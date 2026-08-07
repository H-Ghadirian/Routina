import ComposableArchitecture
import Foundation
import SwiftData

struct TaskRelationshipReviewTask: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let emoji: String
    let tags: [String]
    let path: [String]
    var relationshipCount: Int
}

@Reducer
struct TaskRelationshipReviewFeature {
    private enum CancelID {
        case suggestions
        case batchSuggestions
    }

    @ObservableState
    struct State: Equatable {
        var tasks: [TaskRelationshipReviewTask] = []
        var selectedTaskIndex: Int?
        var suggestions: [TaskRelationshipSuggestion] = []
        var suggestionsByTaskID: [UUID: [TaskRelationshipSuggestion]] = [:]
        var currentFingerprintsByTaskID: [UUID: String] = [:]
        var reviewedFingerprintsByTaskID: [UUID: String] = [:]
        var reviewedTaskIDs: Set<UUID> = []
        var dismissalRecordsByPairKey: [String: TaskRelationshipReviewDismissal] = [:]
        var isLoadingCatalog = false
        var isFindingSuggestions = false
        var isAnalyzingAll = false
        var batchCurrentTaskID: UUID?
        var batchCompletedCount = 0
        var batchTotalCount = 0
        var batchFailureMessagesByTaskID: [UUID: String] = [:]
        var savingSuggestionTargetID: UUID?
        var message: String?

        var selectedTask: TaskRelationshipReviewTask? {
            guard let selectedTaskIndex,
                  tasks.indices.contains(selectedTaskIndex) else {
                return nil
            }
            return tasks[selectedTaskIndex]
        }

        var selectedTaskID: UUID? {
            selectedTask?.id
        }

        var reviewedCount: Int {
            reviewedTaskIDs.count
        }

        var batchCurrentTask: TaskRelationshipReviewTask? {
            guard let batchCurrentTaskID else { return nil }
            return tasks.first { $0.id == batchCurrentTaskID }
        }

        var batchSuggestionCount: Int {
            suggestionsByTaskID.values.reduce(into: 0) { $0 += $1.count }
        }

        var batchFailureCount: Int {
            batchFailureMessagesByTaskID.count
        }

        var batchFailureLabel: String {
            batchFailureCount == 1
                ? "1 task needs retry"
                : "\(batchFailureCount) tasks need retry"
        }

        var newOrChangedTaskIDs: [UUID] {
            tasks.compactMap { task in
                guard let currentFingerprint = currentFingerprintsByTaskID[task.id],
                      reviewedFingerprintsByTaskID[task.id] != currentFingerprint,
                      suggestionsByTaskID[task.id]?.isEmpty != false else {
                    return nil
                }
                return task.id
            }
        }

        var newOrChangedCount: Int {
            newOrChangedTaskIDs.count
        }

        var pendingReviewTaskCount: Int {
            suggestionsByTaskID.values.filter { !$0.isEmpty }.count
        }

        var catalogStatusText: String {
            var parts: [String] = []
            if pendingReviewTaskCount > 0 {
                parts.append(pendingReviewTaskCount == 1
                    ? "1 awaiting review"
                    : "\(pendingReviewTaskCount) awaiting review")
            }
            if newOrChangedCount > 0 {
                parts.append("\(newOrChangedCount) new or changed")
            }
            return parts.isEmpty
                ? "\(reviewedCount) reviewed • Up to date"
                : parts.joined(separator: " • ")
        }

        var canFindSuggestions: Bool {
            selectedTaskID != nil
                && tasks.count > 1
                && !isFindingSuggestions
                && !isAnalyzingAll
                && savingSuggestionTargetID == nil
        }

        var canAnalyzeAll: Bool {
            tasks.count > 1
                && !isLoadingCatalog
                && !isFindingSuggestions
                && !isAnalyzingAll
                && savingSuggestionTargetID == nil
        }

        var canAnalyzeNewOrChanged: Bool {
            newOrChangedCount > 0 && canAnalyzeAll
        }
    }

    enum Action: Equatable {
        case onAppear
        case onDisappear
        case refreshTapped
        case catalogLoaded(
            [TaskRelationshipReviewTask],
            currentFingerprints: [UUID: String],
            reviewedFingerprints: [UUID: String],
            dismissals: [TaskRelationshipReviewDismissal]
        )
        case catalogLoadFailed(String)
        case taskSelected(UUID)
        case findSuggestionsTapped
        case suggestionsLoaded(UUID, [TaskRelationshipSuggestion])
        case suggestionsFailed(UUID, String)
        case analyzeNewOrChangedTapped
        case analyzeAllTapped
        case stopAnalyzeAllTapped
        case batchTaskStarted(UUID)
        case batchTaskCompleted(UUID, [TaskRelationshipSuggestion])
        case batchTaskFailed(UUID, String)
        case batchAnalysisFinished
        case batchAnalysisFailed(String)
        case suggestionKindChanged(UUID, RoutineTaskRelationshipKind)
        case confirmSuggestionTapped(UUID)
        case relationshipSaved(UUID, UUID)
        case relationshipSaveFailed(UUID, UUID, String)
        case dismissSuggestionTapped(UUID)
        case nextTaskTapped
    }

    @Dependency(\.modelContext) var modelContext
    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    @Dependency(\.taskRelationshipSuggestionClient) var suggestionClient
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.taskRelationshipReviewProgressClient) var reviewProgressClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.tasks.isEmpty, !state.isLoadingCatalog else { return .none }
                state.isLoadingCatalog = true
                return loadCatalog()

            case .onDisappear:
                state.isFindingSuggestions = false
                state.isAnalyzingAll = false
                state.batchCurrentTaskID = nil
                return .merge(
                    .cancel(id: CancelID.suggestions),
                    .cancel(id: CancelID.batchSuggestions),
                    persistReviewProgress(state.reviewedFingerprintsByTaskID)
                )

            case .refreshTapped:
                guard !state.isLoadingCatalog,
                      !state.isFindingSuggestions,
                      !state.isAnalyzingAll,
                      state.savingSuggestionTargetID == nil else {
                    return .none
                }
                state.isLoadingCatalog = true
                state.message = nil
                return loadCatalog()

            case let .catalogLoaded(
                tasks,
                currentFingerprints,
                reviewedFingerprints,
                dismissals
            ):
                state.isLoadingCatalog = false
                let previousSelectedTaskID = state.selectedTaskID
                state.tasks = tasks
                state.currentFingerprintsByTaskID = currentFingerprints
                state.reviewedFingerprintsByTaskID = reviewedFingerprints
                state.dismissalRecordsByPairKey = Dictionary(
                    uniqueKeysWithValues: dismissals.map { ($0.pairKey, $0) }
                )
                state.reviewedTaskIDs = Set(tasks.compactMap { task in
                    guard let currentFingerprint = currentFingerprints[task.id],
                          reviewedFingerprints[task.id] == currentFingerprint else {
                        return nil
                    }
                    return task.id
                })
                state.selectedTaskIndex = previousSelectedTaskID.flatMap { selectedTaskID in
                    tasks.firstIndex { $0.id == selectedTaskID }
                } ?? (tasks.isEmpty ? nil : 0)
                state.suggestions = []
                state.suggestionsByTaskID = [:]
                state.batchCurrentTaskID = nil
                state.batchCompletedCount = 0
                state.batchTotalCount = 0
                state.batchFailureMessagesByTaskID = [:]
                state.message = tasks.isEmpty ? "No active tasks are available to review." : nil
                return .none

            case let .catalogLoadFailed(message):
                state.isLoadingCatalog = false
                state.message = message
                return .none

            case let .taskSelected(taskID):
                guard state.savingSuggestionTargetID == nil,
                      !state.isAnalyzingAll,
                      let selectedIndex = state.tasks.firstIndex(where: { $0.id == taskID }),
                      state.selectedTaskID != taskID else {
                    return .none
                }
                state.selectedTaskIndex = selectedIndex
                state.suggestions = state.suggestionsByTaskID[taskID] ?? []
                state.isFindingSuggestions = false
                if let failure = state.batchFailureMessagesByTaskID[taskID] {
                    state.message = "This task could not be analyzed in the batch. \(failure)"
                } else {
                    state.message = state.suggestionsByTaskID[taskID]?.isEmpty == true
                        ? "No new clear relationships found for this task."
                        : nil
                }
                return .cancel(id: CancelID.suggestions)

            case .findSuggestionsTapped:
                guard let sourceTaskID = state.selectedTaskID,
                      state.canFindSuggestions else {
                    return .none
                }
                state.isFindingSuggestions = true
                state.suggestions = []
                state.suggestionsByTaskID[sourceTaskID] = nil
                state.reviewedTaskIDs.remove(sourceTaskID)
                state.reviewedFingerprintsByTaskID[sourceTaskID] = nil
                state.batchFailureMessagesByTaskID[sourceTaskID] = nil
                state.message = nil
                return .merge(
                    persistReviewProgress(state.reviewedFingerprintsByTaskID),
                    findSuggestions(
                        for: sourceTaskID,
                        dismissals: state.dismissalRecordsByPairKey
                    )
                        .cancellable(id: CancelID.suggestions, cancelInFlight: true)
                )

            case let .suggestionsLoaded(sourceTaskID, suggestions):
                guard state.selectedTaskID == sourceTaskID else { return .none }
                state.isFindingSuggestions = false
                state.suggestions = suggestions
                state.suggestionsByTaskID[sourceTaskID] = suggestions
                state.batchFailureMessagesByTaskID[sourceTaskID] = nil
                if state.suggestions.isEmpty {
                    Self.markTaskReviewed(sourceTaskID, in: &state)
                    state.message = "No new clear relationships found for this task."
                    return persistReviewProgress(state.reviewedFingerprintsByTaskID)
                }
                return .none

            case let .suggestionsFailed(sourceTaskID, message):
                guard state.selectedTaskID == sourceTaskID else { return .none }
                state.isFindingSuggestions = false
                state.suggestions = []
                state.message = message
                return .none

            case .analyzeAllTapped:
                guard state.canAnalyzeAll else { return .none }
                let sourceTaskIDs = state.tasks.map(\.id)
                state.suggestions = []
                state.suggestionsByTaskID = [:]
                return startBatch(sourceTaskIDs: sourceTaskIDs, state: &state)

            case .analyzeNewOrChangedTapped:
                guard state.canAnalyzeNewOrChanged else { return .none }
                return startBatch(
                    sourceTaskIDs: state.newOrChangedTaskIDs,
                    state: &state
                )

            case .stopAnalyzeAllTapped:
                guard state.isAnalyzingAll else { return .none }
                state.isAnalyzingAll = false
                state.batchCurrentTaskID = nil
                state.message = "Stopped after checking \(state.batchCompletedCount) of \(state.batchTotalCount) tasks."
                Self.selectFirstCachedSuggestion(in: &state)
                return .merge(
                    .cancel(id: CancelID.batchSuggestions),
                    persistReviewProgress(state.reviewedFingerprintsByTaskID)
                )

            case let .batchTaskStarted(taskID):
                guard state.isAnalyzingAll else { return .none }
                state.batchCurrentTaskID = taskID
                state.reviewedTaskIDs.remove(taskID)
                state.reviewedFingerprintsByTaskID[taskID] = nil
                return .none

            case let .batchTaskCompleted(sourceTaskID, suggestions):
                guard state.isAnalyzingAll else { return .none }
                let cachedPairKeys = Set(
                    state.suggestionsByTaskID.flatMap { cachedSourceTaskID, suggestions in
                        suggestions.map {
                            Self.pairKey(
                                sourceTaskID: cachedSourceTaskID,
                                targetTaskID: $0.targetTaskID
                            )
                        }
                    }
                )
                let filteredSuggestions = suggestions.filter {
                    let pairKey = Self.pairKey(
                        sourceTaskID: sourceTaskID,
                        targetTaskID: $0.targetTaskID
                    )
                    return !cachedPairKeys.contains(pairKey)
                }
                state.suggestionsByTaskID[sourceTaskID] = filteredSuggestions
                state.batchFailureMessagesByTaskID[sourceTaskID] = nil
                if filteredSuggestions.isEmpty {
                    Self.markTaskReviewed(sourceTaskID, in: &state)
                } else {
                    state.reviewedTaskIDs.remove(sourceTaskID)
                }
                state.batchCompletedCount += 1
                state.batchCurrentTaskID = nil
                return .none

            case let .batchTaskFailed(sourceTaskID, message):
                guard state.isAnalyzingAll else { return .none }
                state.batchFailureMessagesByTaskID[sourceTaskID] = message
                state.reviewedTaskIDs.remove(sourceTaskID)
                state.batchCompletedCount += 1
                state.batchCurrentTaskID = nil
                return .none

            case .batchAnalysisFinished:
                guard state.isAnalyzingAll else { return .none }
                state.isAnalyzingAll = false
                state.batchCurrentTaskID = nil
                Self.selectFirstCachedSuggestion(in: &state)
                let processedTaskDescription = state.batchTotalCount == 1
                    ? "1 task"
                    : "\(state.batchTotalCount) tasks"
                if state.batchSuggestionCount == 0, state.batchFailureCount == 0 {
                    state.message = "Checked \(processedTaskDescription). No new clear relationships were found."
                } else if state.batchSuggestionCount == 0 {
                    let failureDescription = state.batchFailureCount == 1
                        ? "1 task could not be analyzed and remains unchecked."
                        : "\(state.batchFailureCount) tasks could not be analyzed and remain unchecked."
                    state.message = "Finished \(processedTaskDescription). \(failureDescription)"
                } else {
                    state.message = nil
                }
                return persistReviewProgress(state.reviewedFingerprintsByTaskID)

            case let .batchAnalysisFailed(message):
                guard state.isAnalyzingAll else { return .none }
                state.isAnalyzingAll = false
                state.batchCurrentTaskID = nil
                state.message = message
                Self.selectFirstCachedSuggestion(in: &state)
                return persistReviewProgress(state.reviewedFingerprintsByTaskID)

            case let .suggestionKindChanged(targetTaskID, kind):
                guard [.blockedBy, .blocks, .related].contains(kind),
                      let index = state.suggestions.firstIndex(where: {
                          $0.targetTaskID == targetTaskID
                      }) else {
                    return .none
                }
                state.suggestions[index].kind = kind
                if let sourceTaskID = state.selectedTaskID {
                    state.suggestionsByTaskID[sourceTaskID] = state.suggestions
                }
                return .none

            case let .confirmSuggestionTapped(targetTaskID):
                guard let sourceTaskID = state.selectedTaskID,
                      state.savingSuggestionTargetID == nil,
                      let suggestion = state.suggestions.first(where: {
                          $0.targetTaskID == targetTaskID
                      }) else {
                    return .none
                }
                state.savingSuggestionTargetID = targetTaskID
                state.message = nil
                return saveRelationship(
                    sourceTaskID: sourceTaskID,
                    suggestion: suggestion
                )

            case let .relationshipSaved(sourceTaskID, targetTaskID):
                guard state.selectedTaskID == sourceTaskID else { return .none }
                state.savingSuggestionTargetID = nil
                Self.removeCachedPair(
                    sourceTaskID: sourceTaskID,
                    targetTaskID: targetTaskID,
                    from: &state
                )
                Self.incrementRelationshipCount(for: sourceTaskID, in: &state.tasks)
                Self.incrementRelationshipCount(for: targetTaskID, in: &state.tasks)
                if state.suggestions.isEmpty {
                    Self.markTaskReviewed(sourceTaskID, in: &state)
                    state.message = "All suggestions for this task are resolved."
                    return persistReviewProgress(state.reviewedFingerprintsByTaskID)
                }
                return .none

            case let .relationshipSaveFailed(sourceTaskID, targetTaskID, message):
                guard state.selectedTaskID == sourceTaskID,
                      state.savingSuggestionTargetID == targetTaskID else {
                    return .none
                }
                state.savingSuggestionTargetID = nil
                state.message = message
                return .none

            case let .dismissSuggestionTapped(targetTaskID):
                guard let sourceTaskID = state.selectedTaskID,
                      state.savingSuggestionTargetID == nil,
                      state.suggestions.contains(where: {
                          $0.targetTaskID == targetTaskID
                      }) else {
                    return .none
                }
                if let dismissal = Self.dismissal(
                    sourceTaskID: sourceTaskID,
                    targetTaskID: targetTaskID,
                    currentFingerprints: state.currentFingerprintsByTaskID,
                    timestamp: now
                ) {
                    state.dismissalRecordsByPairKey[dismissal.pairKey] = dismissal
                }
                Self.removeCachedPair(
                    sourceTaskID: sourceTaskID,
                    targetTaskID: targetTaskID,
                    from: &state
                )
                let persistDismissalFeedback = persistDismissals(
                    Array(state.dismissalRecordsByPairKey.values)
                )
                if state.suggestions.isEmpty {
                    Self.markTaskReviewed(sourceTaskID, in: &state)
                    state.message = "All suggestions for this task are resolved."
                    return .merge(
                        persistDismissalFeedback,
                        persistReviewProgress(state.reviewedFingerprintsByTaskID)
                    )
                }
                return persistDismissalFeedback

            case .nextTaskTapped:
                guard state.savingSuggestionTargetID == nil,
                      !state.isFindingSuggestions,
                      !state.isAnalyzingAll,
                      let currentIndex = state.selectedTaskIndex else {
                    return .none
                }
                let orderedCandidates = Array(state.tasks.dropFirst(currentIndex + 1))
                    + Array(state.tasks.prefix(currentIndex))
                guard let nextTask = orderedCandidates.first(where: {
                    !state.reviewedTaskIDs.contains($0.id)
                }) else {
                    state.message = "All active tasks are up to date or awaiting review."
                    return .none
                }
                state.selectedTaskIndex = state.tasks.firstIndex { $0.id == nextTask.id }
                if let cachedSuggestions = state.suggestionsByTaskID[nextTask.id] {
                    state.suggestions = cachedSuggestions
                    state.message = cachedSuggestions.isEmpty
                        ? "No new clear relationships found for this task."
                        : nil
                    return .none
                }
                state.suggestions = []
                state.message = nil
                return .send(.findSuggestionsTapped)
            }
        }
    }

    private func startBatch(
        sourceTaskIDs: [UUID],
        state: inout State
    ) -> Effect<Action> {
        guard !sourceTaskIDs.isEmpty else { return .none }
        state.isAnalyzingAll = true
        state.batchCurrentTaskID = nil
        state.batchCompletedCount = 0
        state.batchTotalCount = sourceTaskIDs.count
        for sourceTaskID in sourceTaskIDs {
            state.suggestionsByTaskID[sourceTaskID] = nil
            state.batchFailureMessagesByTaskID[sourceTaskID] = nil
        }
        state.message = nil
        return analyzeAll(
            sourceTaskIDs: sourceTaskIDs,
            dismissals: state.dismissalRecordsByPairKey
        )
            .cancellable(id: CancelID.batchSuggestions, cancelInFlight: true)
    }

    private func loadCatalog() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let tasks = try modelContext().fetch(
                    FetchDescriptor<RoutineTask>(sortBy: [SortDescriptor(\RoutineTask.name)])
                )
                let referenceDate = now
                let customTaskSections = appSettingsClient.customTaskSections()
                let suggestionCatalog = TaskRelationshipSuggestionCatalog(
                    tasks: tasks,
                    referenceDate: referenceDate,
                    calendar: calendar,
                    customTaskSections: customTaskSections
                )
                let taskPathsBySectionID = TaskRelationshipSuggestionCatalog
                    .pathTitlesBySectionID(customTaskSections: customTaskSections)
                let eligibleTasks = tasks.filter {
                    $0.canceledAt == nil
                        && !$0.isArchived(referenceDate: referenceDate, calendar: calendar)
                        && !$0.isCompletedOneOff
                }
                var linkedTaskIDsByTaskID: [UUID: Set<UUID>] = [:]
                for task in tasks {
                    for relationship in task.relationships {
                        linkedTaskIDsByTaskID[task.id, default: []].insert(relationship.targetTaskID)
                        linkedTaskIDsByTaskID[relationship.targetTaskID, default: []].insert(task.id)
                    }
                }
                let presentations = eligibleTasks.map {
                    TaskRelationshipReviewTask(
                        id: $0.id,
                        title: RoutineTask.trimmedName($0.name) ?? "Untitled task",
                        emoji: $0.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨",
                        tags: Array($0.tags.prefix(4)),
                        path: $0.customTaskSectionID.flatMap {
                            taskPathsBySectionID[$0]
                        } ?? [],
                        relationshipCount: linkedTaskIDsByTaskID[$0.id]?.count ?? 0
                    )
                }
                let fingerprintEntries: [(UUID, String)] = eligibleTasks.compactMap {
                    guard let fingerprint = suggestionCatalog.fingerprint(for: $0.id) else {
                        return nil
                    }
                    return ($0.id, fingerprint)
                }
                let currentFingerprints = Dictionary(uniqueKeysWithValues: fingerprintEntries)
                let loadedFingerprints = reviewProgressClient.loadFingerprints()
                let currentTaskIDs = Set(currentFingerprints.keys)
                let reviewedFingerprints = loadedFingerprints.filter {
                    currentTaskIDs.contains($0.key)
                }
                if reviewedFingerprints != loadedFingerprints {
                    reviewProgressClient.saveFingerprints(reviewedFingerprints)
                }
                let loadedDismissals = reviewProgressClient.loadDismissals()
                let currentDismissals = loadedDismissals.filter {
                    $0.matches(currentFingerprints: currentFingerprints)
                }
                if currentDismissals != loadedDismissals {
                    reviewProgressClient.saveDismissals(currentDismissals)
                }
                send(.catalogLoaded(
                    presentations,
                    currentFingerprints: currentFingerprints,
                    reviewedFingerprints: reviewedFingerprints,
                    dismissals: currentDismissals
                ))
            } catch {
                send(.catalogLoadFailed("Couldn’t load tasks for relationship review."))
            }
        }
    }

    private func findSuggestions(
        for sourceTaskID: UUID,
        dismissals: [String: TaskRelationshipReviewDismissal]
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let tasks = try modelContext().fetch(FetchDescriptor<RoutineTask>())
                guard tasks.contains(where: { $0.id == sourceTaskID }) else {
                    send(.suggestionsFailed(sourceTaskID, "This task is no longer available."))
                    return
                }
                let catalog = TaskRelationshipSuggestionCatalog(
                    tasks: tasks,
                    referenceDate: now,
                    calendar: calendar,
                    customTaskSections: appSettingsClient.customTaskSections()
                )
                let excludedCandidateIDs = Self.currentDismissedTargetIDs(
                    for: sourceTaskID,
                    dismissals: dismissals,
                    catalog: catalog
                )
                guard let request = catalog.request(
                    for: sourceTaskID,
                    excludingCandidateIDs: excludedCandidateIDs
                ) else {
                    send(.suggestionsLoaded(sourceTaskID, []))
                    return
                }
                guard !request.candidates.isEmpty else {
                    send(.suggestionsLoaded(sourceTaskID, []))
                    return
                }
                let suggestions = try await suggestionClient.suggest(request)
                send(.suggestionsLoaded(sourceTaskID, suggestions))
            } catch {
                let message = (error as? LocalizedError)?.errorDescription
                    ?? "Couldn’t analyze this task. Try again."
                send(.suggestionsFailed(sourceTaskID, message))
            }
        }
    }

    private func analyzeAll(
        sourceTaskIDs: [UUID],
        dismissals: [String: TaskRelationshipReviewDismissal]
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let tasks = try modelContext().fetch(FetchDescriptor<RoutineTask>())
                let catalog = TaskRelationshipSuggestionCatalog(
                    tasks: tasks,
                    referenceDate: now,
                    calendar: calendar,
                    customTaskSections: appSettingsClient.customTaskSections()
                )

                for sourceTaskID in sourceTaskIDs {
                    try Task.checkCancellation()
                    send(.batchTaskStarted(sourceTaskID))
                    let excludedCandidateIDs = Self.currentDismissedTargetIDs(
                        for: sourceTaskID,
                        dismissals: dismissals,
                        catalog: catalog
                    )
                    guard let request = catalog.request(
                        for: sourceTaskID,
                        excludingCandidateIDs: excludedCandidateIDs
                    ),
                          !request.candidates.isEmpty else {
                        send(.batchTaskCompleted(sourceTaskID, []))
                        continue
                    }
                    do {
                        let suggestions = try await suggestionClient.suggest(request)
                        try Task.checkCancellation()
                        send(.batchTaskCompleted(sourceTaskID, suggestions))
                    } catch is CancellationError {
                        return
                    } catch let error as TaskRelationshipSuggestionError {
                        send(.batchAnalysisFailed(
                            error.errorDescription
                                ?? "Apple Intelligence isn’t available right now."
                        ))
                        return
                    } catch {
                        let detail = (error as? LocalizedError)?.errorDescription
                            ?? "The model could not analyze this task."
                        send(.batchTaskFailed(sourceTaskID, detail))
                    }
                }
                send(.batchAnalysisFinished)
            } catch is CancellationError {
                return
            } catch {
                let detail = (error as? LocalizedError)?.errorDescription
                    ?? "Couldn’t continue the batch analysis. Try again."
                send(.batchAnalysisFailed(
                    "Stopped after a model error. \(detail)"
                ))
            }
        }
    }

    private func saveRelationship(
        sourceTaskID: UUID,
        suggestion: TaskRelationshipSuggestion
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                try RoutineTaskRelationshipMutationSupport.link(
                    sourceTaskID: sourceTaskID,
                    targetTaskID: suggestion.targetTaskID,
                    kind: suggestion.kind,
                    timestamp: now,
                    calendar: calendar,
                    context: modelContext()
                )
                send(.relationshipSaved(sourceTaskID, suggestion.targetTaskID))
            } catch {
                send(.relationshipSaveFailed(
                    sourceTaskID,
                    suggestion.targetTaskID,
                    "Couldn’t save this relationship. Try again."
                ))
            }
        }
    }

    private func persistReviewProgress(
        _ fingerprints: [UUID: String]
    ) -> Effect<Action> {
        .run { _ in
            reviewProgressClient.saveFingerprints(fingerprints)
        }
    }

    private func persistDismissals(
        _ dismissals: [TaskRelationshipReviewDismissal]
    ) -> Effect<Action> {
        .run { _ in
            reviewProgressClient.saveDismissals(dismissals)
        }
    }

    private static func pairKey(sourceTaskID: UUID, targetTaskID: UUID) -> String {
        TaskRelationshipReviewDismissal.pairKey(sourceTaskID, targetTaskID)
    }

    private static func dismissal(
        sourceTaskID: UUID,
        targetTaskID: UUID,
        currentFingerprints: [UUID: String],
        timestamp: Date
    ) -> TaskRelationshipReviewDismissal? {
        guard let sourceTaskFingerprint = currentFingerprints[sourceTaskID],
              let targetTaskFingerprint = currentFingerprints[targetTaskID] else {
            return nil
        }
        return TaskRelationshipReviewDismissal(
            sourceTaskID: sourceTaskID,
            sourceTaskFingerprint: sourceTaskFingerprint,
            targetTaskID: targetTaskID,
            targetTaskFingerprint: targetTaskFingerprint,
            dismissedAt: timestamp
        )
    }

    private static func currentDismissedTargetIDs(
        for sourceTaskID: UUID,
        dismissals: [String: TaskRelationshipReviewDismissal],
        catalog: TaskRelationshipSuggestionCatalog
    ) -> Set<UUID> {
        Set(dismissals.values.compactMap { dismissal in
            guard dismissal.matches(fingerprintFor: catalog.fingerprint) else {
                return nil
            }
            return dismissal.otherTaskID(for: sourceTaskID)
        })
    }

    private static func incrementRelationshipCount(
        for taskID: UUID,
        in tasks: inout [TaskRelationshipReviewTask]
    ) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].relationshipCount += 1
    }

    private static func markTaskReviewed(_ taskID: UUID, in state: inout State) {
        state.reviewedTaskIDs.insert(taskID)
        if let currentFingerprint = state.currentFingerprintsByTaskID[taskID] {
            state.reviewedFingerprintsByTaskID[taskID] = currentFingerprint
        }
        state.batchFailureMessagesByTaskID[taskID] = nil
    }

    private static func selectFirstCachedSuggestion(in state: inout State) {
        guard let task = state.tasks.first(where: {
            state.suggestionsByTaskID[$0.id]?.isEmpty == false
        }) else {
            state.suggestions = []
            return
        }
        state.selectedTaskIndex = state.tasks.firstIndex { $0.id == task.id }
        state.suggestions = state.suggestionsByTaskID[task.id] ?? []
    }

    private static func removeCachedPair(
        sourceTaskID: UUID,
        targetTaskID: UUID,
        from state: inout State
    ) {
        state.suggestions.removeAll { $0.targetTaskID == targetTaskID }
        state.suggestionsByTaskID[sourceTaskID]?.removeAll {
            $0.targetTaskID == targetTaskID
        }
        state.suggestionsByTaskID[targetTaskID]?.removeAll {
            $0.targetTaskID == sourceTaskID
        }
        if state.suggestionsByTaskID[targetTaskID]?.isEmpty == true {
            markTaskReviewed(targetTaskID, in: &state)
        }
    }
}

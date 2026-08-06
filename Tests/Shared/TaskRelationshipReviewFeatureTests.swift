import ComposableArchitecture
import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct TaskRelationshipReviewFeatureTests {
    @Test
    func catalogLoadsOnlyActiveReviewableTasks() async throws {
        let context = makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let active = RoutineTask(name: "Book flight", emoji: "✈️", tags: ["Travel"])
        let completed = RoutineTask(
            name: "Old purchase",
            scheduleMode: .oneOff,
            lastDone: Date(timeIntervalSince1970: 1)
        )
        let canceled = RoutineTask(
            name: "Canceled trip",
            scheduleMode: .oneOff,
            canceledAt: now
        )
        let archived = RoutineTask(
            name: "Archived itinerary",
            scheduleMode: .oneOff,
            pausedAt: now
        )
        let rootSection = HomeCustomTaskSection(title: "Travel")
        let childSection = HomeCustomTaskSection(
            parentSectionID: rootSection.id,
            title: "Summer trip"
        )
        active.customTaskSectionID = childSection.id
        context.insert(active)
        context.insert(completed)
        context.insert(canceled)
        context.insert(archived)
        try context.save()

        let presentation = TaskRelationshipReviewTask(
            id: active.id,
            title: "Book flight",
            emoji: "✈️",
            tags: ["Travel"],
            path: ["Travel", "Summer trip"],
            relationshipCount: 0
        )
        let suggestionCatalog = TaskRelationshipSuggestionCatalog(
            tasks: [active, completed, canceled, archived],
            referenceDate: now,
            calendar: calendar,
            customTaskSections: [rootSection, childSection]
        )
        let activeFingerprint = try #require(suggestionCatalog.fingerprint(for: active.id))
        #expect(suggestionCatalog.request(for: archived.id) == nil)
        let store = TestStore(initialState: TaskRelationshipReviewFeature.State()) {
            TaskRelationshipReviewFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.date.now = now
            $0.calendar = calendar
            $0.appSettingsClient.customTaskSections = { [rootSection, childSection] }
        }

        await store.send(.onAppear) {
            $0.isLoadingCatalog = true
        }
        await store.receive(.catalogLoaded(
            [presentation],
            currentFingerprints: [active.id: activeFingerprint],
            reviewedFingerprints: [:]
        )) {
            $0.isLoadingCatalog = false
            $0.tasks = [presentation]
            $0.currentFingerprintsByTaskID = [active.id: activeFingerprint]
            $0.selectedTaskIndex = 0
        }
    }

    @Test
    func suggestionCanBeEditedAndConfirmedFromReviewWindow() async throws {
        let context = makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let source = RoutineTask(name: "Book flight", emoji: "✈️", tags: ["Travel"])
        let target = RoutineTask(name: "Renew passport", emoji: "🛂", tags: ["Travel"])
        context.insert(source)
        context.insert(target)
        try context.save()

        let sourcePresentation = TaskRelationshipReviewTask(
            id: source.id,
            title: "Book flight",
            emoji: "✈️",
            tags: ["Travel"],
            path: [],
            relationshipCount: 0
        )
        let targetPresentation = TaskRelationshipReviewTask(
            id: target.id,
            title: "Renew passport",
            emoji: "🛂",
            tags: ["Travel"],
            path: [],
            relationshipCount: 0
        )
        let suggestion = TaskRelationshipSuggestion(
            targetTaskID: target.id,
            targetTaskTitle: "Renew passport",
            targetTaskEmoji: "🛂",
            kind: .blockedBy,
            reason: "A current passport may be required before booking."
        )
        let editedSuggestion = TaskRelationshipSuggestion(
            targetTaskID: target.id,
            targetTaskTitle: "Renew passport",
            targetTaskEmoji: "🛂",
            kind: .blocks,
            reason: "A current passport may be required before booking."
        )
        let pairKey = [source.id.uuidString.lowercased(), target.id.uuidString.lowercased()]
            .sorted()
            .joined(separator: "|")
        let initialState = TaskRelationshipReviewFeature.State(
            tasks: [sourcePresentation, targetPresentation],
            selectedTaskIndex: 0
        )
        let sourceID = source.id
        let store = TestStore(initialState: initialState) {
            TaskRelationshipReviewFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.date.now = now
            $0.calendar = calendar
            $0.taskRelationshipSuggestionClient = TaskRelationshipSuggestionClient { request in
                #expect(request.source.id == sourceID)
                return [suggestion]
            }
        }

        await store.send(.findSuggestionsTapped) {
            $0.isFindingSuggestions = true
        }
        await store.receive(.suggestionsLoaded(source.id, [suggestion])) {
            $0.isFindingSuggestions = false
            $0.suggestions = [suggestion]
            $0.suggestionsByTaskID[source.id] = [suggestion]
        }
        await store.send(.suggestionKindChanged(target.id, .blocks)) {
            $0.suggestions[0].kind = .blocks
            $0.suggestionsByTaskID[source.id] = [editedSuggestion]
        }
        await store.send(.confirmSuggestionTapped(target.id)) {
            $0.savingSuggestionTargetID = target.id
        }
        await store.receive(.relationshipSaved(source.id, target.id)) {
            $0.savingSuggestionTargetID = nil
            $0.suggestions = []
            $0.suggestionsByTaskID[source.id] = []
            $0.dismissedPairKeys = [pairKey]
            $0.tasks[0].relationshipCount = 1
            $0.tasks[1].relationshipCount = 1
            $0.reviewedTaskIDs = [source.id]
            $0.message = "All suggestions for this task are resolved."
        }

        let persistedSource = try #require(
            try context.fetch(TaskDetailFetchDescriptors.task(for: source.id)).first
        )
        #expect(persistedSource.relationships == [
            RoutineTaskRelationship(targetTaskID: target.id, kind: .blocks)
        ])
    }

    @Test
    func analyzeAllChecksEveryTaskAndCollectsOneReviewPerPair() async throws {
        let context = makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let source = RoutineTask(name: "Book flight", emoji: "✈️")
        let target = RoutineTask(name: "Renew passport", emoji: "🛂")
        let other = RoutineTask(name: "Reserve hotel", emoji: "🏨")
        for task in [source, target, other] {
            context.insert(task)
        }
        try context.save()

        let presentations = [source, target, other].map {
            TaskRelationshipReviewTask(
                id: $0.id,
                title: $0.name ?? "Untitled task",
                emoji: $0.emoji ?? "✨",
                tags: [],
                path: [],
                relationshipCount: 0
            )
        }
        let sourceSuggestion = TaskRelationshipSuggestion(
            targetTaskID: target.id,
            targetTaskTitle: "Renew passport",
            targetTaskEmoji: "🛂",
            kind: .blockedBy,
            reason: "A valid passport is needed before the flight."
        )
        let reverseSuggestion = TaskRelationshipSuggestion(
            targetTaskID: source.id,
            targetTaskTitle: "Book flight",
            targetTaskEmoji: "✈️",
            kind: .related,
            reason: "Both tasks prepare the trip."
        )
        let sourceID = source.id
        let targetID = target.id
        let analyzedTaskIDs = LockIsolated<[UUID]>([])
        let initialState = TaskRelationshipReviewFeature.State(
            tasks: presentations,
            selectedTaskIndex: 0
        )
        let store = TestStore(initialState: initialState) {
            TaskRelationshipReviewFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.date.now = now
            $0.calendar = calendar
            $0.taskRelationshipSuggestionClient = TaskRelationshipSuggestionClient { request in
                analyzedTaskIDs.withValue { $0.append(request.source.id) }
                if request.source.id == sourceID {
                    return [sourceSuggestion]
                }
                if request.source.id == targetID {
                    return [reverseSuggestion]
                }
                return []
            }
        }

        await store.send(.analyzeAllTapped) {
            $0.isAnalyzingAll = true
            $0.batchTotalCount = 3
        }
        await store.receive(.batchTaskStarted(source.id)) {
            $0.batchCurrentTaskID = source.id
        }
        await store.receive(.batchTaskCompleted(source.id, [sourceSuggestion])) {
            $0.suggestionsByTaskID[source.id] = [sourceSuggestion]
            $0.batchCompletedCount = 1
            $0.batchCurrentTaskID = nil
        }
        await store.receive(.batchTaskStarted(target.id)) {
            $0.batchCurrentTaskID = target.id
        }
        await store.receive(.batchTaskCompleted(target.id, [reverseSuggestion])) {
            $0.suggestionsByTaskID[target.id] = []
            $0.reviewedTaskIDs = [target.id]
            $0.batchCompletedCount = 2
            $0.batchCurrentTaskID = nil
        }
        await store.receive(.batchTaskStarted(other.id)) {
            $0.batchCurrentTaskID = other.id
        }
        await store.receive(.batchTaskCompleted(other.id, [])) {
            $0.suggestionsByTaskID[other.id] = []
            $0.reviewedTaskIDs = [target.id, other.id]
            $0.batchCompletedCount = 3
            $0.batchCurrentTaskID = nil
        }
        await store.receive(.batchAnalysisFinished) {
            $0.isAnalyzingAll = false
            $0.suggestions = [sourceSuggestion]
        }

        #expect(analyzedTaskIDs.value == [source.id, target.id, other.id])
        #expect(store.state.batchSuggestionCount == 1)
    }

    @Test
    func analyzeNewOrChangedProcessesOnlyStaleFingerprintsAndPersistsSuccess() async throws {
        let context = makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let unchanged = RoutineTask(name: "Unchanged")
        let changed = RoutineTask(name: "Changed")
        let alsoUnchanged = RoutineTask(name: "Also unchanged")
        for task in [unchanged, changed, alsoUnchanged] {
            context.insert(task)
        }
        try context.save()

        let presentations = [unchanged, changed, alsoUnchanged].map {
            TaskRelationshipReviewTask(
                id: $0.id,
                title: $0.name ?? "Untitled task",
                emoji: "✨",
                tags: [],
                path: [],
                relationshipCount: 0
            )
        }
        let unchangedID = unchanged.id
        let changedID = changed.id
        let alsoUnchangedID = alsoUnchanged.id
        let currentFingerprints = [
            unchangedID: "unchanged-v1",
            changedID: "changed-v2",
            alsoUnchangedID: "also-unchanged-v1"
        ]
        let reviewedFingerprints = [
            unchangedID: "unchanged-v1",
            changedID: "changed-v1",
            alsoUnchangedID: "also-unchanged-v1"
        ]
        let analyzedTaskIDs = LockIsolated<[UUID]>([])
        let savedFingerprints = LockIsolated<[UUID: String]>([:])
        let store = TestStore(
            initialState: TaskRelationshipReviewFeature.State(
                tasks: presentations,
                selectedTaskIndex: 0,
                currentFingerprintsByTaskID: currentFingerprints,
                reviewedFingerprintsByTaskID: reviewedFingerprints,
                reviewedTaskIDs: [unchangedID, alsoUnchangedID]
            )
        ) {
            TaskRelationshipReviewFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.date.now = now
            $0.calendar = calendar
            $0.taskRelationshipSuggestionClient = TaskRelationshipSuggestionClient { request in
                analyzedTaskIDs.withValue { $0.append(request.source.id) }
                return []
            }
            $0.taskRelationshipReviewProgressClient = TaskRelationshipReviewProgressClient(
                loadFingerprints: { [:] },
                saveFingerprints: { value in savedFingerprints.setValue(value) }
            )
        }

        #expect(store.state.newOrChangedTaskIDs == [changedID])
        await store.send(.analyzeNewOrChangedTapped) {
            $0.isAnalyzingAll = true
            $0.batchTotalCount = 1
        }
        await store.receive(.batchTaskStarted(changedID)) {
            $0.batchCurrentTaskID = changedID
            $0.reviewedFingerprintsByTaskID[changedID] = nil
        }
        await store.receive(.batchTaskCompleted(changedID, [])) {
            $0.suggestionsByTaskID[changedID] = []
            $0.reviewedFingerprintsByTaskID[changedID] = "changed-v2"
            $0.reviewedTaskIDs = [unchangedID, changedID, alsoUnchangedID]
            $0.batchCompletedCount = 1
            $0.batchCurrentTaskID = nil
        }
        await store.receive(.batchAnalysisFinished) {
            $0.isAnalyzingAll = false
            $0.message = "Checked 1 task. No new clear relationships were found."
        }
        await store.finish()

        #expect(analyzedTaskIDs.value == [changedID])
        #expect(savedFingerprints.value == currentFingerprints)
        #expect(store.state.newOrChangedCount == 0)
    }

    @Test
    func relationshipReviewProgressStorageRoundTripsFingerprints() throws {
        let suiteName = "TaskRelationshipReviewProgressStorageTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let firstID = UUID()
        let secondID = UUID()
        let fingerprints = [firstID: "first", secondID: "second"]

        TaskRelationshipReviewProgressStorage.save(fingerprints, to: defaults)

        #expect(TaskRelationshipReviewProgressStorage.load(from: defaults) == fingerprints)
    }

    @Test
    func analyzeAllContinuesAfterOneTaskModelFailure() async throws {
        let context = makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let first = RoutineTask(name: "First")
        let failing = RoutineTask(name: "Failing")
        let last = RoutineTask(name: "Last")
        for task in [first, failing, last] {
            context.insert(task)
        }
        try context.save()

        let presentations = [first, failing, last].map {
            TaskRelationshipReviewTask(
                id: $0.id,
                title: $0.name ?? "Untitled task",
                emoji: "✨",
                tags: [],
                path: [],
                relationshipCount: 0
            )
        }
        let firstID = first.id
        let failingID = failing.id
        let lastID = last.id
        let analyzedTaskIDs = LockIsolated<[UUID]>([])
        let store = TestStore(
            initialState: TaskRelationshipReviewFeature.State(
                tasks: presentations,
                selectedTaskIndex: 0
            )
        ) {
            TaskRelationshipReviewFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.date.now = now
            $0.calendar = calendar
            $0.taskRelationshipSuggestionClient = TaskRelationshipSuggestionClient { request in
                analyzedTaskIDs.withValue { $0.append(request.source.id) }
                if request.source.id == failingID {
                    throw BatchModelFailure.rejected
                }
                return []
            }
        }

        await store.send(.analyzeAllTapped) {
            $0.isAnalyzingAll = true
            $0.batchTotalCount = 3
        }
        await store.receive(.batchTaskStarted(firstID)) {
            $0.batchCurrentTaskID = firstID
        }
        await store.receive(.batchTaskCompleted(firstID, [])) {
            $0.suggestionsByTaskID[firstID] = []
            $0.reviewedTaskIDs = [firstID]
            $0.batchCompletedCount = 1
            $0.batchCurrentTaskID = nil
        }
        await store.receive(.batchTaskStarted(failingID)) {
            $0.batchCurrentTaskID = failingID
        }
        await store.receive(.batchTaskFailed(failingID, "Prompt rejected.")) {
            $0.batchFailureMessagesByTaskID[failingID] = "Prompt rejected."
            $0.batchCompletedCount = 2
            $0.batchCurrentTaskID = nil
        }
        await store.receive(.batchTaskStarted(lastID)) {
            $0.batchCurrentTaskID = lastID
        }
        await store.receive(.batchTaskCompleted(lastID, [])) {
            $0.suggestionsByTaskID[lastID] = []
            $0.reviewedTaskIDs = [firstID, lastID]
            $0.batchCompletedCount = 3
            $0.batchCurrentTaskID = nil
        }
        await store.receive(.batchAnalysisFinished) {
            $0.isAnalyzingAll = false
            $0.message = "Finished 3 tasks. 1 task could not be analyzed and remains unchecked."
        }

        #expect(analyzedTaskIDs.value == [firstID, failingID, lastID])
        #expect(store.state.batchFailureCount == 1)
    }

    @Test
    func stoppingAnalyzeAllPreservesCompletedSuggestions() async {
        let sourceID = UUID()
        let targetID = UUID()
        let suggestion = TaskRelationshipSuggestion(
            targetTaskID: targetID,
            targetTaskTitle: "Renew passport",
            targetTaskEmoji: "🛂",
            kind: .blockedBy,
            reason: "A valid passport is needed before the flight."
        )
        let source = TaskRelationshipReviewTask(
            id: sourceID,
            title: "Book flight",
            emoji: "✈️",
            tags: [],
            path: [],
            relationshipCount: 0
        )
        let target = TaskRelationshipReviewTask(
            id: targetID,
            title: "Renew passport",
            emoji: "🛂",
            tags: [],
            path: [],
            relationshipCount: 0
        )
        let initialState = TaskRelationshipReviewFeature.State(
            tasks: [source, target],
            selectedTaskIndex: 1,
            suggestionsByTaskID: [sourceID: [suggestion]],
            isAnalyzingAll: true,
            batchCurrentTaskID: targetID,
            batchCompletedCount: 1,
            batchTotalCount: 2
        )
        let store = TestStore(initialState: initialState) {
            TaskRelationshipReviewFeature()
        }

        await store.send(.stopAnalyzeAllTapped) {
            $0.isAnalyzingAll = false
            $0.batchCurrentTaskID = nil
            $0.selectedTaskIndex = 0
            $0.suggestions = [suggestion]
            $0.message = "Stopped after checking 1 of 2 tasks."
        }
    }

    @Test
    func macMenuOpensDedicatedReducerOwnedReviewWindow() throws {
        let commands = try Self.sourceFile("RoutinaMacApp/Commands/RoutineCommands.swift")
        let scene = try Self.sourceFile("RoutinaMacApp/Screens/App/RoutinaMacRootScene.swift")
        let view = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRelationships/TaskRelationshipReviewView.swift"
        )

        #expect(commands.contains("Button(\"Review Task Relationships…\")"))
        #expect(commands.contains("openWindow(id: RoutinaMacSceneID.taskRelationshipReview)"))
        #expect(
            scene.contains(
                "Window(\"Review Task Relationships\", id: RoutinaMacSceneID.taskRelationshipReview)"
            )
        )
        #expect(view.contains("StoreOf<TaskRelationshipReviewFeature>"))
        #expect(view.contains("Analyze new & changed"))
        #expect(view.contains("Reanalyze all tasks"))
        #expect(view.contains("stopAnalyzeAllTapped"))
        #expect(!view.contains("@Query"))
        #expect(!view.contains("@Environment(\\.modelContext)"))
        #expect(!view.contains("modelContext.save()"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private enum BatchModelFailure: LocalizedError {
        case rejected

        var errorDescription: String? {
            "Prompt rejected."
        }
    }
}

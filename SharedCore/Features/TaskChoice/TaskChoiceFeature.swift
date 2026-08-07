import ComposableArchitecture
import Foundation
import SwiftData

enum TaskChoiceAvailableTime: String, CaseIterable, Equatable, Sendable {
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case flexible

    var title: String {
        switch self {
        case .fifteenMinutes:
            return "15 min"
        case .thirtyMinutes:
            return "30 min"
        case .oneHour:
            return "1 hour"
        case .flexible:
            return "Flexible"
        }
    }

    var maximumEstimatedMinutes: Int? {
        switch self {
        case .fifteenMinutes:
            return 15
        case .thirtyMinutes:
            return 30
        case .oneHour:
            return 60
        case .flexible:
            return nil
        }
    }
}

enum TaskChoiceEnergy: String, CaseIterable, Equatable, Sendable {
    case low
    case medium
    case high

    var title: String { rawValue.capitalized }
}

enum TaskChoiceIntent: String, CaseIterable, Equatable, Sendable {
    case reducePressure
    case meetUrgency
    case makeProgress

    var title: String {
        switch self {
        case .reducePressure:
            return "Reduce pressure"
        case .meetUrgency:
            return "Meet urgency"
        case .makeProgress:
            return "Make progress"
        }
    }
}

struct TaskChoiceCondition: Equatable, Sendable {
    var availableTime: TaskChoiceAvailableTime = .thirtyMinutes
    var energy: TaskChoiceEnergy = .medium
    var intent: TaskChoiceIntent = .makeProgress

    var summary: String {
        "\(availableTime.title) • \(energy.title) energy • \(intent.title.lowercased())"
    }
}

struct TaskChoiceCandidate: Identifiable, Equatable {
    let id: UUID
    let title: String
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let pressure: RoutineTaskPressure
    let thinkingNeeded: RoutineTaskThinkingNeeded
    let estimatedDurationMinutes: Int?
    let tags: [String]
    let learnedTieBreakScore: Double
    let comparisonCount: Int16

    init(task: RoutineTask) {
        id = task.id
        title = RoutineTask.trimmedName(task.name) ?? "Untitled task"
        importance = task.importance
        urgency = task.urgency
        pressure = task.pressure
        thinkingNeeded = task.thinkingNeeded
        estimatedDurationMinutes = task.estimatedDurationMinutes
        tags = task.tags
        learnedTieBreakScore = task.taskChoiceTieBreakScore
        comparisonCount = task.taskChoiceComparisonCount
    }
}

struct TaskChoiceMissingData: Equatable {
    struct Item: Identifiable, Equatable {
        let title: String
        let count: Int

        var id: String { title }
    }

    var importanceCount = 0
    var urgencyCount = 0
    var pressureCount = 0
    var thinkingNeededCount = 0
    var estimatedDurationCount = 0

    var isEmpty: Bool {
        importanceCount == 0
            && urgencyCount == 0
            && pressureCount == 0
            && thinkingNeededCount == 0
            && estimatedDurationCount == 0
    }

    var items: [Item] {
        [
            Item(title: "Importance", count: importanceCount),
            Item(title: "Urgency", count: urgencyCount),
            Item(title: "Pressure", count: pressureCount),
            Item(title: "Thinking needed", count: thinkingNeededCount),
            Item(title: "Time estimate", count: estimatedDurationCount)
        ].filter { $0.count > 0 }
    }
}

enum TaskChoiceCandidateRanking {
    static let tieBreakIncrement = 0.1

    static func isCurrentlySelectable(
        _ task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar,
        logs: [RoutineLog] = []
    ) -> Bool {
        guard task.canceledAt == nil,
              !task.isArchived(referenceDate: referenceDate, calendar: calendar)
        else {
            return false
        }

        if task.isOneOffTask {
            return !task.isCompletedOneOff
        }

        let currentOccurrenceDay = RoutineAssumedCompletion.currentOccurrenceDay(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        guard !RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: currentOccurrenceDay,
            referenceDate: referenceDate,
            logs: logs,
            calendar: calendar
        ) else {
            return false
        }
        let completedCurrentOccurrence = task.lastDone.flatMap {
            RoutineDateMath.completionDisplayDay(
                for: task,
                completionDate: $0,
                calendar: calendar
            )
        }.map {
            calendar.isDate($0, inSameDayAs: currentOccurrenceDay)
        } ?? false

        return !RoutineDateMath.isCompletedForCurrentPeriod(
            completedCurrentOccurrence,
            task: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    static func ranked(
        tasks: [RoutineTask],
        condition: TaskChoiceCondition
    ) -> [TaskChoiceCandidate] {
        tasks
            .map(TaskChoiceCandidate.init)
            .sorted { lhs, rhs in
                let lhsScore = score(lhs, for: condition)
                let rhsScore = score(rhs, for: condition)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                if lhs.learnedTieBreakScore != rhs.learnedTieBreakScore {
                    return lhs.learnedTieBreakScore > rhs.learnedTieBreakScore
                }
                let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                if titleComparison != .orderedSame {
                    return titleComparison == .orderedAscending
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    /// A comparison is needed only when task metadata makes two candidates equally relevant
    /// for the current condition and their persisted learned tie-break is also equal.
    static func nextComparisonPair(
        tasks: [RoutineTask],
        condition: TaskChoiceCondition
    ) -> (TaskChoiceCandidate, TaskChoiceCandidate)? {
        let candidates = tasks.map(TaskChoiceCandidate.init)
        let scoreGroups = Dictionary(grouping: candidates) { score($0, for: condition) }

        for score in scoreGroups.keys.sorted(by: >) {
            guard let scoreGroup = scoreGroups[score] else { continue }
            let tieGroups = Dictionary(grouping: scoreGroup) { tieBreakBucket($0.learnedTieBreakScore) }
            for tieBreak in tieGroups.keys.sorted(by: >) {
                guard let tieGroup = tieGroups[tieBreak], tieGroup.count > 1 else { continue }
                let orderedTie = tieGroup.sorted { lhs, rhs in
                    if lhs.comparisonCount != rhs.comparisonCount {
                        return lhs.comparisonCount < rhs.comparisonCount
                    }
                    let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                    if titleComparison != .orderedSame {
                        return titleComparison == .orderedAscending
                    }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return (orderedTie[0], orderedTie[1])
            }
        }

        return nil
    }

    static func score(
        _ task: TaskChoiceCandidate,
        for condition: TaskChoiceCondition
    ) -> Int {
        var score = (task.importance.sortOrder * 2) + (task.urgency.sortOrder * 2)

        switch condition.intent {
        case .reducePressure:
            score += task.pressure.sortOrder * 3
        case .meetUrgency:
            score += task.urgency.sortOrder * 3
        case .makeProgress:
            score += task.importance.sortOrder * 2
        }

        score += energyScore(task.thinkingNeeded, for: condition.energy)
        score += durationScore(task.estimatedDurationMinutes, for: condition.availableTime)
        return score
    }

    static func nextTieBreakScore(winner: TaskChoiceCandidate, loser: TaskChoiceCandidate) -> Double {
        let rawValue = max(winner.learnedTieBreakScore, loser.learnedTieBreakScore) + tieBreakIncrement
        return (rawValue * 10).rounded() / 10
    }

    static func missingData(for tasks: [RoutineTask]) -> TaskChoiceMissingData {
        tasks.reduce(into: TaskChoiceMissingData()) { result, task in
            if !task.hasExplicitImportance { result.importanceCount += 1 }
            if !task.hasExplicitUrgency { result.urgencyCount += 1 }
            if task.pressure == .none { result.pressureCount += 1 }
            if task.thinkingNeeded == .none { result.thinkingNeededCount += 1 }
            if task.estimatedDurationMinutes == nil { result.estimatedDurationCount += 1 }
        }
    }

    private static func tieBreakBucket(_ score: Double) -> Int {
        Int((score * 10).rounded())
    }

    private static func energyScore(
        _ thinkingNeeded: RoutineTaskThinkingNeeded,
        for energy: TaskChoiceEnergy
    ) -> Int {
        switch (energy, thinkingNeeded) {
        case (.low, .none), (.low, .low):
            return 3
        case (.low, .medium):
            return 0
        case (.low, .high):
            return -4
        case (.medium, .none), (.medium, .low), (.medium, .medium):
            return 2
        case (.medium, .high):
            return -1
        case (.high, .none):
            return 0
        case (.high, .low), (.high, .medium):
            return 2
        case (.high, .high):
            return 3
        }
    }

    private static func durationScore(
        _ estimatedDurationMinutes: Int?,
        for availableTime: TaskChoiceAvailableTime
    ) -> Int {
        guard let maximumEstimatedMinutes = availableTime.maximumEstimatedMinutes,
              let estimatedDurationMinutes
        else {
            return 0
        }

        if estimatedDurationMinutes <= maximumEstimatedMinutes {
            return 4
        }
        if estimatedDurationMinutes <= maximumEstimatedMinutes * 2 {
            return 1
        }
        return -5
    }
}

@Reducer
struct TaskChoiceFeature {
    @ObservableState
    struct State: Equatable {
        enum Phase: Equatable {
            case setup
            case loading
            case needsData
            case comparing
            case recommendation
            case empty
            case failure
        }

        var condition = TaskChoiceCondition()
        var phase: Phase = .setup
        /// The view retains only the visible pair or recommendation; the reducer fetches and ranks tasks off the render path.
        var firstCandidate: TaskChoiceCandidate?
        var secondCandidate: TaskChoiceCandidate?
        var recommendedTask: TaskChoiceCandidate?
        var missingData: TaskChoiceMissingData?
        var candidateCount = 0
        var completedComparisonCount = 0
        var isSavingSelection = false
        var errorMessage: String?

        var comparisonNumber: Int {
            completedComparisonCount + 1
        }
    }

    enum LoadResult: Equatable {
        case empty
        case needsData(TaskChoiceMissingData, candidateCount: Int)
        case comparison(TaskChoiceCandidate, TaskChoiceCandidate, candidateCount: Int)
        case recommendation(TaskChoiceCandidate, candidateCount: Int)
    }

    @CasePathable
    enum Action: Equatable {
        case availableTimeChanged(TaskChoiceAvailableTime)
        case energyChanged(TaskChoiceEnergy)
        case intentChanged(TaskChoiceIntent)
        case findTasksTapped
        case tasksLoaded(LoadResult)
        case tasksLoadFailed
        case preferredTaskSelected(UUID)
        case comparisonSaved(TaskChoiceCandidate)
        case comparisonSaveFailed
        case taskDetailsTapped(UUID)
        case startAgainTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case taskDetailsRequested(UUID)
        }
    }

    @Dependency(\.modelContext) private var modelContext
    @Dependency(\.date.now) private var now
    @Dependency(\.calendar) private var calendar

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .availableTimeChanged(availableTime):
                state.condition.availableTime = availableTime
                return .none

            case let .energyChanged(energy):
                state.condition.energy = energy
                return .none

            case let .intentChanged(intent):
                state.condition.intent = intent
                return .none

            case .findTasksTapped:
                state.phase = .loading
                state.firstCandidate = nil
                state.secondCandidate = nil
                state.recommendedTask = nil
                state.missingData = nil
                state.candidateCount = 0
                state.completedComparisonCount = 0
                state.isSavingSelection = false
                state.errorMessage = nil
                return loadCandidates(for: state.condition)

            case let .tasksLoaded(result):
                state.errorMessage = nil
                state.isSavingSelection = false
                switch result {
                case .empty:
                    state.phase = .empty
                    state.candidateCount = 0
                case let .needsData(missingData, candidateCount):
                    state.phase = .needsData
                    state.missingData = missingData
                    state.candidateCount = candidateCount
                case let .comparison(firstCandidate, secondCandidate, candidateCount):
                    state.phase = .comparing
                    state.firstCandidate = firstCandidate
                    state.secondCandidate = secondCandidate
                    state.candidateCount = candidateCount
                case let .recommendation(recommendedTask, candidateCount):
                    state.phase = .recommendation
                    state.recommendedTask = recommendedTask
                    state.candidateCount = candidateCount
                }
                return .none

            case .tasksLoadFailed:
                state.phase = .failure
                state.errorMessage = "Couldn’t load tasks. Try again."
                return .none

            case let .preferredTaskSelected(taskID):
                guard state.phase == .comparing,
                      !state.isSavingSelection,
                      let firstCandidate = state.firstCandidate,
                      let secondCandidate = state.secondCandidate,
                      taskID == firstCandidate.id || taskID == secondCandidate.id
                else {
                    return .none
                }

                let winner = taskID == firstCandidate.id ? firstCandidate : secondCandidate
                let loser = taskID == firstCandidate.id ? secondCandidate : firstCandidate
                state.isSavingSelection = true
                state.errorMessage = nil
                return saveComparison(winner: winner, loser: loser)

            case let .comparisonSaved(winner):
                state.completedComparisonCount += 1
                state.firstCandidate = winner
                state.secondCandidate = nil
                state.isSavingSelection = false
                return loadCandidates(for: state.condition)

            case .comparisonSaveFailed:
                state.isSavingSelection = false
                state.phase = .failure
                state.errorMessage = "Couldn’t save that comparison. Try again."
                return .none

            case let .taskDetailsTapped(taskID):
                return .send(.delegate(.taskDetailsRequested(taskID)))

            case .startAgainTapped:
                state.phase = .setup
                state.firstCandidate = nil
                state.secondCandidate = nil
                state.recommendedTask = nil
                state.missingData = nil
                state.candidateCount = 0
                state.completedComparisonCount = 0
                state.isSavingSelection = false
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func loadCandidates(for condition: TaskChoiceCondition) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let descriptor = FetchDescriptor<RoutineTask>(
                    predicate: #Predicate { task in
                        task.canceledAt == nil
                    },
                    sortBy: [SortDescriptor(\RoutineTask.name)]
                )
                let tasks = try modelContext().fetch(descriptor)
                let logs = try modelContext().fetch(FetchDescriptor<RoutineLog>())
                let logsByTaskID = Dictionary(grouping: logs, by: \.taskID)
                let referenceDate = now
                let selectableTasks = tasks.filter {
                    TaskChoiceCandidateRanking.isCurrentlySelectable(
                        $0,
                        referenceDate: referenceDate,
                        calendar: calendar,
                        logs: logsByTaskID[$0.id] ?? []
                    )
                }
                let relationshipCandidates = RoutineTaskRelationshipCandidate.from(
                    tasks,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
                let unblockedTasks = selectableTasks.filter {
                    !RoutineTaskRelationshipResolution.hasActiveBlocker(
                        for: $0,
                        within: relationshipCandidates
                    )
                }
                let missingData = TaskChoiceCandidateRanking.missingData(for: unblockedTasks)
                guard missingData.isEmpty else {
                    send(.tasksLoaded(.needsData(missingData, candidateCount: unblockedTasks.count)))
                    return
                }

                let ranked = TaskChoiceCandidateRanking.ranked(
                    tasks: unblockedTasks,
                    condition: condition
                )
                guard let recommendedTask = ranked.first else {
                    send(.tasksLoaded(.empty))
                    return
                }
                if let pair = TaskChoiceCandidateRanking.nextComparisonPair(
                    tasks: unblockedTasks,
                    condition: condition
                ) {
                    send(.tasksLoaded(.comparison(pair.0, pair.1, candidateCount: ranked.count)))
                } else {
                    send(.tasksLoaded(.recommendation(recommendedTask, candidateCount: ranked.count)))
                }
            } catch {
                send(.tasksLoadFailed)
            }
        }
    }

    private func saveComparison(
        winner: TaskChoiceCandidate,
        loser: TaskChoiceCandidate
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                guard let winnerTask = try context.fetch(TaskDetailFetchDescriptors.task(for: winner.id)).first,
                      let loserTask = try context.fetch(TaskDetailFetchDescriptors.task(for: loser.id)).first
                else {
                    send(.comparisonSaveFailed)
                    return
                }

                winnerTask.taskChoiceTieBreakScore = TaskChoiceCandidateRanking.nextTieBreakScore(
                    winner: winner,
                    loser: loser
                )
                winnerTask.taskChoiceComparisonCount = incrementComparisonCount(winnerTask.taskChoiceComparisonCount)
                loserTask.taskChoiceComparisonCount = incrementComparisonCount(loserTask.taskChoiceComparisonCount)
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                send(.comparisonSaved(TaskChoiceCandidate(task: winnerTask)))
            } catch {
                send(.comparisonSaveFailed)
            }
        }
    }

    private func incrementComparisonCount(_ value: Int16) -> Int16 {
        value == .max ? value : value + 1
    }
}

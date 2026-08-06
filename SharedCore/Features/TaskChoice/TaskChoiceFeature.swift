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

    init(task: RoutineTask) {
        id = task.id
        title = RoutineTask.trimmedName(task.name) ?? "Untitled task"
        importance = task.importance
        urgency = task.urgency
        pressure = task.pressure
        thinkingNeeded = task.thinkingNeeded
        estimatedDurationMinutes = task.estimatedDurationMinutes
    }
}

enum TaskChoiceCandidateRanking {
    static let maximumCandidateCount = 6

    static func isCurrentlySelectable(
        _ task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
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

    static func shortlist(
        tasks: [RoutineTask],
        condition: TaskChoiceCondition
    ) -> [TaskChoiceCandidate] {
        let ranked = tasks
            .map(TaskChoiceCandidate.init)
            .sorted { lhs, rhs in
                let lhsScore = score(lhs, for: condition)
                let rhsScore = score(rhs, for: condition)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                if titleComparison != .orderedSame {
                    return titleComparison == .orderedAscending
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }

        guard let firstCandidate = ranked.first else { return [] }
        let comparisons = ranked.dropFirst().sorted { lhs, rhs in
            let lhsSimilarity = metadataSimilarity(lhs, firstCandidate)
            let rhsSimilarity = metadataSimilarity(rhs, firstCandidate)
            if lhsSimilarity != rhsSimilarity {
                return lhsSimilarity > rhsSimilarity
            }

            let lhsScore = score(lhs, for: condition)
            let rhsScore = score(rhs, for: condition)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        return [firstCandidate] + Array(comparisons.prefix(maximumCandidateCount - 1))
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

    static func metadataSimilarity(
        _ lhs: TaskChoiceCandidate,
        _ rhs: TaskChoiceCandidate
    ) -> Int {
        var similarity = 0
        if lhs.importance == rhs.importance { similarity += 1 }
        if lhs.urgency == rhs.urgency { similarity += 1 }
        if lhs.pressure == rhs.pressure { similarity += 1 }
        if lhs.thinkingNeeded == rhs.thinkingNeeded { similarity += 1 }
        return similarity
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
            case comparing
            case recommendation
            case empty
            case failure
        }

        var condition = TaskChoiceCondition()
        var phase: Phase = .setup
        /// The short list is intentionally capped, so a pairwise session never retains a full task collection.
        var candidates: [TaskChoiceCandidate] = []
        var currentWinner: TaskChoiceCandidate?
        var nextCandidateIndex = 1
        var alternatives: [TaskChoiceCandidate] = []
        var errorMessage: String?

        var currentChallenger: TaskChoiceCandidate? {
            guard candidates.indices.contains(nextCandidateIndex) else { return nil }
            return candidates[nextCandidateIndex]
        }

        var comparisonNumber: Int {
            min(nextCandidateIndex, max(candidates.count - 1, 0))
        }

        var comparisonCount: Int {
            max(candidates.count - 1, 0)
        }
    }

    @CasePathable
    enum Action: Equatable {
        case availableTimeChanged(TaskChoiceAvailableTime)
        case energyChanged(TaskChoiceEnergy)
        case intentChanged(TaskChoiceIntent)
        case findTasksTapped
        case candidatesLoaded([TaskChoiceCandidate])
        case candidatesLoadFailed
        case preferredTaskSelected(UUID)
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
                state.candidates = []
                state.currentWinner = nil
                state.nextCandidateIndex = 1
                state.alternatives = []
                state.errorMessage = nil
                return loadCandidates(for: state.condition)

            case let .candidatesLoaded(candidates):
                state.candidates = candidates
                state.currentWinner = candidates.first
                state.nextCandidateIndex = 1
                state.alternatives = []
                state.errorMessage = nil
                switch candidates.count {
                case 0:
                    state.phase = .empty
                case 1:
                    state.phase = .recommendation
                default:
                    state.phase = .comparing
                }
                return .none

            case .candidatesLoadFailed:
                state.phase = .failure
                state.errorMessage = "Couldn’t load tasks. Try again."
                return .none

            case let .preferredTaskSelected(taskID):
                guard state.phase == .comparing,
                      let currentWinner = state.currentWinner,
                      let challenger = state.currentChallenger,
                      taskID == currentWinner.id || taskID == challenger.id
                else {
                    return .none
                }

                let losingTask = taskID == currentWinner.id ? challenger : currentWinner
                state.currentWinner = taskID == currentWinner.id ? currentWinner : challenger
                state.alternatives.append(losingTask)
                state.nextCandidateIndex += 1
                if state.currentChallenger == nil {
                    state.phase = .recommendation
                }
                return .none

            case let .taskDetailsTapped(taskID):
                return .send(.delegate(.taskDetailsRequested(taskID)))

            case .startAgainTapped:
                state.phase = .setup
                state.candidates = []
                state.currentWinner = nil
                state.nextCandidateIndex = 1
                state.alternatives = []
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
                let referenceDate = now
                let selectableTasks = tasks.filter {
                    TaskChoiceCandidateRanking.isCurrentlySelectable(
                        $0,
                        referenceDate: referenceDate,
                        calendar: calendar
                    )
                }
                send(.candidatesLoaded(
                    TaskChoiceCandidateRanking.shortlist(tasks: selectableTasks, condition: condition)
                ))
            } catch {
                send(.candidatesLoadFailed)
            }
        }
    }
}

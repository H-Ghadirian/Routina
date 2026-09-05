import ComposableArchitecture
import Foundation

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
            Item(title: "Time estimate", count: estimatedDurationCount),
        ].filter { $0.count > .zero }
    }
}

enum TaskChoicePhase: Equatable {
    case setup
    case loading
    case needsData
    case comparing
    case recommendation
    case empty
    case failure
}

@CasePathable
enum TaskChoiceDelegateAction: Equatable {
    case taskDetailsRequested(UUID)
}

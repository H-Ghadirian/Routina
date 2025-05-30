import Foundation

enum RoutineTaskType: String, CaseIterable, Equatable, Hashable, Sendable {
    case routine = "Routine"
    case todo = "Todo"
}

enum RoutineTaskPriority: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case none = "None"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"

    var title: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .none:
            return 0
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        case .urgent:
            return 4
        }
    }

    var metadataLabel: String? {
        self == .none ? nil : title
    }
}

enum RoutineTaskImportance: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case level1 = "Low"
    case level2 = "Medium"
    case level3 = "High"
    case level4 = "Critical"

    var sortOrder: Int {
        switch self {
        case .level1:
            return 1
        case .level2:
            return 2
        case .level3:
            return 3
        case .level4:
            return 4
        }
    }

    var title: String { rawValue }

    var shortTitle: String {
        switch self {
        case .level1:
            return "L1"
        case .level2:
            return "L2"
        case .level3:
            return "L3"
        case .level4:
            return "L4"
        }
    }
}

enum RoutineTaskUrgency: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case level1 = "Low"
    case level2 = "Medium"
    case level3 = "High"
    case level4 = "Immediate"

    var sortOrder: Int {
        switch self {
        case .level1:
            return 1
        case .level2:
            return 2
        case .level3:
            return 3
        case .level4:
            return 4
        }
    }

    var title: String { rawValue }

    var shortTitle: String {
        switch self {
        case .level1:
            return "L1"
        case .level2:
            return "L2"
        case .level3:
            return "L3"
        case .level4:
            return "L4"
        }
    }
}

struct ImportanceUrgencyFilterCell: Codable, Equatable, Hashable, Identifiable, Sendable {
    var importance: RoutineTaskImportance
    var urgency: RoutineTaskUrgency

    var id: String {
        "\(importance.rawValue)-\(urgency.rawValue)"
    }

    var title: String {
        "\(importance.title) importance • \(urgency.title) urgency"
    }

    var accessibilityLabel: String {
        "\(importance.title) importance and \(urgency.title.lowercased()) urgency"
    }

    func matches(
        importance candidateImportance: RoutineTaskImportance,
        urgency candidateUrgency: RoutineTaskUrgency
    ) -> Bool {
        candidateImportance.sortOrder >= importance.sortOrder
            && candidateUrgency.sortOrder >= urgency.sortOrder
    }
}

extension RoutineTaskPriority {
    var defaultMatrixPosition: (importance: RoutineTaskImportance, urgency: RoutineTaskUrgency) {
        switch self {
        case .none, .medium:
            return (.level2, .level2)
        case .low:
            return (.level1, .level1)
        case .high:
            return (.level3, .level3)
        case .urgent:
            return (.level4, .level4)
        }
    }
}

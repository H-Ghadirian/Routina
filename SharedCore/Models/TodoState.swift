import Foundation

enum TodoState: String, Codable, CaseIterable, Equatable, Sendable, Identifiable {
    var id: String { rawValue }

    static var filterableCases: [TodoState] { [.ready, .inProgress, .blocked, .paused] }


    case ready
    case inProgress
    case blocked
    case done
    case paused

    var displayTitle: String {
        switch self {
        case .ready: return "Ready"
        case .inProgress: return "In Progress"
        case .blocked: return "Blocked"
        case .done: return "Done"
        case .paused: return "Paused"
        }
    }

    var systemImage: String {
        switch self {
        case .ready: return "circle"
        case .inProgress: return "arrow.clockwise.circle.fill"
        case .blocked: return "exclamationmark.circle.fill"
        case .done: return "checkmark.circle.fill"
        case .paused: return "pause.circle.fill"
        }
    }
}

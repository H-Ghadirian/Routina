import SwiftUI

enum TaskDetailRelationshipPresentation {
    static func statusColor(for status: RoutineTaskRelationshipStatus) -> Color {
        switch status {
        case .doneToday, .completedOneOff:
            return .green
        case .overdue:
            return .red
        case .dueToday:
            return .orange
        case .paused:
            return .teal
        case .pendingTodo:
            return .blue
        case .canceledOneOff:
            return .secondary
        case .onTrack:
            return .secondary
        }
    }
}

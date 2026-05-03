import SwiftUI

enum TaskDetailPriorityPresentation {
    static func priorityTint(for priority: RoutineTaskPriority) -> Color {
        switch priority {
        case .none:
            return .secondary
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .urgent:
            return .red
        }
    }

    static func importanceTint(for importance: RoutineTaskImportance) -> Color {
        switch importance {
        case .level1:
            return .green
        case .level2:
            return .yellow
        case .level3:
            return .orange
        case .level4:
            return .red
        }
    }

    static func urgencyTint(for urgency: RoutineTaskUrgency) -> Color {
        switch urgency {
        case .level1:
            return .green
        case .level2:
            return .yellow
        case .level3:
            return .orange
        case .level4:
            return .red
        }
    }

    static func pressureTint(for pressure: RoutineTaskPressure, style: TaskDetailPressureTintStyle) -> Color {
        switch (style, pressure) {
        case (_, .none):
            return .secondary
        case (.compactPill, .low):
            return .teal
        case (.segmentedControl, .low):
            return .green
        case (_, .medium):
            return .orange
        case (_, .high):
            return .red
        }
    }

    static func pressureSystemImage(for pressure: RoutineTaskPressure) -> String {
        switch pressure {
        case .none:
            return "circle"
        case .low:
            return "circle.lefthalf.filled"
        case .medium:
            return "circle.fill"
        case .high:
            return "exclamationmark.circle.fill"
        }
    }

    static func pressureSelectedForeground(for pressure: RoutineTaskPressure) -> Color {
        switch pressure {
        case .none:
            return .primary
        case .medium:
            return .black.opacity(0.84)
        case .low, .high:
            return .white
        }
    }

    static func todoStateTint(for state: TodoState, style: TaskDetailTodoStateTintStyle) -> Color {
        switch (style, state) {
        case (_, .ready):
            return .secondary
        case (_, .inProgress):
            return .blue
        case (.compactPill, .blocked):
            return .orange
        case (.segmentedControl, .blocked):
            return .red
        case (_, .done):
            return .green
        case (.compactPill, .paused):
            return .purple
        case (.segmentedControl, .paused):
            return .teal
        }
    }

    static func todoStateSelectedForeground(for state: TodoState) -> Color {
        switch state {
        case .ready:
            return .primary
        case .inProgress, .blocked, .done, .paused:
            return .white
        }
    }
}

enum TaskDetailPressureTintStyle {
    case compactPill
    case segmentedControl
}

enum TaskDetailTodoStateTintStyle {
    case compactPill
    case segmentedControl
}

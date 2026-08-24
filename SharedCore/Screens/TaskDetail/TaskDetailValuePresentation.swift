import SwiftUI

enum TaskDetailValuePresentation {

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

    static func importanceSelectedForeground(for importance: RoutineTaskImportance) -> Color {
        switch importance {
        case .level2:
            return .black.opacity(0.84)
        case .level1, .level3, .level4:
            return .white
        }
    }

    static func urgencySelectedForeground(for urgency: RoutineTaskUrgency) -> Color {
        switch urgency {
        case .level2:
            return .black.opacity(0.84)
        case .level1, .level3, .level4:
            return .white
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

enum TaskDetailOptionalControlVisibility {
    static func showsEstimateAddAction(for task: RoutineTask) -> Bool {
        task.estimatedDurationMinutes == nil
    }

    static func showsImportance(for task: RoutineTask) -> Bool {
        task.hasExplicitImportance
            || task.importance != .level2
            || hasLegacyExplicitPriority(for: task)
    }

    static func showsUrgency(for task: RoutineTask) -> Bool {
        task.hasExplicitUrgency
            || task.urgency != .level2
            || hasLegacyExplicitPriority(for: task)
    }

    private static func hasLegacyExplicitPriority(for task: RoutineTask) -> Bool {
        guard !task.hasExplicitImportance, !task.hasExplicitUrgency else { return false }
        return task.priority != .none && task.priority != .medium
    }

    static func showsTodoState(for task: RoutineTask) -> Bool {
        guard task.isOneOffTask else { return false }
        return task.todoStateRawValue != nil || task.isPaused
    }

    static func showsTimeSpent(
        for task: RoutineTask,
        hasActiveFocus: Bool = false,
        showsFocusTimer: Bool = false
    ) -> Bool {
        task.actualDurationMinutes != nil || hasActiveFocus || showsFocusTimer
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

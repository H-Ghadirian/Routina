import Foundation

enum HomeTaskListMode: String, CaseIterable, Equatable, Identifiable {
    case all = "All"
    case routines = "Routines"
    case todos = "Todos"

    var id: Self { self }

    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:
            #if os(macOS)
            return "square.grid.2x2"
            #else
            return "square.stack.3d.up"
            #endif
        case .routines:
            return "repeat"
        case .todos:
            return "checklist"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .all:
            return "Show all tasks"
        case .routines:
            return "Show routines"
        case .todos:
            return "Show todos"
        }
    }
}

extension RoutineTask {
    var preferredTaskListMode: HomeTaskListMode {
        switch scheduleMode.taskType {
        case .routine:
            return .routines
        case .todo:
            return .todos
        case .record:
            return .routines
        }
    }
}

import Foundation

enum HomeTaskListMode: String, CaseIterable, Equatable, Identifiable {
    case all = "All"
    case routines = "Routines"
    case todos = "Todos"
    case records = "Records"

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            return rawValue
        case .routines:
            return rawValue
        case .todos:
            return rawValue
        case .records:
            return "Tracking"
        }
    }

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
        case .records:
            return "chart.bar.doc.horizontal"
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
        case .records:
            return "Show tracking"
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
            return .records
        }
    }
}

import Foundation

extension HomeFeature {
    typealias TaskListMode = HomeTaskListMode

    enum TaskDetailCancelID: Hashable, Sendable {
        case task(UUID)
    }

    typealias SelectedTaskReloadGuard = HomeSelectedTaskReloadGuard

    typealias DoneStats = HomeDoneStats

    typealias MoveDirection = HomeTaskMoveDirection

    typealias RoutineDisplay = HomeRoutineDisplay

    struct TaskCreationConfirmation: Equatable, Identifiable {
        let taskID: UUID
        let taskName: String

        var id: UUID { taskID }
    }

    enum MacSidebarSelection: Hashable, Equatable {
        case task(UUID)
        case timelineEntry(UUID)
    }

    enum MacSidebarMode: String, CaseIterable, Identifiable, Equatable {
        case routines = "Routines"
        case board = "Board"
        case goals = "Goals"
        case adventure = "Adventure"
        case timeline = "Timeline"
        case stats = "Stats"
        case backlog = "Backlog"
        case taskLadder = "Task Ladder"
        case settings = "Settings"
        case addTask = "Add Task"

        var id: Self { self }

        static let workspaceModes: [Self] = [
            .routines,
            .backlog,
            .taskLadder,
            .goals,
            .adventure,
            .stats,
        ]
    }

    typealias BoardScope = HomeBoardScope
}

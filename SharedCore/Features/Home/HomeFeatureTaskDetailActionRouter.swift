import ComposableArchitecture
import Foundation

struct HomeFeatureTaskDetailActionRouter<State, Action> {
    var clearTaskSelection: (inout State) -> Void
    var updatePendingChecklistReloadGuard: (UUID, inout State) -> Void
    var updatePendingChecklistUndoReloadGuard: (inout State) -> Void
    var syncSelectedTaskFromTaskDetail: (inout State) -> Void
    var syncSelectedTaskLogs: ([RoutineLog], inout State) -> Void
    var openLinkedTask: (UUID, inout State) -> Effect<Action>
    var openLinkedTaskSheet: (inout State) -> Void

    func handle(
        _ action: TaskDetailFeature.Action,
        state: inout State
    ) -> Effect<Action>? {
        switch action {
        case .routineDeleted:
            clearTaskSelection(&state)
            return .none

        case let .toggleChecklistRunoutItemDone(itemID),
             let .extendChecklistItemRunout(itemID),
             let .toggleChecklistItemCompletion(itemID),
             let .markChecklistItemCompleted(itemID):
            updatePendingChecklistReloadGuard(itemID, &state)
            syncSelectedTaskAndLogs(&state)
            return .none

        case .undoSelectedDateCompletion:
            updatePendingChecklistUndoReloadGuard(&state)
            syncSelectedTaskAndLogs(&state)
            return .none

        case .markAsDone,
             .cancelTodo,
             .removeLogEntry(_),
             .updateTaskDuration(_),
             .updateLogDuration(_, _),
             .revealHeatmapInTaskDetail,
             .confirmAssumedPastDays,
             .confirmUndoCompletion,
             .todoStateChanged(_),
             .confirmBlockedStateCompletion,
             .editSaveTapped,
             .editSaveRejected(_):
            syncSelectedTaskAndLogs(&state)
            return .none

        case let .logsLoaded(logs):
            syncSelectedTaskFromTaskDetail(&state)
            syncSelectedTaskLogs(logs, &state)
            return .none

        case let .openLinkedTask(taskID):
            return openLinkedTask(taskID, &state)

        case .openAddLinkedTask:
            openLinkedTaskSheet(&state)
            return .none

        default:
            return nil
        }
    }

    private func syncSelectedTaskAndLogs(_ state: inout State) {
        syncSelectedTaskFromTaskDetail(&state)
        syncSelectedTaskLogs([], &state)
    }
}

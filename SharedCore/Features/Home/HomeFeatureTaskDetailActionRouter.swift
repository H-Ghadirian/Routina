import ComposableArchitecture
import Foundation

struct HomeFeatureTaskDetailActionRouter<State, Action> {
    var clearTaskSelection: (inout State) -> Void
    var updatePendingChecklistReloadGuard: (UUID, inout State) -> Void
    var updatePendingChecklistUndoReloadGuard: (inout State) -> Void
    var syncSelectedTaskFromTaskDetail: (inout State) -> Void
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

        case let .toggleChecklistItemCompletion(itemID),
             let .markChecklistItemCompleted(itemID):
            updatePendingChecklistReloadGuard(itemID, &state)
            return .none

        case .undoSelectedDateCompletion:
            updatePendingChecklistUndoReloadGuard(&state)
            return .none

        case .logsLoaded:
            syncSelectedTaskFromTaskDetail(&state)
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
}

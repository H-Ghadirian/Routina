import ComposableArchitecture
import Foundation

struct TaskDetailDialogLifecycleActionHandler {
    typealias State = TaskDetailFeature.State
    typealias Action = TaskDetailFeature.Action

    var calendar: Calendar
    var syncEditFormFromTask: (inout State) -> Void
    var loadEditContext: (UUID) -> Effect<Action>

    func selectedDateChanged(_ date: Date, state: inout State) -> Effect<Action> {
        state.selectedDate = calendar.startOfDay(for: date)
        return .none
    }

    func setEditSheet(_ isPresented: Bool, state: inout State) -> Effect<Action> {
        state.isEditSheetPresented = isPresented
        if isPresented {
            syncEditFormFromTask(&state)
            return loadEditContext(state.task.id)
        }
        return .none
    }

    func requestUndoSelectedDateCompletion(state: inout State) -> Effect<Action> {
        state.pendingLogRemovalTimestamp = nil
        state.isUndoCompletionConfirmationPresented = true
        return .none
    }

    func requestRemoveLogEntry(_ timestamp: Date, state: inout State) -> Effect<Action> {
        state.pendingLogRemovalTimestamp = timestamp
        state.isUndoCompletionConfirmationPresented = true
        return .none
    }

    func setDeleteConfirmation(_ isPresented: Bool, state: inout State) -> Effect<Action> {
        state.isDeleteConfirmationPresented = isPresented
        return .none
    }

    func setUndoCompletionConfirmation(
        _ isPresented: Bool,
        state: inout State
    ) -> Effect<Action> {
        state.isUndoCompletionConfirmationPresented = isPresented
        if !isPresented {
            state.pendingLogRemovalTimestamp = nil
        }
        return .none
    }

    func routineDeleted(state: inout State) -> Effect<Action> {
        state.isEditSheetPresented = false
        state.shouldDismissAfterDelete = true
        return .none
    }

    func deleteDismissHandled(state: inout State) -> Effect<Action> {
        state.shouldDismissAfterDelete = false
        return .none
    }
}

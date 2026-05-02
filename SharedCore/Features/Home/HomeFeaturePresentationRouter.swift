import Foundation

protocol HomeFeaturePresentationRoutingState {
    var selection: HomeSelectionState { get set }
    var presentation: HomePresentationState { get set }
}

struct HomeFeaturePresentationRouter<State: HomeFeaturePresentationRoutingState> {
    func requestDeleteTasks(_ ids: [UUID], state: inout State) {
        let uniqueIDs = HomeTaskSupport.uniqueTaskIDs(ids)
        guard !uniqueIDs.isEmpty else { return }
        state.presentation.pendingDeleteTaskIDs = uniqueIDs
        state.presentation.isDeleteConfirmationPresented = true
    }

    func setDeleteConfirmation(_ isPresented: Bool, state: inout State) {
        state.presentation.isDeleteConfirmationPresented = isPresented
        if !isPresented {
            state.presentation.pendingDeleteTaskIDs = []
        }
    }

    func consumePendingDeleteTaskIDs(state: inout State) -> [UUID] {
        let ids = state.presentation.pendingDeleteTaskIDs
        state.presentation.pendingDeleteTaskIDs = []
        state.presentation.isDeleteConfirmationPresented = false
        return ids
    }

    func setFilterDetailPresented(_ isPresented: Bool, state: inout State) {
        state.presentation.isMacFilterDetailPresented = isPresented
        if isPresented {
            state.presentation.isAddRoutineSheetPresented = false
            state.presentation.addRoutineState = nil
            // Keep existing behavior: clear the list selection identity so tapping
            // the same task can still trigger a fresh selection event later.
            state.selection.selectedTaskID = nil
        }
    }
}

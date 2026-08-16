import ComposableArchitecture
import Foundation

struct HomeSelectionState: Equatable {
    var selectedTaskID: UUID? = nil
    var taskDetailState: TaskDetailFeature.State? = nil
    var taskDetailEffectTaskID: UUID? = nil
    var selectedTaskReloadGuard: HomeSelectedTaskReloadGuard? = nil
    var pendingSelectedChecklistReloadGuardTaskID: UUID? = nil

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.selectedTaskID == rhs.selectedTaskID
            && lhs.taskDetailState == rhs.taskDetailState
            && lhs.selectedTaskReloadGuard == rhs.selectedTaskReloadGuard
            && lhs.pendingSelectedChecklistReloadGuardTaskID == rhs.pendingSelectedChecklistReloadGuardTaskID
    }
}

struct HomePresentationState: Equatable {
    var isAddRoutineSheetPresented: Bool = false
    var addRoutineState: AddRoutineFeature.State? = nil
    var pendingDeleteTaskIDs: [UUID] = []
    var isDeleteConfirmationPresented: Bool = false
    var isMacFilterDetailPresented: Bool = false
}

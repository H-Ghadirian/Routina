import ComposableArchitecture
import Foundation

struct HomeSelectionState: Equatable {
    var selectedTaskID: UUID? = nil
    var taskDetailState: TaskDetailFeature.State? = nil
    var selectedTaskReloadGuard: HomeSelectedTaskReloadGuard? = nil
    var pendingSelectedChecklistReloadGuardTaskID: UUID? = nil
}

struct HomePresentationState: Equatable {
    var isAddRoutineSheetPresented: Bool = false
    var addRoutineState: AddRoutineFeature.State? = nil
    var pendingDeleteTaskIDs: [UUID] = []
    var isDeleteConfirmationPresented: Bool = false
    var isMacFilterDetailPresented: Bool = false
}

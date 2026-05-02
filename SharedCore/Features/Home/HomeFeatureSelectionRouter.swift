import ComposableArchitecture
import Foundation

protocol HomeFeatureSelectionRoutingState {
    var routineTasks: [RoutineTask] { get set }
    var selection: HomeSelectionState { get set }
    var presentation: HomePresentationState { get set }
}

struct HomeFeatureSelectionRouter<State: HomeFeatureSelectionRoutingState, Action> {
    var now: Date
    var calendar: Calendar
    var makeTaskDetailState: (RoutineTask) -> TaskDetailFeature.State
    var refreshDisplays: (inout State) -> Void
    var refreshTaskDetailAction: () -> Action
    var synchronizePlatformSelection: (inout State, UUID?) -> Void = { _, _ in }

    func setSelectedTask(_ taskID: UUID?, state: inout State) -> Effect<Action> {
        if let taskID,
           state.selection.selectedTaskID == taskID,
           state.selection.taskDetailState?.task.id == taskID {
            state.presentation.isMacFilterDetailPresented = false
            return .none
        }

        state.selection.selectedTaskID = taskID
        if taskID != nil {
            state.presentation.isMacFilterDetailPresented = false
        }
        synchronizePlatformSelection(&state, taskID)
        _ = HomeSelectionEditor.selectTask(
            taskID: taskID,
            tasks: state.routineTasks,
            selection: &state.selection,
            makeTaskDetailState: makeTaskDetailState
        )
        return refreshSelectedTaskDetailEffect(for: state)
    }

    func clearTaskSelection(_ state: inout State) {
        HomeSelectionEditor.clearTaskSelection(&state.selection)
    }

    func refreshSelectedTaskDetailState(_ state: inout State) {
        HomeDetailSelectionSupport.refreshSelectedTaskDetailState(
            selection: &state.selection,
            tasks: state.routineTasks,
            now: now,
            calendar: calendar,
            makeTaskDetailState: makeTaskDetailState
        )
    }

    func updatePendingChecklistReloadGuard(for itemID: UUID, state: inout State) {
        HomeDetailSelectionSupport.updatePendingChecklistReloadGuard(
            for: itemID,
            selection: &state.selection,
            now: now,
            calendar: calendar
        )
    }

    func updatePendingChecklistUndoReloadGuard(_ state: inout State) {
        HomeDetailSelectionSupport.updatePendingChecklistUndoReloadGuard(selection: &state.selection)
    }

    func syncSelectedTaskFromTaskDetail(_ state: inout State) {
        var selection = state.selection
        var routineTasks = state.routineTasks
        if HomeDetailSelectionSupport.syncSelectedTaskFromDetail(
            selection: &selection,
            tasks: &routineTasks
        ) {
            state.selection = selection
            state.routineTasks = routineTasks
            refreshDisplays(&state)
        }
    }

    func openLinkedTask(_ taskID: UUID, state: inout State) -> Effect<Action> {
        guard HomeSelectionEditor.selectTask(
            taskID: taskID,
            tasks: state.routineTasks,
            selection: &state.selection,
            makeTaskDetailState: makeTaskDetailState
        ) else {
            return .none
        }
        return refreshSelectedTaskDetailEffect(for: state)
    }

    func refreshSelectedTaskDetailEffect(for state: State) -> Effect<Action> {
        guard state.selection.taskDetailState != nil else { return .none }
        return .send(refreshTaskDetailAction())
    }
}

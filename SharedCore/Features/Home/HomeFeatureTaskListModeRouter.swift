import Foundation

protocol HomeFeatureTaskListModeRoutingState {
    associatedtype TaskListModeValue: Equatable & RawRepresentable where TaskListModeValue.RawValue == String

    var routineTasks: [RoutineTask] { get }
    var selection: HomeSelectionState { get set }
    var presentation: HomePresentationState { get set }
    var hideUnavailableRoutines: Bool { get set }
    var taskListMode: TaskListModeValue { get set }
    var taskFilters: HomeTaskFiltersState { get set }
}

struct HomeFeatureTaskListModeRouter<State: HomeFeatureTaskListModeRoutingState> {
    var setHideUnavailableRoutines: (Bool) -> Void
    var persistTemporaryViewState: (State) -> Void
    var synchronizePlatformSelectionAfterModeChange: (inout State) -> Void = { _ in }

    func changeMode(_ mode: State.TaskListModeValue, state: inout State) {
        let oldMode = state.taskListMode
        var taskFilters = state.taskFilters
        var hideUnavailableRoutines = state.hideUnavailableRoutines
        let didResetHideUnavailableRoutines = HomeFilterEditor.transitionTaskListMode(
            from: oldMode.rawValue,
            to: mode.rawValue,
            taskFilters: &taskFilters,
            hideUnavailableRoutines: &hideUnavailableRoutines
        )
        state.taskFilters = taskFilters
        state.hideUnavailableRoutines = hideUnavailableRoutines
        if didResetHideUnavailableRoutines {
            setHideUnavailableRoutines(false)
        }
        state.taskListMode = mode
        state.presentation.isMacFilterDetailPresented = false
        HomeDetailSelectionSupport.clearSelectionIfNeededForTaskListMode(
            selection: &state.selection,
            tasks: state.routineTasks,
            modeRawValue: mode.rawValue
        )
        if state.selection.selectedTaskID == nil {
            synchronizePlatformSelectionAfterModeChange(&state)
        }
        persistTemporaryViewState(state)
    }
}

import ComposableArchitecture
import Foundation

struct HomeFeatureMacNavigationRouter {
    var setHideUnavailableRoutines: (Bool) -> Void
    var persistTemporaryViewState: (HomeFeature.State) -> Void

    func sidebarModeChanged(
        _ mode: HomeFeature.MacSidebarMode,
        state: inout HomeFeature.State
    ) -> Effect<HomeFeature.Action> {
        state.macSidebarMode = mode
        state.presentation.isMacFilterDetailPresented = false
        switch mode {
        case .routines:
            dismissAddRoutineSheet(&state)
            state.macSidebarSelection = state.selection.selectedTaskID.map(HomeFeature.MacSidebarSelection.task)
            if let effect = taskListModeSyncEffectForSelectedTask(state) {
                return effect
            }

        case .board:
            dismissAddRoutineSheet(&state)
            if let taskID = state.selection.selectedTaskID,
               let task = state.routineTasks.first(where: { $0.id == taskID }),
               task.isOneOffTask {
                state.macSidebarSelection = .task(taskID)
            } else {
                state.macSidebarSelection = nil
                HomeSelectionEditor.clearTaskSelection(&state.selection)
            }
            if state.taskListMode != .todos {
                return .send(.taskListModeChanged(.todos))
            }

        case .goals, .timeline, .stats, .settings:
            dismissAddRoutineSheet(&state)
            state.macSidebarSelection = nil
            HomeSelectionEditor.clearTaskSelection(&state.selection)
            if mode == .settings && state.selectedSettingsSection == nil {
                state.selectedSettingsSection = .notifications
            }

        case .addTask:
            state.macSidebarSelection = nil
            dismissAddRoutineSheet(&state)
        }
        persistTemporaryViewState(state)
        return .none
    }

    func sidebarSelectionChanged(
        _ selection: HomeFeature.MacSidebarSelection?,
        state: inout HomeFeature.State
    ) -> Effect<HomeFeature.Action> {
        state.macSidebarSelection = selection
        dismissAddRoutineSheet(&state)
        state.presentation.isMacFilterDetailPresented = false
        switch selection {
        case let .task(taskID):
            if state.macSidebarMode != .board {
                state.macSidebarMode = .routines
            }
            alignTaskListModeForSelectedTask(taskID, state: &state)
            return .send(.setSelectedTask(taskID))

        case .timelineEntry:
            state.macSidebarMode = .timeline
            // Task resolution requires @Query data; the view sends .setSelectedTask.
            return .none

        case nil:
            if state.macSidebarMode == .routines {
                return .send(.setSelectedTask(nil))
            }
            return .none
        }
    }

    func selectedSettingsSectionChanged(
        _ section: SettingsMacSection?,
        state: inout HomeFeature.State
    ) -> Effect<HomeFeature.Action> {
        state.selectedSettingsSection = section
        persistTemporaryViewState(state)
        return .none
    }

    private func dismissAddRoutineSheet(_ state: inout HomeFeature.State) {
        if state.presentation.isAddRoutineSheetPresented {
            state.presentation.isAddRoutineSheetPresented = false
            state.presentation.addRoutineState = nil
        }
    }

    private func taskListModeSyncEffectForSelectedTask(_ state: HomeFeature.State) -> Effect<HomeFeature.Action>? {
        guard let taskID = state.selection.selectedTaskID,
              let task = state.routineTasks.first(where: { $0.id == taskID }) else {
            return nil
        }
        let newMode: HomeFeature.TaskListMode = task.isOneOffTask ? .todos : .routines
        guard newMode != state.taskListMode else { return nil }
        return .send(.taskListModeChanged(newMode))
    }

    private func alignTaskListModeForSelectedTask(
        _ taskID: UUID,
        state: inout HomeFeature.State
    ) {
        guard let task = state.routineTasks.first(where: { $0.id == taskID }) else { return }
        let newMode: HomeFeature.TaskListMode = task.isOneOffTask ? .todos : .routines
        guard state.taskListMode != .all, newMode != state.taskListMode else { return }

        let oldMode = state.taskListMode
        var taskFilters = state.taskFilters
        var hideUnavailableRoutines = state.hideUnavailableRoutines
        let didResetHideUnavailableRoutines = HomeFilterEditor.transitionTaskListMode(
            from: oldMode.rawValue,
            to: newMode.rawValue,
            taskFilters: &taskFilters,
            hideUnavailableRoutines: &hideUnavailableRoutines
        )
        state.taskFilters = taskFilters
        state.hideUnavailableRoutines = hideUnavailableRoutines
        if didResetHideUnavailableRoutines {
            setHideUnavailableRoutines(false)
        }
        state.taskListMode = newMode
        persistTemporaryViewState(state)
    }
}

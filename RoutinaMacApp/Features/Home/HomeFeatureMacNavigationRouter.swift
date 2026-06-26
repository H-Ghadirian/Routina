import ComposableArchitecture
import Foundation

struct HomeFeatureMacNavigationRouter {
    var setHideUnavailableRoutines: (Bool) -> Void
    var persistTemporaryViewState: (HomeFeature.State) -> Void

    func sidebarModeChanged(
        _ mode: HomeFeature.MacSidebarMode,
        state: inout HomeFeature.State
    ) -> Effect<HomeFeature.Action> {
        let resolvedMode: HomeFeature.MacSidebarMode = mode
        let previousSidebarSelection = state.macSidebarSelection
        state.macSidebarMode = resolvedMode
        state.presentation.isMacFilterDetailPresented = false
        switch resolvedMode {
        case .routines:
            dismissAddRoutineSheet(&state)
            state.macSidebarSelection = state.selection.selectedTaskID.map(HomeFeature.MacSidebarSelection.task)
            if !previousSidebarSelection.isTimelineEntry,
               let effect = taskListModeSyncEffectForSelectedTask(state) {
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

        case .goals, .adventure, .timeline, .stats, .settings:
            dismissAddRoutineSheet(&state)
            state.macSidebarSelection = nil
            HomeSelectionEditor.clearTaskSelection(&state.selection)
            if resolvedMode == .settings && state.selectedSettingsSection == nil {
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
            selectTaskInSidebar(taskID, state: &state)
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
        state.selectedSettingsSection = section?.resolvedNavigationSection
        persistTemporaryViewState(state)
        return .none
    }

    func openTaskDeepLink(
        _ taskID: UUID,
        state: inout HomeFeature.State,
        setSelectedTask: (UUID, inout HomeFeature.State) -> Effect<HomeFeature.Action>
    ) -> Effect<HomeFeature.Action> {
        guard state.routineTasks.contains(where: { $0.id == taskID }) else {
            return .none
        }

        state.macSidebarMode = .routines
        state.presentation.isMacFilterDetailPresented = false
        selectTaskInSidebar(taskID, state: &state)
        return setSelectedTask(taskID, &state)
    }

    func openNoteDeepLink(
        _ noteID: UUID,
        state: inout HomeFeature.State
    ) -> Effect<HomeFeature.Action> {
        state.macSidebarMode = .timeline
        state.macSidebarSelection = .timelineEntry(noteID)
        state.presentation.isMacFilterDetailPresented = false
        state.presentation.isAddRoutineSheetPresented = false
        state.presentation.addRoutineState = nil
        state.selectedTimelineRange = .all
        state.selectedTimelineFilterType = .notes
        state.selectedTimelineTags = []
        state.selectedTimelineIncludeTagMatchMode = .all
        state.selectedTimelineExcludedTags = []
        state.selectedTimelineExcludeTagMatchMode = .any
        state.selectedTimelineImportanceUrgencyFilter = nil
        state.selectedTimelineMediaFilter = .all
        HomeSelectionEditor.clearTaskSelection(&state.selection)
        persistTemporaryViewState(state)
        return .none
    }

    func openEventDeepLink(
        _ eventID: UUID,
        state: inout HomeFeature.State
    ) -> Effect<HomeFeature.Action> {
        state.macSidebarMode = .timeline
        state.macSidebarSelection = .timelineEntry(eventID)
        state.presentation.isMacFilterDetailPresented = false
        state.presentation.isAddRoutineSheetPresented = false
        state.presentation.addRoutineState = nil
        state.selectedTimelineRange = .all
        state.selectedTimelineFilterType = .events
        state.selectedTimelineTags = []
        state.selectedTimelineIncludeTagMatchMode = .all
        state.selectedTimelineExcludedTags = []
        state.selectedTimelineExcludeTagMatchMode = .any
        state.selectedTimelineImportanceUrgencyFilter = nil
        state.selectedTimelineMediaFilter = .all
        HomeSelectionEditor.clearTaskSelection(&state.selection)
        persistTemporaryViewState(state)
        return .none
    }

    func openSprintDeepLink(
        _ sprintID: UUID,
        state: inout HomeFeature.State
    ) -> Effect<HomeFeature.Action> {
        guard state.sprintBoardData.sprints.contains(where: { $0.id == sprintID }) else {
            return .none
        }

        state.macSidebarMode = .routines
        state.macSidebarSelection = nil
        state.presentation.isMacFilterDetailPresented = false
        HomeSelectionEditor.clearTaskSelection(&state.selection)
        state.selectedBoardScope = .sprint(sprintID)

        guard state.taskListMode != .todos else { return .none }
        return .send(.taskListModeChanged(.todos))
    }

    func openSleepDeepLink(
        _ sleepID: UUID,
        state: inout HomeFeature.State
    ) -> Effect<HomeFeature.Action> {
        state.macSidebarMode = .routines
        state.macSidebarSelection = nil
        state.pendingSleepPlannerSessionID = sleepID
        state.presentation.isMacFilterDetailPresented = false
        state.presentation.isAddRoutineSheetPresented = false
        state.presentation.addRoutineState = nil
        HomeSelectionEditor.clearTaskSelection(&state.selection)
        persistTemporaryViewState(state)
        return .none
    }

    func selectTaskInSidebar(
        _ taskID: UUID,
        state: inout HomeFeature.State
    ) {
        state.macSidebarSelection = .task(taskID)
        dismissAddRoutineSheet(&state)
        state.presentation.isMacFilterDetailPresented = false
        if state.macSidebarMode != .board {
            state.macSidebarMode = .routines
        }
        alignTaskListModeForSelectedTask(taskID, state: &state)
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

private extension HomeFeature.MacSidebarSelection? {
    var isTimelineEntry: Bool {
        switch self {
        case .some(.timelineEntry):
            return true
        case .some(.task), .none:
            return false
        }
    }
}

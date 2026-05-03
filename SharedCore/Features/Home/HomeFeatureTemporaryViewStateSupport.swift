import Foundation

protocol HomeFeatureTemporaryViewState {
    associatedtype TaskListModeValue: RawRepresentable where TaskListModeValue.RawValue == String

    var hideUnavailableRoutines: Bool { get set }
    var taskListMode: TaskListModeValue { get set }
    var taskFilters: HomeTaskFiltersState { get set }
    var timelineFilters: HomeTimelineFiltersState { get set }
    var statsFilters: HomeStatsFiltersState { get set }
}

enum HomeFeatureTemporaryViewStateSupport {
    static func applyBase<State: HomeFeatureTemporaryViewState>(
        _ persistedState: TemporaryViewState?,
        to state: inout State,
        defaultHideUnavailableRoutines: Bool
    ) -> HomeTemporaryViewStateValues {
        let restoredState = HomeTemporaryViewStateMapper.restore(
            from: persistedState,
            defaultHideUnavailableRoutines: defaultHideUnavailableRoutines
        )
        state.hideUnavailableRoutines = restoredState.hideUnavailableRoutines
        state.taskFilters = restoredState.taskFilters
        state.timelineFilters = restoredState.timelineFilters
        state.statsFilters = restoredState.statsFilters

        if let rawValue = restoredState.taskListModeRawValue,
           let mode = State.TaskListModeValue(rawValue: rawValue) {
            state.taskListMode = mode
        }

        return restoredState
    }

    static func makeValues<State: HomeFeatureTemporaryViewState>(
        from state: State,
        macSidebarModeRawValue: String?,
        macSelectedSettingsSectionRawValue: String?
    ) -> HomeTemporaryViewStateValues {
        HomeTemporaryViewStateValues(
            hideUnavailableRoutines: state.hideUnavailableRoutines,
            taskListModeRawValue: state.taskListMode.rawValue,
            taskFilters: state.taskFilters,
            timelineFilters: state.timelineFilters,
            statsFilters: state.statsFilters,
            macSidebarModeRawValue: macSidebarModeRawValue,
            macSelectedSettingsSectionRawValue: macSelectedSettingsSectionRawValue
        )
    }
}

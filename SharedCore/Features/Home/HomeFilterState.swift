import Foundation

struct HomeTaskFiltersState: Equatable {
    var selectedFilter: RoutineListFilter = .all
    var selectedTag: String? = nil
    var excludedTags: Set<String> = []
    var selectedManualPlaceFilterID: UUID? = nil
    var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
    var selectedTodoStateFilter: TodoState? = nil
    var tabFilterSnapshots: [String: TabFilterStateManager.Snapshot] = [:]
    var isFilterSheetPresented: Bool = false

    var currentSnapshot: TabFilterStateManager.Snapshot {
        TabFilterStateManager.Snapshot(
            selectedTag: selectedTag,
            excludedTags: excludedTags,
            selectedFilter: selectedFilter,
            selectedManualPlaceFilterID: selectedManualPlaceFilterID,
            selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter,
            selectedTodoStateFilter: selectedTodoStateFilter
        )
    }

    mutating func apply(snapshot: TabFilterStateManager.Snapshot) {
        selectedTag = snapshot.selectedTag
        excludedTags = snapshot.excludedTags
        selectedFilter = snapshot.selectedFilter
        selectedManualPlaceFilterID = snapshot.selectedManualPlaceFilterID
        selectedImportanceUrgencyFilter = snapshot.selectedImportanceUrgencyFilter
        selectedTodoStateFilter = snapshot.selectedTodoStateFilter
    }
}

struct HomeTimelineFiltersState: Equatable {
    var selectedRange: TimelineRange = .all
    var selectedFilterType: TimelineFilterType = .all
    var selectedTag: String? = nil
    var selectedExcludedTags: Set<String> = []
    var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
}

struct HomeStatsFiltersState: Equatable {
    var selectedRange: DoneChartRange = .week
    var selectedTag: String? = nil
}

struct HomeTemporaryViewStateValues: Equatable {
    var hideUnavailableRoutines: Bool
    var taskListModeRawValue: String?
    var taskFilters: HomeTaskFiltersState
    var timelineFilters: HomeTimelineFiltersState
    var statsFilters: HomeStatsFiltersState
    var macSidebarModeRawValue: String?
    var macSelectedSettingsSectionRawValue: String?
}

enum HomeTemporaryViewStateMapper {
    static func restore(
        from persistedState: TemporaryViewState?,
        defaultHideUnavailableRoutines: Bool
    ) -> HomeTemporaryViewStateValues {
        let persistedState = persistedState ?? .default
        var taskFilters = HomeTaskFiltersState(
            selectedFilter: persistedState.homeSelectedFilter,
            selectedTag: persistedState.homeSelectedTag,
            excludedTags: persistedState.homeExcludedTags,
            selectedManualPlaceFilterID: persistedState.homeSelectedManualPlaceFilterID,
            selectedImportanceUrgencyFilter: persistedState.homeSelectedImportanceUrgencyFilter,
            selectedTodoStateFilter: persistedState.homeSelectedTodoStateFilter,
            tabFilterSnapshots: persistedState.homeTabFilterSnapshots,
            isFilterSheetPresented: false
        )

        if let rawValue = persistedState.homeTaskListModeRawValue,
           let snapshot = taskFilters.tabFilterSnapshots[rawValue] {
            taskFilters.apply(snapshot: snapshot)
        }

        return HomeTemporaryViewStateValues(
            hideUnavailableRoutines: persistedState.hideUnavailableRoutines || defaultHideUnavailableRoutines,
            taskListModeRawValue: persistedState.homeTaskListModeRawValue,
            taskFilters: taskFilters,
            timelineFilters: HomeTimelineFiltersState(
                selectedRange: persistedState.homeSelectedTimelineRange,
                selectedFilterType: persistedState.homeSelectedTimelineFilterType,
                selectedTag: persistedState.homeSelectedTimelineTag,
                selectedExcludedTags: persistedState.homeSelectedTimelineExcludedTags,
                selectedImportanceUrgencyFilter: persistedState.homeSelectedTimelineImportanceUrgencyFilter
            ),
            statsFilters: HomeStatsFiltersState(
                selectedRange: persistedState.statsSelectedRange,
                selectedTag: persistedState.statsSelectedTag
            ),
            macSidebarModeRawValue: persistedState.macHomeSidebarModeRawValue,
            macSelectedSettingsSectionRawValue: persistedState.macSelectedSettingsSectionRawValue
        )
    }

    static func makeTemporaryViewState(
        existing: TemporaryViewState?,
        values: HomeTemporaryViewStateValues
    ) -> TemporaryViewState {
        let existing = existing ?? .default
        var taskFilters = values.taskFilters

        if let rawValue = values.taskListModeRawValue {
            taskFilters.tabFilterSnapshots[rawValue] = taskFilters.currentSnapshot
        }

        return TemporaryViewState(
            selectedAppTabRawValue: existing.selectedAppTabRawValue,
            homeTaskListModeRawValue: values.taskListModeRawValue,
            homeSelectedFilter: taskFilters.selectedFilter,
            homeSelectedTag: taskFilters.selectedTag,
            homeExcludedTags: taskFilters.excludedTags,
            homeSelectedManualPlaceFilterID: taskFilters.selectedManualPlaceFilterID,
            homeSelectedImportanceUrgencyFilter: taskFilters.selectedImportanceUrgencyFilter,
            homeSelectedTodoStateFilter: taskFilters.selectedTodoStateFilter,
            homeTabFilterSnapshots: taskFilters.tabFilterSnapshots,
            hideUnavailableRoutines: values.hideUnavailableRoutines,
            homeSelectedTimelineRange: values.timelineFilters.selectedRange,
            homeSelectedTimelineFilterType: values.timelineFilters.selectedFilterType,
            homeSelectedTimelineTag: values.timelineFilters.selectedTag,
            homeSelectedTimelineExcludedTags: values.timelineFilters.selectedExcludedTags,
            homeSelectedTimelineImportanceUrgencyFilter: values.timelineFilters.selectedImportanceUrgencyFilter,
            macHomeSidebarModeRawValue: values.macSidebarModeRawValue ?? existing.macHomeSidebarModeRawValue,
            macSelectedSettingsSectionRawValue: values.macSelectedSettingsSectionRawValue ?? existing.macSelectedSettingsSectionRawValue,
            timelineSelectedRange: existing.timelineSelectedRange,
            timelineFilterType: existing.timelineFilterType,
            timelineSelectedTag: existing.timelineSelectedTag,
            timelineSelectedImportanceUrgencyFilter: existing.timelineSelectedImportanceUrgencyFilter,
            statsSelectedRange: existing.statsSelectedRange,
            statsSelectedTag: existing.statsSelectedTag,
            statsExcludedTags: existing.statsExcludedTags,
            statsSelectedImportanceUrgencyFilter: existing.statsSelectedImportanceUrgencyFilter,
            statsTaskTypeFilterRawValue: existing.statsTaskTypeFilterRawValue
        )
    }
}

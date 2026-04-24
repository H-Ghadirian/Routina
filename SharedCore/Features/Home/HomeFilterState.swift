import Foundation

struct HomeTaskFiltersState: Equatable {
    var selectedFilter: RoutineListFilter = .all
    var selectedTag: String? = nil
    var selectedTags: Set<String> = []
    var includeTagMatchMode: RoutineTagMatchMode = .all
    var excludedTags: Set<String> = []
    var excludeTagMatchMode: RoutineTagMatchMode = .any
    var selectedManualPlaceFilterID: UUID? = nil
    var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
    var selectedTodoStateFilter: TodoState? = nil
    var taskListViewMode: HomeTaskListViewMode = .all
    var tabFilterSnapshots: [String: TabFilterStateManager.Snapshot] = [:]
    var isFilterSheetPresented: Bool = false

    var currentSnapshot: TabFilterStateManager.Snapshot {
        TabFilterStateManager.Snapshot(
            selectedTag: selectedTag,
            selectedTags: effectiveSelectedTags,
            includeTagMatchMode: includeTagMatchMode,
            excludedTags: excludedTags,
            excludeTagMatchMode: excludeTagMatchMode,
            selectedFilter: selectedFilter,
            selectedManualPlaceFilterID: selectedManualPlaceFilterID,
            selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter,
            selectedTodoStateFilter: selectedTodoStateFilter,
            taskListViewMode: taskListViewMode
        )
    }

    var effectiveSelectedTags: Set<String> {
        if !selectedTags.isEmpty { return selectedTags }
        return selectedTag.map { [$0] } ?? []
    }

    mutating func setSelectedTag(_ tag: String?) {
        selectedTag = tag
        selectedTags = tag.map { [$0] } ?? []
    }

    mutating func setSelectedTags(_ tags: Set<String>) {
        selectedTags = tags
        selectedTag = tags.sorted().first
    }

    mutating func apply(snapshot: TabFilterStateManager.Snapshot) {
        selectedTag = snapshot.selectedTag
        selectedTags = snapshot.selectedTags
        includeTagMatchMode = snapshot.includeTagMatchMode
        excludedTags = snapshot.excludedTags
        excludeTagMatchMode = snapshot.excludeTagMatchMode
        selectedFilter = snapshot.selectedFilter
        selectedManualPlaceFilterID = snapshot.selectedManualPlaceFilterID
        selectedImportanceUrgencyFilter = snapshot.selectedImportanceUrgencyFilter
        selectedTodoStateFilter = snapshot.selectedTodoStateFilter
        taskListViewMode = snapshot.taskListViewMode
    }
}

struct HomeTimelineFiltersState: Equatable {
    var selectedRange: TimelineRange = .all
    var selectedFilterType: TimelineFilterType = .all
    var selectedTag: String? = nil
    var selectedTags: Set<String> = []
    var includeTagMatchMode: RoutineTagMatchMode = .all
    var selectedExcludedTags: Set<String> = []
    var excludeTagMatchMode: RoutineTagMatchMode = .any
    var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil

    var effectiveSelectedTags: Set<String> {
        if !selectedTags.isEmpty { return selectedTags }
        return selectedTag.map { [$0] } ?? []
    }

    mutating func setSelectedTag(_ tag: String?) {
        selectedTag = tag
        selectedTags = tag.map { [$0] } ?? []
    }

    mutating func setSelectedTags(_ tags: Set<String>) {
        selectedTags = tags
        selectedTag = tags.sorted().first
    }
}

struct HomeStatsFiltersState: Equatable {
    var selectedRange: DoneChartRange = .week
    var selectedTag: String? = nil
    var selectedTags: Set<String> = []
    var includeTagMatchMode: RoutineTagMatchMode = .all

    var effectiveSelectedTags: Set<String> {
        if !selectedTags.isEmpty { return selectedTags }
        return selectedTag.map { [$0] } ?? []
    }

    mutating func setSelectedTag(_ tag: String?) {
        selectedTag = tag
        selectedTags = tag.map { [$0] } ?? []
    }

    mutating func setSelectedTags(_ tags: Set<String>) {
        selectedTags = tags
        selectedTag = tags.sorted().first
    }
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
            selectedTags: persistedState.homeSelectedTags,
            includeTagMatchMode: persistedState.homeIncludeTagMatchMode,
            excludedTags: persistedState.homeExcludedTags,
            excludeTagMatchMode: persistedState.homeExcludeTagMatchMode,
            selectedManualPlaceFilterID: persistedState.homeSelectedManualPlaceFilterID,
            selectedImportanceUrgencyFilter: persistedState.homeSelectedImportanceUrgencyFilter,
            selectedTodoStateFilter: persistedState.homeSelectedTodoStateFilter,
            taskListViewMode: persistedState.homeTaskListViewMode,
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
                selectedTags: persistedState.homeSelectedTimelineTags,
                includeTagMatchMode: persistedState.homeTimelineIncludeTagMatchMode,
                selectedExcludedTags: persistedState.homeSelectedTimelineExcludedTags,
                excludeTagMatchMode: persistedState.homeTimelineExcludeTagMatchMode,
                selectedImportanceUrgencyFilter: persistedState.homeSelectedTimelineImportanceUrgencyFilter
            ),
            statsFilters: HomeStatsFiltersState(
                selectedRange: persistedState.statsSelectedRange,
                selectedTag: persistedState.statsSelectedTag,
                selectedTags: persistedState.statsSelectedTags,
                includeTagMatchMode: persistedState.statsIncludeTagMatchMode
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
            homeSelectedTags: taskFilters.effectiveSelectedTags,
            homeIncludeTagMatchMode: taskFilters.includeTagMatchMode,
            homeExcludedTags: taskFilters.excludedTags,
            homeExcludeTagMatchMode: taskFilters.excludeTagMatchMode,
            homeSelectedManualPlaceFilterID: taskFilters.selectedManualPlaceFilterID,
            homeSelectedImportanceUrgencyFilter: taskFilters.selectedImportanceUrgencyFilter,
            homeSelectedTodoStateFilter: taskFilters.selectedTodoStateFilter,
            homeTaskListViewMode: taskFilters.taskListViewMode,
            homeTabFilterSnapshots: taskFilters.tabFilterSnapshots,
            hideUnavailableRoutines: values.hideUnavailableRoutines,
            homeSelectedTimelineRange: values.timelineFilters.selectedRange,
            homeSelectedTimelineFilterType: values.timelineFilters.selectedFilterType,
            homeSelectedTimelineTag: values.timelineFilters.selectedTag,
            homeSelectedTimelineTags: values.timelineFilters.effectiveSelectedTags,
            homeTimelineIncludeTagMatchMode: values.timelineFilters.includeTagMatchMode,
            homeSelectedTimelineExcludedTags: values.timelineFilters.selectedExcludedTags,
            homeTimelineExcludeTagMatchMode: values.timelineFilters.excludeTagMatchMode,
            homeSelectedTimelineImportanceUrgencyFilter: values.timelineFilters.selectedImportanceUrgencyFilter,
            macHomeSidebarModeRawValue: values.macSidebarModeRawValue ?? existing.macHomeSidebarModeRawValue,
            macSelectedSettingsSectionRawValue: values.macSelectedSettingsSectionRawValue ?? existing.macSelectedSettingsSectionRawValue,
            timelineSelectedRange: existing.timelineSelectedRange,
            timelineFilterType: existing.timelineFilterType,
            timelineSelectedTag: existing.timelineSelectedTag,
            timelineSelectedTags: existing.timelineSelectedTags,
            timelineIncludeTagMatchMode: existing.timelineIncludeTagMatchMode,
            timelineExcludedTags: existing.timelineExcludedTags,
            timelineExcludeTagMatchMode: existing.timelineExcludeTagMatchMode,
            timelineSelectedImportanceUrgencyFilter: existing.timelineSelectedImportanceUrgencyFilter,
            statsSelectedRange: existing.statsSelectedRange,
            statsSelectedTag: existing.statsSelectedTag,
            statsSelectedTags: existing.statsSelectedTags,
            statsIncludeTagMatchMode: existing.statsIncludeTagMatchMode,
            statsExcludedTags: existing.statsExcludedTags,
            statsExcludeTagMatchMode: existing.statsExcludeTagMatchMode,
            statsSelectedImportanceUrgencyFilter: existing.statsSelectedImportanceUrgencyFilter,
            statsTaskTypeFilterRawValue: existing.statsTaskTypeFilterRawValue
        )
    }
}

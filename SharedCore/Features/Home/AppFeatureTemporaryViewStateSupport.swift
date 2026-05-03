import Foundation

protocol AppStatsFeatureTemporaryViewState {
    var selectedRange: DoneChartRange { get set }
    var selectedTag: String? { get }
    var effectiveSelectedTags: Set<String> { get }
    var includeTagMatchMode: RoutineTagMatchMode { get set }
    var excludedTags: Set<String> { get set }
    var excludeTagMatchMode: RoutineTagMatchMode { get set }
    var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? { get set }
    var taskTypeFilter: StatsTaskTypeFilter { get set }
    var advancedQuery: String { get set }

    mutating func setSelectedTag(_ tag: String?)
    mutating func setSelectedTags(_ tags: Set<String>)
}

protocol AppFeatureTemporaryViewState {
    associatedtype HomeState: HomeFeatureTemporaryViewState
    associatedtype StatsState: AppStatsFeatureTemporaryViewState

    var selectedTab: Tab { get set }
    var home: HomeState { get set }
    var timeline: TimelineFeature.State { get set }
    var stats: StatsState { get set }
}

enum AppFeatureTemporaryViewStateSupport {
    static func apply<State: AppFeatureTemporaryViewState>(
        _ persistedState: TemporaryViewState?,
        to state: inout State
    ) {
        let persistedState = persistedState ?? .default
        if let rawValue = persistedState.selectedAppTabRawValue,
           let tab = Tab(rawValue: rawValue) {
            state.selectedTab = tab
        }
        applyTimelineFilters(from: persistedState, to: &state.timeline)
        applyStatsFilters(from: persistedState, to: &state.stats)
    }

    static func reset<State: AppFeatureTemporaryViewState>(
        _ state: inout State,
        homeTaskListMode: State.HomeState.TaskListModeValue
    ) {
        state.home.taskListMode = homeTaskListMode
        state.home.hideUnavailableRoutines = false

        var taskFilters = state.home.taskFilters
        taskFilters.selectedFilter = .all
        taskFilters.advancedQuery = ""
        taskFilters.setSelectedTags([])
        taskFilters.includeTagMatchMode = .all
        taskFilters.excludedTags = []
        taskFilters.excludeTagMatchMode = .any
        taskFilters.selectedManualPlaceFilterID = nil
        taskFilters.selectedImportanceUrgencyFilter = nil
        taskFilters.selectedTodoStateFilter = nil
        taskFilters.selectedPressureFilter = nil
        taskFilters.tabFilterSnapshots = [:]
        taskFilters.isFilterSheetPresented = false
        state.home.taskFilters = taskFilters

        state.home.timelineFilters = HomeTimelineFiltersState()
        state.home.statsFilters = HomeStatsFiltersState()

        state.timeline.selectedRange = .all
        state.timeline.filterType = .all
        state.timeline.setSelectedTag(nil)
        state.timeline.includeTagMatchMode = .all
        state.timeline.excludedTags = []
        state.timeline.excludeTagMatchMode = .any
        state.timeline.selectedImportanceUrgencyFilter = nil
        state.timeline.isFilterSheetPresented = false
        state.timeline.availableTags = []
        state.timeline.groupedEntries = []

        state.stats.selectedRange = .week
        state.stats.setSelectedTag(nil)
        state.stats.includeTagMatchMode = .all
        state.stats.excludedTags = []
        state.stats.excludeTagMatchMode = .any
        state.stats.selectedImportanceUrgencyFilter = nil
        state.stats.taskTypeFilter = .all
        state.stats.advancedQuery = ""
    }

    static func makeTemporaryViewState<State: AppFeatureTemporaryViewState>(
        from state: State,
        preserving existingState: TemporaryViewState?
    ) -> TemporaryViewState {
        let existing = existingState ?? .default
        return TemporaryViewState(
            selectedAppTabRawValue: state.selectedTab.rawValue,
            homeTaskListModeRawValue: existing.homeTaskListModeRawValue,
            homeSelectedFilter: existing.homeSelectedFilter,
            homeAdvancedQuery: existing.homeAdvancedQuery,
            homeSelectedTag: existing.homeSelectedTag,
            homeSelectedTags: existing.homeSelectedTags,
            homeIncludeTagMatchMode: existing.homeIncludeTagMatchMode,
            homeExcludedTags: existing.homeExcludedTags,
            homeExcludeTagMatchMode: existing.homeExcludeTagMatchMode,
            homeSelectedManualPlaceFilterID: existing.homeSelectedManualPlaceFilterID,
            homeSelectedImportanceUrgencyFilter: existing.homeSelectedImportanceUrgencyFilter,
            homeSelectedTodoStateFilter: existing.homeSelectedTodoStateFilter,
            homeSelectedPressureFilter: existing.homeSelectedPressureFilter,
            homeTabFilterSnapshots: existing.homeTabFilterSnapshots,
            hideUnavailableRoutines: existing.hideUnavailableRoutines,
            homeSelectedTimelineRange: existing.homeSelectedTimelineRange,
            homeSelectedTimelineFilterType: existing.homeSelectedTimelineFilterType,
            homeSelectedTimelineTag: existing.homeSelectedTimelineTag,
            homeSelectedTimelineTags: existing.homeSelectedTimelineTags,
            homeTimelineIncludeTagMatchMode: existing.homeTimelineIncludeTagMatchMode,
            homeSelectedTimelineExcludedTags: existing.homeSelectedTimelineExcludedTags,
            homeTimelineExcludeTagMatchMode: existing.homeTimelineExcludeTagMatchMode,
            homeSelectedTimelineImportanceUrgencyFilter: existing.homeSelectedTimelineImportanceUrgencyFilter,
            macHomeSidebarModeRawValue: existing.macHomeSidebarModeRawValue,
            macSelectedSettingsSectionRawValue: existing.macSelectedSettingsSectionRawValue,
            timelineSelectedRange: state.timeline.selectedRange,
            timelineFilterType: state.timeline.filterType,
            timelineSelectedTag: state.timeline.selectedTag,
            timelineSelectedTags: state.timeline.effectiveSelectedTags,
            timelineIncludeTagMatchMode: state.timeline.includeTagMatchMode,
            timelineExcludedTags: state.timeline.excludedTags,
            timelineExcludeTagMatchMode: state.timeline.excludeTagMatchMode,
            timelineSelectedImportanceUrgencyFilter: state.timeline.selectedImportanceUrgencyFilter,
            statsSelectedRange: state.stats.selectedRange,
            statsSelectedTag: state.stats.selectedTag,
            statsSelectedTags: state.stats.effectiveSelectedTags,
            statsIncludeTagMatchMode: state.stats.includeTagMatchMode,
            statsExcludedTags: state.stats.excludedTags,
            statsExcludeTagMatchMode: state.stats.excludeTagMatchMode,
            statsSelectedImportanceUrgencyFilter: state.stats.selectedImportanceUrgencyFilter,
            statsTaskTypeFilterRawValue: state.stats.taskTypeFilter.rawValue,
            statsAdvancedQuery: state.stats.advancedQuery
        )
    }

    private static func applyTimelineFilters(
        from persistedState: TemporaryViewState,
        to state: inout TimelineFeature.State
    ) {
        state.selectedRange = persistedState.timelineSelectedRange
        state.filterType = persistedState.timelineFilterType
        state.setSelectedTags(persistedState.timelineSelectedTags)
        if state.effectiveSelectedTags.isEmpty {
            state.setSelectedTag(persistedState.timelineSelectedTag)
        }
        state.includeTagMatchMode = persistedState.timelineIncludeTagMatchMode
        state.excludedTags = persistedState.timelineExcludedTags
        state.excludeTagMatchMode = persistedState.timelineExcludeTagMatchMode
        state.selectedImportanceUrgencyFilter = persistedState.timelineSelectedImportanceUrgencyFilter
    }

    private static func applyStatsFilters<State: AppStatsFeatureTemporaryViewState>(
        from persistedState: TemporaryViewState,
        to state: inout State
    ) {
        state.selectedRange = persistedState.statsSelectedRange
        state.setSelectedTags(persistedState.statsSelectedTags)
        if state.effectiveSelectedTags.isEmpty {
            state.setSelectedTag(persistedState.statsSelectedTag)
        }
        state.includeTagMatchMode = persistedState.statsIncludeTagMatchMode
        state.excludedTags = persistedState.statsExcludedTags
        state.excludeTagMatchMode = persistedState.statsExcludeTagMatchMode
        state.selectedImportanceUrgencyFilter = persistedState.statsSelectedImportanceUrgencyFilter
        state.advancedQuery = persistedState.statsAdvancedQuery
        if let rawValue = persistedState.statsTaskTypeFilterRawValue,
           let filter = StatsTaskTypeFilter(rawValue: rawValue) {
            state.taskTypeFilter = filter
        }
    }
}

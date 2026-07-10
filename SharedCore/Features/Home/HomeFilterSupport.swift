import Foundation

struct HomeFilterMutationResult: Equatable {
    var didResetHideUnavailableRoutines: Bool = false
    var shouldPersistTemporaryViewState: Bool = true
}

struct HomeSharedFilterState: Equatable {
    var selectedTags: Set<String>
    var excludedTags: Set<String>
    var includeTagMatchMode: RoutineTagMatchMode
    var excludeTagMatchMode: RoutineTagMatchMode
    var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
}

enum HomeSharedFilterStateResolver {
    static func resolvedState(
        taskSelectedTags: Set<String>,
        timelineSelectedTags: Set<String>,
        taskExcludedTags: Set<String>,
        timelineExcludedTags: Set<String>,
        taskIncludeTagMatchMode: RoutineTagMatchMode,
        timelineIncludeTagMatchMode: RoutineTagMatchMode,
        taskExcludeTagMatchMode: RoutineTagMatchMode,
        timelineExcludeTagMatchMode: RoutineTagMatchMode,
        taskImportanceUrgencyFilter: ImportanceUrgencyFilterCell?,
        timelineImportanceUrgencyFilter: ImportanceUrgencyFilterCell?,
        preferredTags: [String]
    ) -> HomeSharedFilterState {
        let selectedTags = mergedTagSet(
            taskSelectedTags,
            timelineSelectedTags,
            preferredTags: preferredTags
        )
        let excludedTags = mergedTagSet(
            taskExcludedTags,
            timelineExcludedTags,
            preferredTags: preferredTags
        )
        .filter { excludedTag in
            !HomeTagFilterMutationSupport.contains(excludedTag, in: selectedTags)
        }

        return HomeSharedFilterState(
            selectedTags: selectedTags,
            excludedTags: excludedTags,
            includeTagMatchMode: resolvedMatchMode(
                taskIncludeTagMatchMode,
                timelineIncludeTagMatchMode,
                taskHasSelection: !taskSelectedTags.isEmpty,
                timelineHasSelection: !timelineSelectedTags.isEmpty,
                fallback: .all
            ),
            excludeTagMatchMode: resolvedMatchMode(
                taskExcludeTagMatchMode,
                timelineExcludeTagMatchMode,
                taskHasSelection: !taskExcludedTags.isEmpty,
                timelineHasSelection: !timelineExcludedTags.isEmpty,
                fallback: .any
            ),
            selectedImportanceUrgencyFilter: resolvedImportanceUrgencyFilter(
                taskImportanceUrgencyFilter,
                timelineImportanceUrgencyFilter
            )
        )
    }

    private static func mergedTagSet(
        _ sets: Set<String>...,
        preferredTags: [String]
    ) -> Set<String> {
        Set(RoutineTag.deduplicated(sets.flatMap { Array($0) }, preferredTags: preferredTags))
    }

    private static func resolvedMatchMode(
        _ taskMode: RoutineTagMatchMode,
        _ timelineMode: RoutineTagMatchMode,
        taskHasSelection: Bool,
        timelineHasSelection: Bool,
        fallback: RoutineTagMatchMode
    ) -> RoutineTagMatchMode {
        if taskMode == timelineMode { return taskMode }
        if taskHasSelection && !timelineHasSelection { return taskMode }
        if timelineHasSelection && !taskHasSelection { return timelineMode }
        return fallback
    }

    private static func resolvedImportanceUrgencyFilter(
        _ taskFilter: ImportanceUrgencyFilterCell?,
        _ timelineFilter: ImportanceUrgencyFilterCell?
    ) -> ImportanceUrgencyFilterCell? {
        let normalizedTaskFilter = ImportanceUrgencyFilterCell.normalized(taskFilter)
        let normalizedTimelineFilter = ImportanceUrgencyFilterCell.normalized(timelineFilter)
        guard normalizedTaskFilter != normalizedTimelineFilter else { return normalizedTaskFilter }
        return normalizedTaskFilter ?? normalizedTimelineFilter
    }
}

enum HomeTaskFilterMutation: Equatable {
    case selectedFilter(RoutineListFilter)
    case advancedQuery(String)
    case selectedTag(String?)
    case selectedTags(Set<String>)
    case includeTagMatchMode(RoutineTagMatchMode)
    case excludedTags(Set<String>)
    case excludeTagMatchMode(RoutineTagMatchMode)
    case selectedManualPlaceFilterID(UUID?)
    case selectedImportanceUrgencyFilter(ImportanceUrgencyFilterCell?)
    case selectedTodoStateFilter(TodoState?)
    case selectedPressureFilter(RoutineTaskPressure?)
    case selectedGoalFilter(HomeTaskGoalFilter)
    case selectedMediaFilter(TaskMediaFilter)
    case hideAssumedDoneTasks(Bool)
    case taskListViewMode(HomeTaskListViewMode)
    case taskListSortOrder(HomeTaskListSortOrder)
    case createdDateFilter(HomeTaskCreatedDateFilter)
    case showArchivedTasks(Bool)
    case isFilterSheetPresented(Bool)
    case clearOptionalFilters
}

enum HomeTimelineFilterMutation: Equatable {
    case selectedRange(TimelineRange)
    case selectedFilterType(TimelineFilterType)
    case selectedTag(String?)
    case selectedTags(Set<String>)
    case includeTagMatchMode(RoutineTagMatchMode)
    case selectedExcludedTags(Set<String>)
    case excludeTagMatchMode(RoutineTagMatchMode)
    case selectedImportanceUrgencyFilter(ImportanceUrgencyFilterCell?)
    case selectedMediaFilter(TaskMediaFilter)
}

enum HomeStatsFilterMutation: Equatable {
    case selectedRange(DoneChartRange)
    case selectedTag(String?)
    case selectedTags(Set<String>)
    case includeTagMatchMode(RoutineTagMatchMode)
}

enum HomeFilterEditor {
    static func normalizeSelectedFilter(
        forTaskListModeRawValue taskListModeRawValue: String?,
        taskFilters: inout HomeTaskFiltersState
    ) {
        guard taskListModeRawValue == "Todos",
              taskFilters.selectedFilter == .doneToday
        else { return }

        taskFilters.selectedFilter = .all
    }

    @discardableResult
    static func transitionTaskListMode(
        from oldModeRawValue: String,
        to newModeRawValue: String,
        taskFilters: inout HomeTaskFiltersState,
        hideUnavailableRoutines: inout Bool
    ) -> Bool {
        taskFilters.tabFilterSnapshots[oldModeRawValue] = taskFilters.currentSnapshot

        let savedSnapshot = taskFilters.tabFilterSnapshots[newModeRawValue]
        taskFilters.apply(snapshot: savedSnapshot ?? .default)
        normalizeSelectedFilter(forTaskListModeRawValue: newModeRawValue, taskFilters: &taskFilters)

        if savedSnapshot == nil && hideUnavailableRoutines {
            hideUnavailableRoutines = false
            return true
        }

        return false
    }

    @discardableResult
    static func clearOptionalFilters(
        taskFilters: inout HomeTaskFiltersState,
        hideUnavailableRoutines: inout Bool
    ) -> Bool {
        taskFilters.setSelectedTag(nil)
        taskFilters.advancedQuery = ""
        taskFilters.includeTagMatchMode = .all
        taskFilters.excludedTags = []
        taskFilters.excludeTagMatchMode = .any
        taskFilters.selectedManualPlaceFilterID = nil
        taskFilters.selectedImportanceUrgencyFilter = nil
        taskFilters.selectedTodoStateFilter = nil
        taskFilters.selectedPressureFilter = nil
        taskFilters.selectedGoalFilter = .all
        taskFilters.selectedMediaFilter = .all
        taskFilters.hideAssumedDoneTasks = true
        taskFilters.taskListViewMode = .all
        taskFilters.taskListSortOrder = .smart
        taskFilters.createdDateFilter = .all
        taskFilters.showArchivedTasks = true

        if hideUnavailableRoutines {
            hideUnavailableRoutines = false
            return true
        }

        return false
    }

    @discardableResult
    static func clearTaskListAndSharedFilters(
        taskFilters: inout HomeTaskFiltersState,
        timelineFilters: inout HomeTimelineFiltersState,
        hideUnavailableRoutines: inout Bool
    ) -> HomeFilterMutationResult {
        let didResetHideUnavailableRoutines = clearOptionalFilters(
            taskFilters: &taskFilters,
            hideUnavailableRoutines: &hideUnavailableRoutines
        )
        taskFilters.selectedFilter = .all

        timelineFilters.setSelectedTags([])
        timelineFilters.includeTagMatchMode = .all
        timelineFilters.selectedExcludedTags = []
        timelineFilters.excludeTagMatchMode = .any
        timelineFilters.selectedImportanceUrgencyFilter = nil

        return HomeFilterMutationResult(didResetHideUnavailableRoutines: didResetHideUnavailableRoutines)
    }

    @discardableResult
    static func apply(
        _ mutation: HomeTaskFilterMutation,
        taskFilters: inout HomeTaskFiltersState,
        hideUnavailableRoutines: inout Bool
    ) -> HomeFilterMutationResult {
        switch mutation {
        case let .selectedFilter(filter):
            taskFilters.selectedFilter = filter

        case let .advancedQuery(query):
            taskFilters.advancedQuery = query

        case let .selectedTag(tag):
            taskFilters.setSelectedTag(tag)

        case let .selectedTags(tags):
            taskFilters.setSelectedTags(tags)

        case let .includeTagMatchMode(mode):
            taskFilters.includeTagMatchMode = mode

        case let .excludedTags(tags):
            taskFilters.excludedTags = tags

        case let .excludeTagMatchMode(mode):
            taskFilters.excludeTagMatchMode = mode

        case let .selectedManualPlaceFilterID(id):
            taskFilters.selectedManualPlaceFilterID = id

        case let .selectedImportanceUrgencyFilter(filter):
            taskFilters.selectedImportanceUrgencyFilter = ImportanceUrgencyFilterCell.normalized(filter)

        case let .selectedTodoStateFilter(filter):
            taskFilters.selectedTodoStateFilter = filter

        case let .selectedPressureFilter(filter):
            taskFilters.selectedPressureFilter = filter

        case let .selectedGoalFilter(filter):
            taskFilters.selectedGoalFilter = filter

        case let .selectedMediaFilter(filter):
            taskFilters.selectedMediaFilter = filter

        case let .hideAssumedDoneTasks(hideAssumedDoneTasks):
            taskFilters.hideAssumedDoneTasks = hideAssumedDoneTasks

        case let .taskListViewMode(mode):
            taskFilters.taskListViewMode = mode

        case let .taskListSortOrder(order):
            taskFilters.taskListSortOrder = order

        case let .createdDateFilter(filter):
            taskFilters.createdDateFilter = filter

        case let .showArchivedTasks(showArchivedTasks):
            taskFilters.showArchivedTasks = showArchivedTasks

        case let .isFilterSheetPresented(isPresented):
            taskFilters.isFilterSheetPresented = isPresented
            return HomeFilterMutationResult(shouldPersistTemporaryViewState: false)

        case .clearOptionalFilters:
            return HomeFilterMutationResult(
                didResetHideUnavailableRoutines: clearOptionalFilters(
                    taskFilters: &taskFilters,
                    hideUnavailableRoutines: &hideUnavailableRoutines
                )
            )
        }

        return HomeFilterMutationResult()
    }

    static func apply(
        _ mutation: HomeTimelineFilterMutation,
        timelineFilters: inout HomeTimelineFiltersState
    ) {
        switch mutation {
        case let .selectedRange(range):
            timelineFilters.selectedRange = range

        case let .selectedFilterType(filterType):
            timelineFilters.selectedFilterType = filterType

        case let .selectedTag(tag):
            timelineFilters.setSelectedTag(tag)

        case let .selectedTags(tags):
            timelineFilters.setSelectedTags(tags)

        case let .includeTagMatchMode(mode):
            timelineFilters.includeTagMatchMode = mode

        case let .selectedExcludedTags(tags):
            timelineFilters.selectedExcludedTags = tags

        case let .excludeTagMatchMode(mode):
            timelineFilters.excludeTagMatchMode = mode

        case let .selectedImportanceUrgencyFilter(filter):
            timelineFilters.selectedImportanceUrgencyFilter = ImportanceUrgencyFilterCell.normalized(filter)

        case let .selectedMediaFilter(filter):
            timelineFilters.selectedMediaFilter = filter
        }
    }

    static func apply(
        _ mutation: HomeStatsFilterMutation,
        statsFilters: inout HomeStatsFiltersState
    ) {
        switch mutation {
        case let .selectedRange(range):
            statsFilters.selectedRange = range

        case let .selectedTag(tag):
            statsFilters.setSelectedTag(tag)

        case let .selectedTags(tags):
            statsFilters.setSelectedTags(tags)

        case let .includeTagMatchMode(mode):
            statsFilters.includeTagMatchMode = mode
        }
    }
}

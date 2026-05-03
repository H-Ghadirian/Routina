import Foundation

struct HomeFilterMutationResult: Equatable {
    var didResetHideUnavailableRoutines: Bool = false
    var shouldPersistTemporaryViewState: Bool = true
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
}

enum HomeStatsFilterMutation: Equatable {
    case selectedRange(DoneChartRange)
    case selectedTag(String?)
    case selectedTags(Set<String>)
    case includeTagMatchMode(RoutineTagMatchMode)
}

enum HomeFilterEditor {
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
            taskFilters.selectedImportanceUrgencyFilter = filter

        case let .selectedTodoStateFilter(filter):
            taskFilters.selectedTodoStateFilter = filter

        case let .selectedPressureFilter(filter):
            taskFilters.selectedPressureFilter = filter

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
            timelineFilters.selectedImportanceUrgencyFilter = filter
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

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
    case selectedFlags(Set<String>)
    case includeFlagMatchMode(RoutineTagMatchMode)
    case excludedFlags(Set<String>)
    case excludeFlagMatchMode(RoutineTagMatchMode)
    case excludedTags(Set<String>)
    case excludeTagMatchMode(RoutineTagMatchMode)
    case selectedManualPlaceFilterID(UUID?)
    case selectedImportanceUrgencyFilter(ImportanceUrgencyFilterCell?)
    case selectedTodoStateFilter(TodoState?)
    case selectedPressureFilter(RoutineTaskPressure?)
    case selectedThinkingNeededFilter(RoutineTaskThinkingNeeded?)
    case selectedGoalFilter(HomeTaskGoalFilter)
    case selectedMediaFilter(TaskMediaFilter)
    case selectedEstimationFilter(TaskEstimationFilter)
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
    case selectedStatusFilter(TimelineStatusFilter)
    case selectedTag(String?)
    case selectedTags(Set<String>)
    case includeTagMatchMode(RoutineTagMatchMode)
    case selectedFlags(Set<String>)
    case includeFlagMatchMode(RoutineTagMatchMode)
    case selectedExcludedTags(Set<String>)
    case excludeTagMatchMode(RoutineTagMatchMode)
    case selectedImportanceUrgencyFilter(ImportanceUrgencyFilterCell?)
    case selectedPressureFilter(RoutineTaskPressure?)
    case selectedThinkingNeededFilter(RoutineTaskThinkingNeeded?)
    case selectedEstimationFilter(TaskEstimationFilter)
    case selectedMediaFilter(TaskMediaFilter)
}

enum HomeStatsFilterMutation: Equatable {
    case selectedRange(DoneChartRange)
    case selectedTag(String?)
    case selectedTags(Set<String>)
    case includeTagMatchMode(RoutineTagMatchMode)
}

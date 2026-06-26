import SwiftUI

struct HomeFiltersSheetView: View {
    let configuration: HomeFiltersSheetConfiguration
    let bindings: HomeFilterBindings
    let tagData: HomeTagFilterData
    let actions: HomeFiltersSheetActions

    @AppStorage(
        UserDefaultBoolValueKey.appSettingFilterQuerySectionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var showsFilterQuerySections = false

    var body: some View {
        NavigationStack {
            List {
                if showsFilterQuerySections {
                    HomeFiltersQuerySection(
                        advancedQuery: bindings.advancedQuery,
                        options: HomeAdvancedQueryOptions(
                            tags: tagData.tagSummaries.map(\.name),
                            places: configuration.place.isPlacesEnabled
                                ? configuration.place.sortedRoutinePlaces.map(\.displayName)
                                : []
                        )
                    )
                }
                HomeFiltersTaskListModeSection(taskListMode: bindings.taskListMode)
                HomeFiltersVisibilitySection(
                    taskListMode: configuration.taskListMode,
                    taskListViewMode: bindings.taskListViewMode,
                    hideAssumedDoneTasks: bindings.hideAssumedDoneTasks,
                    showArchivedTasks: bindings.showArchivedTasks
                )
                HomeFiltersGroupingSection(
                    routineListSectioningMode: bindings.routineListSectioningMode
                )
                HomeFiltersSortSection(taskListSortOrder: bindings.taskListSortOrder)
                HomeFiltersCreatedSection(createdDateFilter: bindings.createdDateFilter)
                HomeFiltersStatusSection(
                    placeFilterPluralNoun: configuration.place.placeFilterPluralNoun,
                    availableFilters: configuration.availableFilters,
                    selectedFilter: bindings.selectedFilter
                )
                HomeFiltersTodoStateSection(
                    taskListMode: configuration.taskListMode,
                    selectedTodoStateFilter: bindings.selectedTodoStateFilter
                )
                HomeFiltersPressureSection(
                    selectedPressureFilter: bindings.selectedPressureFilter
                )
                HomeFiltersGoalSection(
                    selectedGoalFilter: bindings.selectedGoalFilter
                )
                HomeFiltersMediaSection(
                    selectedMediaFilter: bindings.selectedMediaFilter
                )
                HomeFiltersImportanceUrgencySection(
                    selectedImportanceUrgencyFilter: bindings.selectedImportanceUrgencyFilter,
                    summary: configuration.importanceUrgencySummary
                )
                HomeFiltersTagRulesSection(
                    bindings: bindings.tagRules,
                    data: tagData,
                    actions: actions.tagActions
                )
                if configuration.place.isPlacesEnabled {
                    HomeFiltersPlaceSection(
                        configuration: configuration.place,
                        selectedPlaceID: bindings.selectedPlaceID,
                        hideUnavailableRoutines: bindings.hideUnavailableRoutines
                    )
                }
                HomeFiltersClearSection(
                    hasActiveOptionalFilters: configuration.hasActiveOptionalFilters,
                    onClearOptionalFilters: actions.onClearOptionalFilters
                )
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: actions.onDismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

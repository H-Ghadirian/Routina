import SwiftUI

struct HomeFiltersSheetView<TagPicker: View>: View {
    let configuration: HomeFiltersSheetConfiguration
    let bindings: HomeFilterBindings
    let flagData: HomeFlagFilterData
    let actions: HomeFiltersSheetActions
    let tagPicker: () -> TagPicker
    let tagSuggestions: () -> [String]

    @State private var isTagPickerPresented = false

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
                        options: {
                            HomeAdvancedQueryOptions(
                                tags: tagSuggestions(),
                                places: configuration.place.isPlacesEnabled
                                    ? configuration.place.sortedRoutinePlaces.map(\.displayName)
                                    : []
                            )
                        }
                    )
                }
                HomeFiltersTaskListModeSection(taskListMode: bindings.taskListMode)
                HomeFiltersVisibilitySection(
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
                HomeFiltersThinkingNeededSection(
                    selectedThinkingNeededFilter: bindings.selectedThinkingNeededFilter
                )
                if configuration.isGoalsEnabled {
                    HomeFiltersGoalSection(
                        selectedGoalFilter: bindings.selectedGoalFilter
                    )
                }
                HomeFiltersMediaSection(
                    selectedMediaFilter: bindings.selectedMediaFilter
                )
                HomeFiltersEstimationSection(
                    selectedEstimationFilter: bindings.selectedEstimationFilter
                )
                HomeFiltersImportanceUrgencySection(
                    selectedImportanceUrgencyFilter: bindings.selectedImportanceUrgencyFilter,
                    summary: configuration.importanceUrgencySummary
                )
                HomeFiltersTagFilterEntrySection(
                    selectedTags: bindings.selectedTags,
                    excludedTags: bindings.excludedTags,
                    onShowTagPicker: {
                        isTagPickerPresented = true
                    }
                )
                HomeFiltersFlagSection(
                    includeFlagMatchMode: bindings.includeFlagMatchMode,
                    data: flagData,
                    actions: actions.flagActions
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
        .sheet(isPresented: $isTagPickerPresented) {
            tagPicker()
        }
    }
}

import SwiftUI

struct HomeFiltersSheetView: View {
    let configuration: HomeFiltersSheetConfiguration
    let bindings: HomeFilterBindings
    let tagData: HomeTagFilterData
    let actions: HomeFiltersSheetActions

    var body: some View {
        NavigationStack {
            List {
                HomeFiltersViewModeSection(taskListViewMode: bindings.taskListViewMode)
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
                HomeFiltersImportanceUrgencySection(
                    selectedImportanceUrgencyFilter: bindings.selectedImportanceUrgencyFilter,
                    summary: configuration.importanceUrgencySummary
                )
                HomeFiltersTagRulesSection(
                    bindings: bindings.tagRules,
                    data: tagData,
                    actions: actions.tagActions
                )
                HomeFiltersPlaceSection(
                    configuration: configuration.place,
                    selectedPlaceID: bindings.selectedPlaceID,
                    hideUnavailableRoutines: bindings.hideUnavailableRoutines
                )
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

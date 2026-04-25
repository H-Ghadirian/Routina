import SwiftUI

struct HomeFiltersSheetView: View {
    let taskListMode: HomeFeature.TaskListMode
    let availableFilters: [RoutineListFilter]
    @Binding var taskListViewMode: HomeTaskListViewMode
    @Binding var selectedFilter: RoutineListFilter
    @Binding var selectedTodoStateFilter: TodoState?
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    @Binding var includeTagMatchMode: RoutineTagMatchMode
    @Binding var excludeTagMatchMode: RoutineTagMatchMode
    let selectedTags: Set<String>
    let excludedTags: Set<String>
    let tagSummaries: [RoutineTagSummary]
    let allTagTaskCount: Int
    let suggestedRelatedTags: [String]
    let availableExcludeTagSummaries: [RoutineTagSummary]
    let sortedRoutinePlaces: [RoutinePlace]
    let hasSavedPlaces: Bool
    let hasPlaceLinkedRoutines: Bool
    let isLocationAuthorized: Bool
    @Binding var selectedPlaceID: UUID?
    @Binding var hideUnavailableRoutines: Bool
    let placeFilterPluralNoun: String
    let placeFilterAllTitle: String
    let placeFilterSectionDescription: String
    let locationStatusText: String
    let importanceUrgencySummary: String
    let hasActiveOptionalFilters: Bool
    let onResetIncludedTags: () -> Void
    let onToggleIncludedTag: (String) -> Void
    let onAddIncludedTag: (String) -> Void
    let onToggleExcludedTag: (String) -> Void
    let isIncludedTagSelected: (String) -> Bool
    let onClearOptionalFilters: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                HomeFiltersViewModeSection(taskListViewMode: $taskListViewMode)
                HomeFiltersStatusSection(
                    placeFilterPluralNoun: placeFilterPluralNoun,
                    availableFilters: availableFilters,
                    selectedFilter: $selectedFilter
                )
                HomeFiltersTodoStateSection(
                    taskListMode: taskListMode,
                    selectedTodoStateFilter: $selectedTodoStateFilter
                )
                HomeFiltersImportanceUrgencySection(
                    selectedImportanceUrgencyFilter: $selectedImportanceUrgencyFilter,
                    summary: importanceUrgencySummary
                )
                HomeFiltersTagRulesSection(
                    includeTagMatchMode: $includeTagMatchMode,
                    excludeTagMatchMode: $excludeTagMatchMode,
                    selectedTags: selectedTags,
                    excludedTags: excludedTags,
                    tagSummaries: tagSummaries,
                    allTagTaskCount: allTagTaskCount,
                    suggestedRelatedTags: suggestedRelatedTags,
                    availableExcludeTagSummaries: availableExcludeTagSummaries,
                    onResetIncludedTags: onResetIncludedTags,
                    onToggleIncludedTag: onToggleIncludedTag,
                    onAddIncludedTag: onAddIncludedTag,
                    onToggleExcludedTag: onToggleExcludedTag,
                    isIncludedTagSelected: isIncludedTagSelected
                )
                HomeFiltersPlaceSection(
                    sortedRoutinePlaces: sortedRoutinePlaces,
                    hasSavedPlaces: hasSavedPlaces,
                    hasPlaceLinkedRoutines: hasPlaceLinkedRoutines,
                    isLocationAuthorized: isLocationAuthorized,
                    selectedPlaceID: $selectedPlaceID,
                    hideUnavailableRoutines: $hideUnavailableRoutines,
                    placeFilterPluralNoun: placeFilterPluralNoun,
                    placeFilterAllTitle: placeFilterAllTitle,
                    placeFilterSectionDescription: placeFilterSectionDescription,
                    locationStatusText: locationStatusText
                )
                HomeFiltersClearSection(
                    hasActiveOptionalFilters: hasActiveOptionalFilters,
                    onClearOptionalFilters: onClearOptionalFilters
                )
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

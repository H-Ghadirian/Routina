import SwiftUI

// This extension is compiled into both app targets; it is excluded from SwiftPM
// because `HomeTCAView` itself remains platform-owned.

extension HomeTCAView {
    @ViewBuilder
    var activeFilterChipBar: some View {
        HomeActiveFilterChipBar(
            taskListViewMode: store.taskListViewMode,
            taskListSortOrder: store.taskListSortOrder,
            createdDateFilter: store.createdDateFilter,
            advancedQuery: store.advancedQuery,
            selectedTags: store.selectedTags,
            excludedTags: store.excludedTags,
            selectedPlaceName: selectedPlaceName,
            selectedImportanceUrgencyFilterLabel: homeFilterPresentation.selectedImportanceUrgencyFilterLabel,
            selectedPressureFilter: store.selectedPressureFilter,
            hideUnavailableRoutines: store.hideUnavailableRoutines,
            showArchivedTasks: store.showArchivedTasks,
            onClearAll: { store.send(.clearOptionalFilters) },
            onClearTaskListViewMode: { store.send(.taskListViewModeChanged(.all)) },
            onClearTaskListSortOrder: { store.send(.taskListSortOrderChanged(.smart)) },
            onClearCreatedDateFilter: { store.send(.createdDateFilterChanged(.all)) },
            onClearAdvancedQuery: { store.send(.advancedQueryChanged("")) },
            onRemoveIncludedTag: { tag in
                var selected = store.selectedTags
                selected = selected.filter { !RoutineTag.contains($0, in: [tag]) }
                store.send(.selectedTagsChanged(selected))
            },
            onRemoveExcludedTag: { tag in
                store.send(.excludedTagsChanged(store.excludedTags.filter { $0 != tag }))
            },
            onClearPlace: {
                store.send(.selectedManualPlaceFilterIDChanged(nil))
            },
            onClearImportanceUrgency: {
                store.send(.selectedImportanceUrgencyFilterChanged(nil))
            },
            onClearPressure: {
                store.send(.selectedPressureFilterChanged(nil))
            },
            onShowUnavailableRoutines: {
                store.send(.hideUnavailableRoutinesChanged(false))
            },
            onShowArchivedTasks: {
                store.send(.showArchivedTasksChanged(true))
            }
        )
    }

    var homeFilterPresentation: HomeFilterPresentation {
        HomeFilterPresentation(
            taskListKind: store.taskListMode.filterTaskListKind,
            selectedFilter: store.selectedFilter,
            advancedQuery: store.advancedQuery,
            taskListViewMode: store.taskListViewMode,
            taskListSortOrder: store.taskListSortOrder,
            createdDateFilter: store.createdDateFilter,
            selectedTodoStateFilter: store.selectedTodoStateFilter,
            selectedTags: store.selectedTags,
            includeTagMatchMode: store.includeTagMatchMode,
            excludedTags: store.excludedTags,
            selectedPlaceName: selectedPlaceName,
            hasSelectedPlaceFilter: store.selectedManualPlaceFilterID != nil,
            selectedImportanceUrgencyFilter: store.selectedImportanceUrgencyFilter,
            selectedPressureFilter: store.selectedPressureFilter,
            hideUnavailableRoutines: store.hideUnavailableRoutines,
            showArchivedTasks: store.showArchivedTasks,
            hasSavedPlaces: hasSavedPlaces,
            awayRoutineCount: store.awayRoutineDisplays.count,
            locationAuthorizationStatus: store.locationSnapshot.authorizationStatus
        )
    }

    var hideUnavailableRoutinesBinding: Binding<Bool> {
        Binding(
            get: { store.hideUnavailableRoutines },
            set: { store.send(.hideUnavailableRoutinesChanged($0)) }
        )
    }

    var showArchivedTasksBinding: Binding<Bool> {
        Binding(
            get: { store.showArchivedTasks },
            set: { store.send(.showArchivedTasksChanged($0)) }
        )
    }

    var isFilterSheetPresentedBinding: Binding<Bool> {
        Binding(
            get: { store.isFilterSheetPresented },
            set: { store.send(.isFilterSheetPresentedChanged($0)) }
        )
    }

    var manualPlaceFilterBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedManualPlaceFilterID },
            set: { store.send(.selectedManualPlaceFilterIDChanged($0)) }
        )
    }

    var homeFilterBindings: HomeFilterBindings {
        HomeFilterBindings(
            taskListViewMode: Binding(
                get: { store.taskListViewMode },
                set: { store.send(.taskListViewModeChanged($0)) }
            ),
            taskListSortOrder: Binding(
                get: { store.taskListSortOrder },
                set: { store.send(.taskListSortOrderChanged($0)) }
            ),
            createdDateFilter: Binding(
                get: { store.createdDateFilter },
                set: { store.send(.createdDateFilterChanged($0)) }
            ),
            advancedQuery: Binding(
                get: { store.advancedQuery },
                set: { store.send(.advancedQueryChanged($0)) }
            ),
            selectedFilter: Binding(
                get: { store.selectedFilter },
                set: { store.send(.selectedFilterChanged($0)) }
            ),
            selectedTodoStateFilter: Binding(
                get: { store.selectedTodoStateFilter },
                set: { store.send(.selectedTodoStateFilterChanged($0)) }
            ),
            selectedImportanceUrgencyFilter: Binding(
                get: { store.selectedImportanceUrgencyFilter },
                set: { store.send(.selectedImportanceUrgencyFilterChanged($0)) }
            ),
            selectedPressureFilter: Binding(
                get: { store.selectedPressureFilter },
                set: { store.send(.selectedPressureFilterChanged($0)) }
            ),
            includeTagMatchMode: Binding(
                get: { store.includeTagMatchMode },
                set: { store.send(.includeTagMatchModeChanged($0)) }
            ),
            excludeTagMatchMode: Binding(
                get: { store.excludeTagMatchMode },
                set: { store.send(.excludeTagMatchModeChanged($0)) }
            ),
            selectedPlaceID: manualPlaceFilterBinding,
            hideUnavailableRoutines: hideUnavailableRoutinesBinding,
            showArchivedTasks: showArchivedTasksBinding
        )
    }

    var sortedRoutinePlaces: [RoutinePlace] {
        store.routinePlaces.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    var selectedPlaceName: String? {
        guard let id = store.selectedManualPlaceFilterID else { return nil }
        return store.routinePlaces.first(where: { $0.id == id })?.displayName
    }

    var hasActiveOptionalFilters: Bool {
        homeFilterPresentation.hasActiveOptionalFilters
    }

    var hasSavedPlaces: Bool {
        !sortedRoutinePlaces.isEmpty
    }

    var hasPlaceLinkedRoutines: Bool {
        store.routineTasks.contains { $0.placeID != nil }
    }

    var hasPlaceAwareContent: Bool {
        hasSavedPlaces || hasPlaceLinkedRoutines
    }

    var manualPlaceFilterDescription: String {
        homeFilterPresentation.manualPlaceFilterDescription
    }

    var placeFilterSectionDescription: String {
        homeFilterPresentation.placeFilterSectionDescription
    }

    var placeFilterPluralNoun: String {
        homeFilterPresentation.placeFilterPluralNoun
    }

    var placeFilterAllTitle: String {
        homeFilterPresentation.placeFilterAllTitle
    }

    var importanceUrgencyFilterSummary: String {
        homeFilterPresentation.importanceUrgencyFilterSummary
    }

    var locationStatusText: String {
        homeFilterPresentation.locationStatusText
    }

    var iOSAvailableFilters: [RoutineListFilter] {
        [.all, .due, .doneToday]
    }

    var homeTagFilterSupport: HomeTagFilterSupport<HomeFeature.RoutineDisplay> {
        HomeTagFilterSupport(
            allDisplays: allRoutineDisplays,
            matchesCurrentTaskListMode: matchesCurrentTaskListMode,
            tags: \.tags,
            selectedTags: store.selectedTags,
            includeTagMatchMode: store.includeTagMatchMode,
            relatedTagRules: store.relatedTagRules,
            suggestionAnchor: relatedFilterTagSuggestionAnchor
        )
    }

    var homeTagFilterCoordinator: HomeTagFilterCoordinator<HomeFeature.RoutineDisplay> {
        HomeTagFilterCoordinator(
            support: homeTagFilterSupport,
            excludedTags: store.excludedTags,
            setSelectedTags: { store.send(.selectedTagsChanged($0)) },
            setExcludedTags: { store.send(.excludedTagsChanged($0)) },
            setSuggestionAnchor: { relatedFilterTagSuggestionAnchor = $0 }
        )
    }

    var homeTagFilterData: HomeTagFilterData {
        let data = homeTagFilterCoordinator.data
        return HomeTagFilterData(
            selectedTags: data.selectedTags,
            excludedTags: data.excludedTags,
            tagSummaries: RoutineTagColors.applying(store.tagColors, to: data.tagSummaries),
            allTagTaskCount: data.allTagTaskCount,
            suggestedRelatedTags: data.suggestedRelatedTags,
            availableExcludeTagSummaries: RoutineTagColors.applying(store.tagColors, to: data.availableExcludeTagSummaries),
            showsTagCounts: data.showsTagCounts
        )
    }

    var homeTagFilterActions: HomeTagFilterActions {
        homeTagFilterCoordinator.actions
    }

    private var allRoutineDisplays: [HomeFeature.RoutineDisplay] {
        store.routineDisplays + store.awayRoutineDisplays + store.archivedRoutineDisplays
    }
}

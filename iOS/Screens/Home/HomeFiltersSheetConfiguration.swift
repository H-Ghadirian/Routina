import Foundation

struct HomeFiltersSheetConfiguration {
    let taskListMode: HomeFeature.TaskListMode
    let availableFilters: [RoutineListFilter]
    let place: HomeFiltersPlaceConfiguration
    let importanceUrgencySummary: String
    let hasActiveOptionalFilters: Bool
}

struct HomeFiltersPlaceConfiguration {
    let sortedRoutinePlaces: [RoutinePlace]
    let hasSavedPlaces: Bool
    let hasPlaceLinkedRoutines: Bool
    let isLocationAuthorized: Bool
    let placeFilterPluralNoun: String
    let placeFilterAllTitle: String
    let placeFilterSectionDescription: String
    let locationStatusText: String
}

struct HomeFiltersSheetActions {
    let tagActions: HomeTagFilterActions
    let onClearOptionalFilters: () -> Void
    let onDismiss: () -> Void
}

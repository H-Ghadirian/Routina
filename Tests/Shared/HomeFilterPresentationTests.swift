import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct HomeFilterPresentationTests {
    @Test
    func activeOptionalFilterCountTracksEveryFilterBucket() {
        let presentation = HomeFilterPresentation(
            taskListKind: .todos,
            advancedQuery: "type:todo",
            taskListViewMode: .actionable,
            selectedTodoStateFilter: .inProgress,
            selectedTags: ["Focus", "Work"],
            excludedTags: ["Errand", "Low"],
            hasSelectedPlaceFilter: true,
            selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell(importance: .level3, urgency: .level2),
            selectedPressureFilter: .medium,
            selectedGoalFilter: .withGoal,
            hideUnavailableRoutines: true
        )

        #expect(presentation.activeOptionalFilterCount == 11)
        #expect(presentation.hasActiveOptionalFilters)
    }

    @Test
    func filterLabelsBuildCompactMacSidebarSummary() {
        let presentation = HomeFilterPresentation(
            taskListKind: .all,
            selectedFilter: .due,
            advancedQuery: "tag:work",
            taskListViewMode: .actionable,
            selectedTodoStateFilter: .blocked,
            selectedTags: ["Focus", "Work"],
            includeTagMatchMode: .any,
            excludedTags: ["Errand"],
            selectedPlaceName: "Office",
            selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell(importance: .level4, urgency: .level3),
            selectedPressureFilter: .high,
            selectedGoalFilter: .withoutGoal,
            hideUnavailableRoutines: true
        )

        #expect(presentation.filterLabels == [
            "Due",
            "Don't show blocked tasks",
            "Blocked",
            "Pressure High",
            "No Goal",
            "Query tag:work",
            "Any 2 tags",
            "not #Errand",
            "Office",
            "L4/L3+",
            "Away hidden"
        ])
        #expect(presentation.activeTaskFiltersSummary(resultCount: 12, maxVisibleCount: 4) == "Due • Don't show blocked tasks • Blocked • Pressure High +7 • 12 results")
    }

    @Test
    func allLevelsThresholdDoesNotCountAsActiveImportanceUrgencyFilter() {
        let presentation = HomeFilterPresentation(
            taskListKind: .all,
            selectedImportanceUrgencyFilter: .allLevels
        )

        #expect(presentation.activeOptionalFilterCount == 0)
        #expect(!presentation.hasActiveOptionalFilters)
        #expect(presentation.filterLabels.isEmpty)
        #expect(presentation.selectedImportanceUrgencyFilterLabel == nil)
        #expect(presentation.importanceUrgencyFilterSummary == "Showing tasks across all importance and urgency levels.")
    }

    @Test
    func showingAssumedDoneTasksCountsAsNonDefaultFilter() {
        let presentation = HomeFilterPresentation(
            taskListKind: .all,
            hideAssumedDoneTasks: false
        )

        #expect(presentation.activeOptionalFilterCount == 1)
        #expect(presentation.hasActiveOptionalFilters)
        #expect(presentation.filterLabels == ["Assumed visible"])
    }

    @Test
    func placeCopyAdaptsToTaskListKindAndSavedPlaces() {
        let selected = HomeFilterPresentation(
            taskListKind: .routines,
            selectedPlaceName: "Gym",
            hasSavedPlaces: true
        )
        let empty = HomeFilterPresentation(
            taskListKind: .todos,
            hasSavedPlaces: false
        )

        #expect(selected.placeFilterPluralNoun == "routines")
        #expect(selected.placeFilterAllTitle == "All routines")
        #expect(selected.manualPlaceFilterDescription == "Showing only routines linked to Gym.")
        #expect(empty.placeFilterSectionDescription == "Save a place in Settings, then link it to a task to filter by place here.")
    }

    @Test
    func locationStatusTextMatchesAvailabilityAndAuthorization() {
        let hiddenAway = HomeFilterPresentation(
            taskListKind: .all,
            hideUnavailableRoutines: true,
            awayRoutineCount: 3,
            locationAuthorizationStatus: .authorizedWhenInUse
        )
        let unavailable = HomeFilterPresentation(
            taskListKind: .all,
            locationAuthorizationStatus: .denied
        )

        #expect(hiddenAway.locationStatusText == "3 routines are hidden because you are away from their matching places.")
        #expect(unavailable.locationStatusText == "Location access is off, so place-based routines stay visible.")
    }
}

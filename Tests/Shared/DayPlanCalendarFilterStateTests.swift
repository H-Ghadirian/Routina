import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct DayPlanCalendarFilterStateTests {
    @Test
    func unavailableBetaLayersDoNotRegisterAsHiddenFilters() {
        var filters = DayPlanCalendarFilterState()
        filters.showsEvents = false
        filters.showsAway = false
        filters.showsSleep = false

        let unavailableBetaLayers = DayPlanCalendarFilterAvailability(
            includesEvents: false,
            includesAway: false,
            includesSleep: false
        )

        #expect(filters.hiddenLayerCount(availability: unavailableBetaLayers) == 0)
        #expect(filters.summaryText(availability: unavailableBetaLayers) == "All layers visible")
        #expect(!filters.hasActiveFilters(availability: unavailableBetaLayers))
    }

    @Test
    func unavailableBetaLayersNormalizeToVisibleForRendering() {
        var filters = DayPlanCalendarFilterState()
        filters.showsEvents = false
        filters.showsAway = false
        filters.showsSleep = false
        filters.showsFocus = false

        let unavailableBetaLayers = DayPlanCalendarFilterAvailability(
            includesEvents: false,
            includesAway: false,
            includesSleep: false
        )

        let normalized = filters.normalized(availability: unavailableBetaLayers)

        #expect(normalized.showsEvents)
        #expect(normalized.showsAway)
        #expect(normalized.showsSleep)
        #expect(!normalized.showsFocus)
        #expect(filters.hiddenLayerCount(availability: unavailableBetaLayers) == 1)
        #expect(filters.summaryText(availability: unavailableBetaLayers) == "1 layer hidden")
    }

    @Test
    func availableBetaLayersStillRegisterAsHiddenFilters() {
        var filters = DayPlanCalendarFilterState()
        filters.showsEvents = false
        filters.showsAway = false
        filters.showsSleep = false

        let allLayersAvailable = DayPlanCalendarFilterAvailability()

        #expect(filters.hiddenLayerCount(availability: allLayersAvailable) == 3)
        #expect(filters.summaryText(availability: allLayersAvailable) == "3 layers hidden")
        #expect(filters.hasActiveFilters(availability: allLayersAvailable))
    }
}

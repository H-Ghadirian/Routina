import Foundation
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
        #expect(filters.summaryText(availability: unavailableBetaLayers) == "Default layers visible")
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

    @Test
    func assumedDoneLayerIsHiddenByDefaultButDoesNotCountAsAnActiveFilter() {
        let filters = DayPlanCalendarFilterState()
        let availability = DayPlanCalendarFilterAvailability()

        #expect(!filters.showsAssumedDone)
        #expect(filters.hiddenLayerCount(availability: availability) == 0)
        #expect(filters.summaryText(availability: availability) == "Default layers visible")
        #expect(!filters.hasActiveFilters(availability: availability))
    }

    @Test
    func assumedDoneTimelineActivityCanBeShownFromFilters() {
        let assumedDone = timelineActivity(source: .assumedDone)
        let recordedDone = timelineActivity(source: .log(UUID()))
        var filters = DayPlanCalendarFilterState()

        #expect(!filters.includesTimelineActivity(assumedDone))
        #expect(filters.includesTimelineActivity(recordedDone))

        filters.showsAssumedDone = true

        #expect(filters.includesTimelineActivity(assumedDone))
        #expect(filters.includesTimelineActivity(recordedDone))
        #expect(filters.summaryText(availability: DayPlanCalendarFilterAvailability()) == "Showing assumed done")
        #expect(filters.hasActiveFilters(availability: DayPlanCalendarFilterAvailability()))
    }

    @Test
    func resetReturnsToHidingAssumedDoneTimelineActivity() {
        var filters = DayPlanCalendarFilterState()
        filters.showsAssumedDone = true

        filters.reset()

        #expect(!filters.showsAssumedDone)
    }

    @Test
    func dayAgendaCanIncludeAssumedDoneWhenCalendarLayerIsHidden() {
        let assumedDone = timelineActivity(source: .assumedDone)
        let filters = DayPlanCalendarFilterState()

        #expect(!filters.includesTimelineActivity(assumedDone))
        #expect(filters.includesTimelineActivity(assumedDone, includesAssumedDone: true))
    }

    private func timelineActivity(source: DayPlanTimelineActivitySource) -> DayPlanTimelineActivityBlock {
        let taskID = UUID()
        return DayPlanTimelineActivityBlock(
            block: DayPlanBlock(
                id: taskID,
                taskID: taskID,
                dayKey: "2026-07-11",
                startMinute: 9 * 60,
                durationMinutes: 30,
                titleSnapshot: "Morning reset"
            ),
            kind: .completed,
            source: source
        )
    }
}

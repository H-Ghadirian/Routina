import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct DayPlanSlotActionPresentationTests {
    @Test
    func visibleSlotActionModesHideSleepWhenAwayExperimentIsOff() {
        #expect(DayPlanSlotActionMode.visibleCases(includingAway: false) == [.task])
        #expect(DayPlanSlotActionMode.visibleCases(includingAway: true) == [.task, .away])
    }
}

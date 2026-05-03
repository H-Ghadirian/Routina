import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TaskDetailTimeSpentPresentationTests {
    @Test
    func defaultEditMinutesPrefersCurrentThenEstimateThenFallback() {
        #expect(TaskDetailTimeSpentPresentation.defaultEditMinutes(currentMinutes: 42, estimatedMinutes: 15) == 42)
        #expect(TaskDetailTimeSpentPresentation.defaultEditMinutes(currentMinutes: nil, estimatedMinutes: 15) == 15)
        #expect(TaskDetailTimeSpentPresentation.defaultEditMinutes(currentMinutes: nil, estimatedMinutes: nil) == 25)
        #expect(TaskDetailTimeSpentPresentation.defaultEditMinutes(currentMinutes: 2_000, estimatedMinutes: nil) == 1_440)
    }

    @Test
    func entryPreviewAndApplyCopyUseSharedDurationText() {
        let entry = TaskDetailTimeSpentPresentation.entryTotalMinutes(hours: 1, minutes: 15)

        #expect(entry == 75)
        #expect(TaskDetailTimeSpentPresentation.previewTotalMinutes(currentMinutes: 30, entryMinutes: entry) == 105)
        #expect(TaskDetailTimeSpentPresentation.previewText(currentMinutes: 30, entryMinutes: entry) == "Total 1 hour 45 minutes")
        #expect(TaskDetailTimeSpentPresentation.applyTitle(entryMinutes: entry) == "Add 1 hour 15 minutes")
        #expect(TaskDetailTimeSpentPresentation.canApplyEntry(currentMinutes: 30, entryMinutes: entry))
        #expect(!TaskDetailTimeSpentPresentation.canApplyEntry(currentMinutes: 1_430, entryMinutes: 15))
    }

    @Test
    func focusSessionSecondsRoundToAtLeastOneMinute() {
        #expect(TaskDetailTimeSpentPresentation.focusSessionMinutes(from: 1) == 1)
        #expect(TaskDetailTimeSpentPresentation.focusSessionMinutes(from: 89) == 1)
        #expect(TaskDetailTimeSpentPresentation.focusSessionMinutes(from: 90) == 2)
    }
}

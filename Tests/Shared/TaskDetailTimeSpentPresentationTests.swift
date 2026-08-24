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
        #expect(TaskDetailTimeSpentPresentation.previewText(currentMinutes: 30, entryMinutes: entry) == "New total 1 hour 45 minutes")
        #expect(TaskDetailTimeSpentPresentation.applyTitle(entryMinutes: entry) == "Add 1 hour 15 minutes")
        #expect(TaskDetailTimeSpentPresentation.applyTitle(currentMinutes: nil, entryMinutes: entry) == "Log 1 hour 15 minutes")
        #expect(TaskDetailTimeSpentPresentation.applyTitle(currentMinutes: 30, entryMinutes: entry) == "Add 1 hour 15 minutes")
        #expect(TaskDetailTimeSpentPresentation.canApplyEntry(currentMinutes: 30, entryMinutes: entry))
        #expect(!TaskDetailTimeSpentPresentation.canApplyEntry(currentMinutes: 1_430, entryMinutes: 15))
    }

    @Test
    func previewCopyHandlesEmptyEntry() {
        #expect(TaskDetailTimeSpentPresentation.previewText(currentMinutes: nil, entryMinutes: 0) == "Enter time to log")
        #expect(TaskDetailTimeSpentPresentation.previewText(currentMinutes: 30, entryMinutes: 0) == "Current total 30 minutes")
    }

    @Test
    func timeSectionOnlyForcesOpenForActiveFocus() {
        #expect(!TaskDetailTimeSpentPresentation.shouldForceExpandSection(
            hasActiveFocus: false,
            showsFocusTimer: true
        ))
        #expect(TaskDetailTimeSpentPresentation.shouldForceExpandSection(
            hasActiveFocus: true,
            showsFocusTimer: false
        ))
    }

    @Test
    func defaultEditMinutesCanBeBuiltFromTaskAndLog() {
        let task = RoutineTask(name: "Practice", estimatedDurationMinutes: 40, actualDurationMinutes: 10)
        let log = RoutineLog(taskID: task.id, kind: .completed, actualDurationMinutes: nil)

        #expect(TaskDetailTimeSpentPresentation.defaultTaskEditMinutes(task: task) == 10)
        #expect(TaskDetailTimeSpentPresentation.defaultLogEditMinutes(log: log, task: task) == 40)
    }

}

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

    @Test
    func defaultEditMinutesCanBeBuiltFromTaskAndLog() {
        let task = RoutineTask(name: "Practice", estimatedDurationMinutes: 40, actualDurationMinutes: 10)
        let log = RoutineLog(taskID: task.id, kind: .completed, actualDurationMinutes: nil)

        #expect(TaskDetailTimeSpentPresentation.defaultTaskEditMinutes(task: task) == 10)
        #expect(TaskDetailTimeSpentPresentation.defaultLogEditMinutes(log: log, task: task) == 40)
    }

    @Test
    func focusSessionUpdateTargetsTodoOrLatestCompletedLog() {
        let todo = RoutineTask(name: "Write report", scheduleMode: .oneOff, actualDurationMinutes: 15)
        let todoUpdate = TaskDetailTimeSpentPresentation.focusSessionUpdate(
            task: todo,
            logs: [],
            seconds: 30 * 60
        )

        #expect(todoUpdate == .init(target: .task, minutes: 45))

        let routine = RoutineTask(name: "Practice")
        let olderLog = RoutineLog(
            timestamp: makeDate("2026-04-25T08:00:00Z"),
            taskID: routine.id,
            kind: .completed,
            actualDurationMinutes: 10
        )
        let latestLog = RoutineLog(
            timestamp: makeDate("2026-04-25T10:00:00Z"),
            taskID: routine.id,
            kind: .completed,
            actualDurationMinutes: 20
        )

        let routineUpdate = TaskDetailTimeSpentPresentation.focusSessionUpdate(
            task: routine,
            logs: [latestLog, olderLog],
            seconds: 30 * 60
        )

        #expect(routineUpdate == .init(target: .log(latestLog.id), minutes: 50))
    }
}

import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct TaskDetailSharedViewSupportTests {
    @Test
    func durationTextFormatsMinutesHoursAndMixedDurations() {
        #expect(TaskDetailHeaderBadgePresentation.durationText(for: 1) == "1 minute")
        #expect(TaskDetailHeaderBadgePresentation.durationText(for: 25) == "25 minutes")
        #expect(TaskDetailHeaderBadgePresentation.durationText(for: 60) == "1 hour")
        #expect(TaskDetailHeaderBadgePresentation.durationText(for: 125) == "2 hours 5 minutes")
    }

    @Test
    func displayedActualDurationUsesTodoStoredValueAndRoutineLogs() {
        let todo = RoutineTask(
            name: "Buy milk",
            scheduleMode: .oneOff,
            actualDurationMinutes: 15
        )
        let routine = RoutineTask(name: "Practice", scheduleMode: .fixedInterval)
        let logs = [
            RoutineLog(taskID: routine.id, kind: .completed, actualDurationMinutes: 20),
            RoutineLog(taskID: routine.id, kind: .canceled, actualDurationMinutes: 30),
            RoutineLog(taskID: routine.id, kind: .completed, actualDurationMinutes: 25)
        ]

        #expect(TaskDetailHeaderBadgePresentation.displayedActualDurationMinutes(task: todo, logs: logs) == 15)
        #expect(TaskDetailHeaderBadgePresentation.displayedActualDurationMinutes(task: routine, logs: logs) == 45)
    }

    @Test
    func statusMetadataItemsBuildSharedTaskDetailRows() {
        let referenceDate = makeDate("2026-04-25T10:00:00Z")
        let task = RoutineTask(
            name: "Write report",
            imageData: Data([1]),
            steps: [
                RoutineStep(title: "Outline"),
                RoutineStep(title: "Draft")
            ],
            scheduleMode: .fixedInterval,
            interval: 2
        )
        var state = TaskDetailFeature.State(task: task)
        state.logs = [
            RoutineLog(taskID: task.id, kind: .completed, actualDurationMinutes: 35)
        ]
        state.taskAttachments = [
            AttachmentItem(fileName: "notes.txt", data: Data([2]))
        ]

        let items = TaskDetailStatusMetadataPresentation.items(
            for: state,
            showSelectedDate: true,
            displayedActualDurationText: "35 minutes",
            dueDateMetadataDisplayText: "Tomorrow",
            referenceDate: referenceDate
        )

        #expect(items.map(\.id).contains("frequency"))
        #expect(items.map(\.id).contains("completed"))
        #expect(items.map(\.id).contains("timeSpent"))
        #expect(items.first { $0.id == "attachments" }?.value == "1 image, 1 file")
        #expect(items.first { $0.id == "stepProgress" }?.value == "2 sequential steps")
        #expect(items.first { $0.id == "nextStep" }?.value == "Outline")
    }
}

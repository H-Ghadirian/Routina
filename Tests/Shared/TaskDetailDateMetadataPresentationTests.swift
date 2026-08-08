import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TaskDetailDateMetadataPresentationTests {
    @Test
    func dueDateMetadataHidesUntimedRoutineDueToday() {
        let today = Date()

        #expect(
            TaskDetailDateMetadataPresentation.dueDateMetadataText(
                dueDate: today,
                isOneOffTask: false,
                usesExplicitTimeOfDay: false
            ) == nil
        )
    }

    @Test
    func selectedDateAndCancelCopyUseTodayCopyForToday() {
        let today = Date()

        #expect(
            TaskDetailDateMetadataPresentation.selectedDateMetadataText(
                selectedDate: today
            ) == "Today"
        )
        #expect(
            TaskDetailDateMetadataPresentation.cancelTodoButtonTitle(
                selectedDate: today
            ) == "Cancel todo"
        )
    }

    @Test
    func selectedDateMetadataHiddenForCompletedTodo() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let completedTodo = RoutineTask(
            scheduleMode: .oneOff,
            lastDone: yesterday
        )

        #expect(
            TaskDetailDateMetadataPresentation.shouldShowSelectedDateMetadata(
                selectedDate: yesterday,
                task: completedTodo
            ) == false
        )
    }

    @Test
    func scheduledTimeBlockMetadataDescribesOneOffDateAndRange() throws {
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            name: "Watch film",
            availabilityStartDate: makeDate("2026-08-08T00:00:00Z"),
            scheduleMode: .oneOff,
            recurrenceRule: .interval(
                days: 1,
                timeRange: RoutineTimeRange(
                    start: RoutineTimeOfDay(hour: 12, minute: 0),
                    end: RoutineTimeOfDay(hour: 15, minute: 0)
                )
            ),
            recurrenceTimeRangeRole: .scheduledBlock
        )

        let metadata = try #require(
            TaskDetailDateMetadataPresentation.scheduledTimeBlockMetadataText(
                task: task,
                calendar: calendar
            )
        )

        #expect(metadata.contains("·"))
        #expect(metadata.contains("–"))
    }
}

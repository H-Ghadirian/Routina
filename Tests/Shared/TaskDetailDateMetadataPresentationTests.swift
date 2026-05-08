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
}

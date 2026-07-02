import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TaskDetailCompletionButtonTitlePresentationTests {
    @Test
    func titlePrefersUndoWhenSelectedDateIsTerminal() {
        let task = RoutineTask(name: "Stretch")

        let title = makePresentation(
            task: task,
            isSelectedDateTerminal: true
        ).title

        #expect(title == "Undo")
    }

    @Test
    func titleBlocksFutureRoutineCompletion() {
        let task = RoutineTask(name: "Stretch")
        let future = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        let title = makePresentation(
            task: task,
            selectedDate: future,
            isSelectedDateInFuture: true
        ).title

        #expect(title == "Future dates can't be marked done")
    }

    @Test
    func titleUsesTodoCopyForToday() {
        let task = RoutineTask(name: "Buy milk", scheduleMode: .oneOff)

        let title = makePresentation(task: task).title

        #expect(title == "Done")
    }

    @Test
    func titleBlocksManualCompletionUntilOptionalChecklistIsComplete() {
        let task = RoutineTask(
            name: "Pack bag",
            checklistItems: [
                RoutineChecklistItem(title: "Laptop", intervalDays: 1),
                RoutineChecklistItem(title: "Charger", intervalDays: 1)
            ],
            scheduleMode: .oneOff
        )

        let title = makePresentation(task: task).title

        #expect(title == "Complete checklist items first")
    }

    @Test
    func titleUsesSelectedPastDayForRunoutDueItems() {
        let selectedDate = makeDate("2026-07-01T08:00:00Z")
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            name: "Groceries",
            checklistItems: [
                RoutineChecklistItem(
                    title: "Bread",
                    intervalDays: 3,
                    createdAt: makeDate("2026-06-28T10:00:00Z")
                )
            ],
            scheduleMode: .derivedFromChecklist
        )
        var presentation = makePresentation(
            task: task,
            selectedDate: selectedDate
        )
        presentation.calendar = calendar

        #expect(presentation.title == "Done: Bread")
    }

    private func makePresentation(
        task: RoutineTask,
        selectedDate: Date = Date(),
        isSelectedDateTerminal: Bool = false,
        isSelectedDateInFuture: Bool = false,
        shouldUseBulkConfirmAsPrimaryAction: Bool = false,
        bulkConfirmAssumedDaysTitle: String = "",
        isSelectedDateAssumedDone: Bool = false,
        completionTargetDate: Date? = nil
    ) -> TaskDetailCompletionButtonTitlePresentation {
        TaskDetailCompletionButtonTitlePresentation(
            task: task,
            selectedDate: selectedDate,
            isSelectedDateTerminal: isSelectedDateTerminal,
            isSelectedDateInFuture: isSelectedDateInFuture,
            shouldUseBulkConfirmAsPrimaryAction: shouldUseBulkConfirmAsPrimaryAction,
            bulkConfirmAssumedDaysTitle: bulkConfirmAssumedDaysTitle,
            isSelectedDateAssumedDone: isSelectedDateAssumedDone,
            completionTargetDate: completionTargetDate
        )
    }
}

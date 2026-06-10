import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct HomeTaskLifecycleSupportTests {
    @Test
    func markTaskDone_blocksOptionalChecklistUntilEveryItemIsChecked() {
        let firstID = UUID()
        let secondID = UUID()
        let task = RoutineTask(
            name: "Pack bag",
            checklistItems: [
                RoutineChecklistItem(id: firstID, title: "Laptop", intervalDays: 1),
                RoutineChecklistItem(id: secondID, title: "Charger", intervalDays: 1)
            ],
            scheduleMode: .oneOff
        )
        #expect(task.markOptionalChecklistItemCompleted(firstID))
        var tasks = [task]
        var doneStats = HomeDoneStats()

        let blockedUpdate = HomeTaskLifecycleSupport.markTaskDone(
            taskID: task.id,
            referenceDate: makeDate("2026-05-08T10:00:00Z"),
            calendar: makeTestCalendar(),
            tasks: &tasks,
            doneStats: &doneStats
        )

        #expect(blockedUpdate == nil)
        #expect(tasks[0].lastDone == nil)
        #expect(doneStats.totalCount == 0)

        #expect(tasks[0].markOptionalChecklistItemCompleted(secondID))
        let allowedUpdate = HomeTaskLifecycleSupport.markTaskDone(
            taskID: task.id,
            referenceDate: makeDate("2026-05-08T10:00:00Z"),
            calendar: makeTestCalendar(),
            tasks: &tasks,
            doneStats: &doneStats
        )

        #expect(allowedUpdate == .advance(HomeAdvanceTaskUpdate(
            taskID: task.id,
            completionDate: makeDate("2026-05-08T10:00:00Z"),
            previousTodoStateTitle: TodoState.ready.displayTitle
        )))
        #expect(tasks[0].lastDone == makeDate("2026-05-08T10:00:00Z"))
        #expect(doneStats.totalCount == 1)
    }

    @Test
    func markTaskDone_forMissedExactTimeRoutineCompletesMissedOccurrence() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = RoutineTask(
            name: "Class",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-05-01T10:00:00Z")
        )
        var tasks = [task]
        var doneStats = HomeDoneStats()

        let update = HomeTaskLifecycleSupport.markTaskDone(
            taskID: task.id,
            referenceDate: makeDate("2026-05-08T10:00:00Z"),
            calendar: calendar,
            tasks: &tasks,
            doneStats: &doneStats
        )

        #expect(update == .advance(HomeAdvanceTaskUpdate(
            taskID: task.id,
            completionDate: makeDate("2026-05-07T18:30:00Z"),
            previousTodoStateTitle: nil
        )))
        #expect(tasks[0].lastDone == makeDate("2026-05-07T18:30:00Z"))
        #expect(doneStats.totalCount == 1)
        #expect(doneStats.countsByTaskID[task.id] == 1)
    }

    @Test
    func markTaskMissed_acknowledgesMissedOccurrenceWithoutCompletionCount() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = RoutineTask(
            name: "Class",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-05-01T10:00:00Z")
        )
        var doneStats = HomeDoneStats()

        let update = HomeTaskLifecycleSupport.markTaskMissed(
            taskID: task.id,
            referenceDate: makeDate("2026-05-08T10:00:00Z"),
            calendar: calendar,
            tasks: [task],
            doneStats: &doneStats
        )

        #expect(update == HomeMarkTaskMissedUpdate(
            taskID: task.id,
            missedDate: makeDate("2026-05-07T18:30:00Z"),
            referenceDate: makeDate("2026-05-08T10:00:00Z")
        ))
        #expect(task.lastDone == nil)
        #expect(doneStats.totalCount == 0)
        #expect(doneStats.countsByTaskID.isEmpty)
        #expect(doneStats.missedDatesByTaskID[task.id] == [makeDate("2026-05-07T18:30:00Z")])
    }

    @Test
    func markTaskCanceled_acknowledgesMissedOccurrenceAsCanceledWithoutCompletionCount() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = RoutineTask(
            name: "Class",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-05-01T10:00:00Z")
        )
        var doneStats = HomeDoneStats()

        let update = HomeTaskLifecycleSupport.markTaskCanceled(
            taskID: task.id,
            referenceDate: makeDate("2026-05-08T10:00:00Z"),
            calendar: calendar,
            tasks: [task],
            doneStats: &doneStats
        )

        #expect(update == HomeMarkTaskCanceledUpdate(
            taskID: task.id,
            canceledDate: makeDate("2026-05-07T18:30:00Z"),
            referenceDate: makeDate("2026-05-08T10:00:00Z")
        ))
        #expect(task.lastDone == nil)
        #expect(doneStats.totalCount == 0)
        #expect(doneStats.countsByTaskID.isEmpty)
        #expect(doneStats.canceledTotalCount == 1)
        #expect(doneStats.canceledCountsByTaskID[task.id] == 1)
        #expect(doneStats.canceledDatesByTaskID[task.id] == [makeDate("2026-05-07T18:30:00Z")])
    }

    @Test
    func planTaskStoresDateOnlyAndCanClearPlan() {
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            name: "Draft outline",
            scheduleMode: .oneOff
        )
        let plannedDate = makeDate("2026-06-10T16:20:00Z")
        let normalizedDate = calendar.startOfDay(for: plannedDate)
        var tasks = [task]

        let update = HomeTaskLifecycleSupport.planTask(
            taskID: task.id,
            plannedDate: plannedDate,
            calendar: calendar,
            tasks: &tasks
        )

        #expect(update == HomePlanTaskUpdate(taskID: task.id, plannedDate: normalizedDate))
        #expect(tasks[0].plannedDate == normalizedDate)

        let unchangedUpdate = HomeTaskLifecycleSupport.planTask(
            taskID: task.id,
            plannedDate: normalizedDate,
            calendar: calendar,
            tasks: &tasks
        )

        #expect(unchangedUpdate == nil)

        let clearUpdate = HomeTaskLifecycleSupport.planTask(
            taskID: task.id,
            plannedDate: nil,
            calendar: calendar,
            tasks: &tasks
        )

        #expect(clearUpdate == HomePlanTaskUpdate(taskID: task.id, plannedDate: nil))
        #expect(tasks[0].plannedDate == nil)
    }

    @Test
    func planTaskDoesNotPlanDailyRoutine() {
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            name: "Morning review",
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 1)
        )
        var tasks = [task]

        let update = HomeTaskLifecycleSupport.planTask(
            taskID: task.id,
            plannedDate: makeDate("2026-06-10T16:20:00Z"),
            calendar: calendar,
            tasks: &tasks
        )

        #expect(update == nil)
        #expect(tasks[0].plannedDate == nil)
    }

    @Test
    func planTaskAllowsChecklistDrivenRoutineWithoutDailyRunoutItem() {
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            name: "Pantry restock",
            checklistItems: [RoutineChecklistItem(title: "Rice", intervalDays: 3)],
            scheduleMode: .derivedFromChecklist,
            recurrenceRule: .interval(days: 1)
        )
        let plannedDate = makeDate("2026-06-10T16:20:00Z")
        let normalizedDate = calendar.startOfDay(for: plannedDate)
        var tasks = [task]

        let update = HomeTaskLifecycleSupport.planTask(
            taskID: task.id,
            plannedDate: plannedDate,
            calendar: calendar,
            tasks: &tasks
        )

        #expect(update == HomePlanTaskUpdate(taskID: task.id, plannedDate: normalizedDate))
        #expect(tasks[0].plannedDate == normalizedDate)
    }

    @Test
    func planTaskDoesNotPlanChecklistDrivenRoutineWithDailyRunoutItem() {
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            name: "Pantry restock",
            checklistItems: [RoutineChecklistItem(title: "Milk", intervalDays: 1)],
            scheduleMode: .derivedFromChecklist,
            recurrenceRule: .interval(days: 1)
        )
        var tasks = [task]

        let update = HomeTaskLifecycleSupport.planTask(
            taskID: task.id,
            plannedDate: makeDate("2026-06-10T16:20:00Z"),
            calendar: calendar,
            tasks: &tasks
        )

        #expect(update == nil)
        #expect(tasks[0].plannedDate == nil)
    }
}

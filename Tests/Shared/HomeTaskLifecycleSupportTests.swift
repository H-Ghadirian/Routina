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
        #expect(doneStats.completedDatesByTaskID[task.id] == [makeDate("2026-05-08T10:00:00Z")])
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
        #expect(doneStats.completedDatesByTaskID[task.id] == [makeDate("2026-05-07T18:30:00Z")])
    }

    @Test
    func markTaskDone_fulfillsLinkedRoutineWithoutIncreasingAggregateDoneCount() {
        let calendar = makeTestCalendar()
        let completedAt = makeDate("2026-05-01T10:00:00Z")
        let gym = RoutineTask(name: "Gym", scheduleMode: .fixedInterval)
        let exercise = RoutineTask(
            name: "Exercise routine",
            relationships: [
                RoutineTaskRelationship(targetTaskID: gym.id, kind: .doneWhen)
            ],
            scheduleMode: .fixedInterval
        )
        var tasks = [gym, exercise]
        var doneStats = HomeDoneStats()

        let update = HomeTaskLifecycleSupport.markTaskDone(
            taskID: gym.id,
            referenceDate: completedAt,
            calendar: calendar,
            tasks: &tasks,
            doneStats: &doneStats
        )
        let updatedExercise = tasks.first { $0.id == exercise.id }

        #expect(update == .advance(HomeAdvanceTaskUpdate(
            taskID: gym.id,
            completionDate: completedAt,
            previousTodoStateTitle: nil
        )))
        #expect(doneStats.totalCount == 1)
        #expect(doneStats.countsByTaskID[gym.id] == 1)
        #expect(doneStats.countsByTaskID[exercise.id] == nil)
        #expect(doneStats.completedDatesByTaskID[gym.id] == [completedAt])
        #expect(doneStats.completedDatesByTaskID[exercise.id] == [completedAt])
        #expect(updatedExercise?.lastDone == completedAt)
    }

    @Test
    func markTaskDone_forSameDayMissedTimeWindowCompletesCurrentOccurrenceBeforeOlderMisses() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = RoutineTask(
            name: "Class",
            recurrenceRule: .weekly(
                on: 5,
                timeRange: RoutineTimeRange(
                    start: RoutineTimeOfDay(hour: 18, minute: 30),
                    end: RoutineTimeOfDay(hour: 20, minute: 0)
                )
            ),
            scheduleAnchor: makeDate("2026-06-25T10:00:00Z"),
            createdAt: makeDate("2026-06-25T10:00:00Z")
        )
        var tasks = [task]
        var doneStats = HomeDoneStats()

        let update = HomeTaskLifecycleSupport.markTaskDone(
            taskID: task.id,
            referenceDate: makeDate("2026-07-09T22:00:00Z"),
            calendar: calendar,
            tasks: &tasks,
            doneStats: &doneStats
        )

        #expect(update == .advance(HomeAdvanceTaskUpdate(
            taskID: task.id,
            completionDate: makeDate("2026-07-09T18:30:00Z"),
            previousTodoStateTitle: nil
        )))
        #expect(tasks[0].lastDone == makeDate("2026-07-09T18:30:00Z"))
        #expect(doneStats.completedDatesByTaskID[task.id] == [makeDate("2026-07-09T18:30:00Z")])
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
    func markTaskMissed_skipsAcknowledgedEarlierMissedOccurrence() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let firstMissed = makeDate("2026-05-07T18:30:00Z")
        let secondMissed = makeDate("2026-05-14T18:30:00Z")
        let task = RoutineTask(
            name: "Class",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-05-01T10:00:00Z")
        )
        var doneStats = HomeDoneStats(missedDatesByTaskID: [task.id: [firstMissed]])

        let update = HomeTaskLifecycleSupport.markTaskMissed(
            taskID: task.id,
            referenceDate: makeDate("2026-05-15T10:00:00Z"),
            calendar: calendar,
            tasks: [task],
            doneStats: &doneStats
        )

        #expect(update == HomeMarkTaskMissedUpdate(
            taskID: task.id,
            missedDate: secondMissed,
            referenceDate: makeDate("2026-05-15T10:00:00Z")
        ))
        #expect(doneStats.missedDatesByTaskID[task.id] == [firstMissed, secondMissed])
    }

    @Test
    func confirmAssumedTaskDone_recordsOptimisticCompletionForToday() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-05-08T10:00:00Z")
        let task = RoutineTask(
            name: "Review notes",
            scheduleMode: .record,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 8, minute: 0)),
            createdAt: makeDate("2026-05-01T10:00:00Z"),
            autoAssumeDailyDone: true
        )
        var doneStats = HomeDoneStats()

        let update = HomeTaskLifecycleSupport.confirmAssumedTaskDone(
            taskID: task.id,
            referenceDate: referenceDate,
            calendar: calendar,
            tasks: [task],
            doneStats: &doneStats
        )

        #expect(update == HomeResolveAssumedTaskUpdate(
            taskID: task.id,
            resolutionDate: referenceDate,
            referenceDate: referenceDate
        ))
        #expect(doneStats.totalCount == 1)
        #expect(doneStats.countsByTaskID[task.id] == 1)
        #expect(doneStats.completedDatesByTaskID[task.id] == [referenceDate])
    }

    @Test
    func markAssumedTaskMissed_recordsOptimisticMissForToday() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-05-08T10:00:00Z")
        let task = RoutineTask(
            name: "Review notes",
            scheduleMode: .record,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 8, minute: 0)),
            createdAt: makeDate("2026-05-01T10:00:00Z"),
            autoAssumeDailyDone: true
        )
        var doneStats = HomeDoneStats()

        let update = HomeTaskLifecycleSupport.markAssumedTaskMissed(
            taskID: task.id,
            referenceDate: referenceDate,
            calendar: calendar,
            tasks: [task],
            doneStats: &doneStats
        )

        #expect(update == HomeResolveAssumedTaskUpdate(
            taskID: task.id,
            resolutionDate: referenceDate,
            referenceDate: referenceDate
        ))
        #expect(doneStats.totalCount == 0)
        #expect(doneStats.countsByTaskID.isEmpty)
        #expect(doneStats.missedDatesByTaskID[task.id] == [referenceDate])
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
    func planTaskKeepsExactTodoAvailabilityPlannedOnSameDate() {
        let calendar = makeTestCalendar()
        let availabilityDate = makeDate("2026-07-19T11:30:00Z")
        let expectedDate = makeDate("2026-07-19T00:00:00Z")
        let task = RoutineTask(
            name: "Visit pharmacy",
            availabilityStartDate: availabilityDate,
            scheduleMode: .oneOff
        )
        task.plannedDate = nil
        var tasks = [task]

        let update = HomeTaskLifecycleSupport.planTask(
            taskID: task.id,
            plannedDate: nil,
            calendar: calendar,
            tasks: &tasks
        )

        #expect(update == HomePlanTaskUpdate(taskID: task.id, plannedDate: expectedDate))
        #expect(tasks[0].plannedDate == expectedDate)
    }

    @Test
    func planTaskClearsCustomSectionAssignmentWhenDateIsSet() {
        let calendar = makeTestCalendar()
        let customSectionID = UUID()
        let task = RoutineTask(
            name: "Draft outline",
            customTaskSectionID: customSectionID,
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

        #expect(update == HomePlanTaskUpdate(
            taskID: task.id,
            plannedDate: normalizedDate,
            customTaskSectionID: nil
        ))
        #expect(tasks[0].plannedDate == normalizedDate)
        #expect(tasks[0].customTaskSectionID == nil)
    }

    @Test
    func deleteCustomTaskSectionClearsAssignmentsAndManualOrder() {
        let deletedSectionID = UUID()
        let otherSectionID = UUID()
        let deletedSectionKey = HomeCustomTaskSectionStorage.manualOrderSectionKey(for: deletedSectionID)
        let otherSectionKey = HomeCustomTaskSectionStorage.manualOrderSectionKey(for: otherSectionID)

        let assignedTask = RoutineTask(
            name: "Assigned",
            customTaskSectionID: deletedSectionID,
            scheduleMode: .oneOff
        )
        assignedTask.manualSectionOrders = [deletedSectionKey: 0]

        let staleManualOrderTask = RoutineTask(
            name: "Other section",
            customTaskSectionID: otherSectionID,
            scheduleMode: .oneOff
        )
        staleManualOrderTask.manualSectionOrders = [
            deletedSectionKey: 1,
            otherSectionKey: 0
        ]

        let unrelatedTask = RoutineTask(name: "Unrelated", scheduleMode: .oneOff)
        var tasks = [assignedTask, staleManualOrderTask, unrelatedTask]

        let update = HomeTaskLifecycleSupport.deleteCustomTaskSection(
            sectionID: deletedSectionID,
            tasks: &tasks
        )

        #expect(update == HomeDeleteCustomTaskSectionUpdate(
            sectionID: deletedSectionID,
            sectionKey: deletedSectionKey,
            taskIDs: [assignedTask.id, staleManualOrderTask.id]
        ))
        #expect(tasks[0].customTaskSectionID == nil)
        #expect(tasks[0].manualSectionOrders[deletedSectionKey] == nil)
        #expect(tasks[1].customTaskSectionID == otherSectionID)
        #expect(tasks[1].manualSectionOrders[deletedSectionKey] == nil)
        #expect(tasks[1].manualSectionOrders[otherSectionKey] == 0)
        #expect(tasks[2].customTaskSectionID == nil)
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

    @Test
    func planTaskAllowsDailyRunoutTracking() {
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            name: "Groceries",
            checklistItems: [RoutineChecklistItem(title: "Milk", intervalDays: 1)],
            scheduleMode: .recordDerivedFromChecklist,
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
    func markTaskDoneForChecklistRunoutCountsDoneAfterAllDueItemsAreCleared() {
        let calendar = makeTestCalendar()
        let breadID = UUID()
        let milkID = UUID()
        let createdAt = makeDate("2026-03-10T10:00:00Z")
        let referenceDate = makeDate("2026-03-18T12:00:00Z")
        let task = RoutineTask(
            name: "Groceries",
            checklistItems: [
                RoutineChecklistItem(id: breadID, title: "Bread", intervalDays: 3, createdAt: createdAt),
                RoutineChecklistItem(id: milkID, title: "Milk", intervalDays: 5, createdAt: createdAt)
            ],
            scheduleMode: .derivedFromChecklist
        )
        task.markChecklistItemsDone([breadID], doneAt: referenceDate, calendar: calendar)
        var tasks = [task]
        var doneStats = HomeDoneStats()

        let update = HomeTaskLifecycleSupport.markTaskDone(
            taskID: task.id,
            referenceDate: referenceDate,
            calendar: calendar,
            tasks: &tasks,
            doneStats: &doneStats
        )

        #expect(update == .checklist(HomeChecklistRunoutDoneUpdate(taskID: task.id, completionDate: referenceDate)))
        #expect(tasks[0].lastDone == referenceDate)
        #expect(tasks[0].dueChecklistItems(referenceDate: referenceDate, calendar: calendar).isEmpty)
        #expect(doneStats.totalCount == 1)
        #expect(doneStats.countsByTaskID[task.id] == 1)
    }
}

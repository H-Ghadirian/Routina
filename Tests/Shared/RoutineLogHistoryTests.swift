import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct RoutineLogHistoryTests {
    @Test
    func backfillMissingLastDoneLogs_insertsOnlyMissingEntries() throws {
        let context = makeInMemoryContext()
        let insertedCompletion = makeDate("2026-03-15T09:00:00Z")
        let duplicateCompletion = makeDate("2026-03-14T09:00:00Z")
        let insertedTask = makeTask(
            in: context,
            name: "Hydrate",
            interval: 1,
            lastDone: insertedCompletion,
            emoji: "💧"
        )
        let duplicateTask = makeTask(
            in: context,
            name: "Stretch",
            interval: 2,
            lastDone: duplicateCompletion,
            emoji: "🧘"
        )
        _ = makeTask(
            in: context,
            name: "Read",
            interval: 3,
            lastDone: nil,
            emoji: "📚"
        )
        _ = makeLog(in: context, task: duplicateTask, timestamp: duplicateCompletion)
        try context.save()

        let didInsert = try RoutineLogHistory.backfillMissingLastDoneLogs(in: context)
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(didInsert)
        #expect(logs.count == 2)
        #expect(logs.contains { $0.taskID == insertedTask.id && $0.timestamp == insertedCompletion })
        #expect(logs.contains { $0.taskID == duplicateTask.id && $0.timestamp == duplicateCompletion })
    }

    @Test
    func deduplicateRedundantSameDayLogs_keepsLatestLogPerTaskDayAndKind() throws {
        let context = makeInMemoryContext()
        let task = makeTask(
            in: context,
            name: "Read",
            interval: 1,
            lastDone: nil,
            emoji: "📚"
        )
        let otherTask = makeTask(
            in: context,
            name: "Walk",
            interval: 1,
            lastDone: nil,
            emoji: "🚶"
        )
        let older = makeDate("2026-04-26T13:50:00Z")
        let newer = makeDate("2026-04-26T13:50:30Z")
        let nextDay = makeDate("2026-04-27T12:00:00Z")
        _ = makeLog(in: context, task: task, timestamp: older)
        _ = makeLog(in: context, task: task, timestamp: newer)
        _ = makeLog(in: context, task: task, timestamp: nextDay)
        _ = makeLog(in: context, task: otherTask, timestamp: older)
        _ = makeLog(in: context, task: task, timestamp: older, kind: .canceled)
        try context.save()

        let didDelete = try RoutineLogHistory.deduplicateRedundantSameDayLogs(in: context)
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(didDelete)
        #expect(logs.count == 4)
        #expect(logs.contains { $0.taskID == task.id && $0.kind == .completed && $0.timestamp == newer })
        #expect(logs.contains { $0.taskID == task.id && $0.kind == .completed && $0.timestamp == nextDay })
        #expect(logs.contains { $0.taskID == otherTask.id && $0.kind == .completed && $0.timestamp == older })
        #expect(logs.contains { $0.taskID == task.id && $0.kind == .canceled && $0.timestamp == older })
    }

    @Test
    func deduplicateRedundantSameDayLogs_keepsFulfilledLogsFromDifferentSources() throws {
        let context = makeInMemoryContext()
        let target = makeTask(
            in: context,
            name: "Exercise routine",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let gym = makeTask(
            in: context,
            name: "Gym",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let hiking = makeTask(
            in: context,
            name: "Hiking",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let olderGymFulfillment = makeDate("2026-05-01T10:00:00Z")
        let newerGymFulfillment = makeDate("2026-05-01T10:05:00Z")
        let hikingFulfillment = makeDate("2026-05-01T11:00:00Z")
        context.insert(RoutineLog(
            timestamp: olderGymFulfillment,
            taskID: target.id,
            kind: .fulfilled,
            sourceTaskID: gym.id
        ))
        context.insert(RoutineLog(
            timestamp: newerGymFulfillment,
            taskID: target.id,
            kind: .fulfilled,
            sourceTaskID: gym.id
        ))
        context.insert(RoutineLog(
            timestamp: hikingFulfillment,
            taskID: target.id,
            kind: .fulfilled,
            sourceTaskID: hiking.id
        ))
        try context.save()

        let didDelete = try RoutineLogHistory.deduplicateRedundantSameDayLogs(
            in: context,
            calendar: makeTestCalendar()
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(didDelete)
        #expect(logs.count == 2)
        #expect(logs.contains {
            $0.taskID == target.id
                && $0.kind == .fulfilled
                && $0.sourceTaskID == gym.id
                && $0.timestamp == newerGymFulfillment
        })
        #expect(logs.contains {
            $0.taskID == target.id
                && $0.kind == .fulfilled
                && $0.sourceTaskID == hiking.id
                && $0.timestamp == hikingFulfillment
        })
    }

    @Test
    func advanceTask_fulfillsDoneWhenLinkedRoutine() throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let gym = makeTask(
            in: context,
            name: "Gym",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let exercise = makeTask(
            in: context,
            name: "Exercise routine",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        exercise.relationships = [
            RoutineTaskRelationship(targetTaskID: gym.id, kind: .doneWhen)
        ]
        try context.save()

        let completedAt = makeDate("2026-05-01T10:00:00Z")
        let result = try #require(
            try RoutineLogHistory.advanceTask(
                taskID: gym.id,
                completedAt: completedAt,
                context: context,
                calendar: calendar
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let gymLog = try #require(logs.first { $0.taskID == gym.id })
        let exerciseLog = try #require(logs.first { $0.taskID == exercise.id })

        #expect(result.result == .completedRoutine)
        #expect(gym.lastDone == completedAt)
        #expect(exercise.lastDone == completedAt)
        #expect(gymLog.kind == .completed)
        #expect(gymLog.sourceTaskID == nil)
        #expect(exerciseLog.kind == .fulfilled)
        #expect(exerciseLog.sourceTaskID == gym.id)
    }

    @Test
    func removeCompletion_keepsLinkedRoutineFulfilledWhenAnotherSourceCompletedSameDay() throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let gym = makeTask(
            in: context,
            name: "Gym",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let hiking = makeTask(
            in: context,
            name: "Hiking",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let exercise = makeTask(
            in: context,
            name: "Exercise routine",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        exercise.relationships = [
            RoutineTaskRelationship(targetTaskID: gym.id, kind: .doneWhen),
            RoutineTaskRelationship(targetTaskID: hiking.id, kind: .doneWhen)
        ]
        try context.save()

        let gymCompletedAt = makeDate("2026-05-01T10:00:00Z")
        let hikingCompletedAt = makeDate("2026-05-01T11:00:00Z")
        _ = try #require(
            try RoutineLogHistory.advanceTask(
                taskID: gym.id,
                completedAt: gymCompletedAt,
                context: context,
                calendar: calendar
            )
        )
        _ = try #require(
            try RoutineLogHistory.advanceTask(
                taskID: hiking.id,
                completedAt: hikingCompletedAt,
                context: context,
                calendar: calendar
            )
        )
        let fulfilledBeforeUndo = try context.fetch(FetchDescriptor<RoutineLog>())
            .filter { $0.taskID == exercise.id && $0.kind == .fulfilled }

        #expect(fulfilledBeforeUndo.count == 2)

        _ = try #require(
            try RoutineLogHistory.removeCompletion(
                taskID: gym.id,
                on: gymCompletedAt,
                context: context,
                calendar: calendar
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(exercise.lastDone == hikingCompletedAt)
        #expect(logs.contains {
            $0.taskID == exercise.id
                && $0.kind == .fulfilled
                && $0.sourceTaskID == hiking.id
                && $0.timestamp == hikingCompletedAt
        })
        #expect(!logs.contains {
            $0.taskID == exercise.id
                && $0.kind == .fulfilled
                && $0.sourceTaskID == gym.id
        })
    }

    @Test
    func advanceTask_withSequentialSteps_savesLogOnlyAfterFinalStep() throws {
        let context = makeInMemoryContext()
        let task = makeTask(
            in: context,
            name: "Laundry",
            interval: 7,
            lastDone: nil,
            emoji: "🧺",
            steps: [
                RoutineStep(title: "Wash"),
                RoutineStep(title: "Dry")
            ]
        )
        try context.save()

        let firstCompletion = makeDate("2026-03-15T09:00:00Z")
        let firstResult = try #require(
            try RoutineLogHistory.advanceTask(
                taskID: task.id,
                completedAt: firstCompletion,
                context: context
            )
        )

        #expect(firstResult.result == .advancedStep(completedSteps: 1, totalSteps: 2))
        #expect(firstResult.task.completedStepCount == 1)
        #expect(try context.fetch(FetchDescriptor<RoutineLog>()).isEmpty)

        let finalCompletion = makeDate("2026-03-15T09:05:00Z")
        let finalResult = try #require(
            try RoutineLogHistory.advanceTask(
                taskID: task.id,
                completedAt: finalCompletion,
                context: context
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(finalResult.result == .completedRoutine)
        #expect(finalResult.task.completedStepCount == 0)
        #expect(finalResult.task.sequenceStartedAt == nil)
        #expect(finalResult.task.lastDone == finalCompletion)
        #expect(finalResult.task.scheduleAnchor == finalCompletion)
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == task.id)
        #expect(logs.first?.timestamp == finalCompletion)
    }

    @Test
    func advanceTask_blocksOptionalChecklistUntilEveryItemIsChecked() throws {
        let context = makeInMemoryContext()
        let firstID = UUID()
        let secondID = UUID()
        let task = makeTask(
            in: context,
            name: "Pack bag",
            interval: 1,
            lastDone: nil,
            emoji: "🎒",
            checklistItems: [
                RoutineChecklistItem(id: firstID, title: "Laptop", intervalDays: 1),
                RoutineChecklistItem(id: secondID, title: "Charger", intervalDays: 1)
            ],
            scheduleMode: .fixedInterval
        )
        #expect(task.markOptionalChecklistItemCompleted(firstID))
        try context.save()

        let blockedResult = try RoutineLogHistory.advanceTask(
            taskID: task.id,
            completedAt: makeDate("2026-03-15T09:00:00Z"),
            context: context
        )
        #expect(blockedResult == nil)
        #expect(task.lastDone == nil)
        #expect(try context.fetch(FetchDescriptor<RoutineLog>()).isEmpty)

        #expect(task.markOptionalChecklistItemCompleted(secondID))
        try context.save()
        let allowedResult = try #require(
            try RoutineLogHistory.advanceTask(
                taskID: task.id,
                completedAt: makeDate("2026-03-15T09:05:00Z"),
                context: context
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(allowedResult.result == .completedRoutine)
        #expect(allowedResult.task.lastDone == makeDate("2026-03-15T09:05:00Z"))
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == task.id)
    }

    @Test
    func advanceTask_forBackfilledCompletionWithoutAnchorDoesNotStartCycleAtReferenceDate() throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-04-28T10:00:00Z")
        let completionDate = makeDate("2026-04-21T12:00:00Z")
        let task = makeTask(
            in: context,
            name: "Exercise",
            interval: 4,
            lastDone: nil,
            emoji: "🏃",
            scheduleAnchor: nil
        )
        try context.save()

        let result = try #require(
            try RoutineLogHistory.advanceTask(
                taskID: task.id,
                completedAt: completionDate,
                referenceDate: referenceDate,
                context: context,
                calendar: calendar
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(result.result == .completedRoutine)
        #expect(result.task.lastDone == completionDate)
        #expect(result.task.scheduleAnchor == completionDate)
        #expect(RoutineDateMath.overdueDays(for: result.task, referenceDate: referenceDate, calendar: calendar) == 3)
        #expect(logs.count == 1)
        #expect(logs.first?.timestamp == completionDate)
    }

    @Test
    func advanceChecklistItem_savesLogOnlyAfterFinalChecklistItem() throws {
        let context = makeInMemoryContext()
        let breadID = UUID()
        let milkID = UUID()
        let task = makeTask(
            in: context,
            name: "Groceries",
            interval: 7,
            lastDone: nil,
            emoji: "🛒",
            checklistItems: [
                RoutineChecklistItem(id: breadID, title: "Bread", intervalDays: 3),
                RoutineChecklistItem(id: milkID, title: "Milk", intervalDays: 5)
            ],
            scheduleMode: .fixedIntervalChecklist
        )
        try context.save()

        let firstCompletion = makeDate("2026-03-15T09:00:00Z")
        let firstResult = try #require(
            try RoutineLogHistory.advanceChecklistItem(
                taskID: task.id,
                itemID: breadID,
                completedAt: firstCompletion,
                context: context
            )
        )

        #expect(firstResult.result == .advancedChecklist(completedItems: 1, totalItems: 2))
        #expect(firstResult.task.completedChecklistItemCount == 1)
        #expect(try context.fetch(FetchDescriptor<RoutineLog>()).isEmpty)

        let finalCompletion = makeDate("2026-03-15T09:05:00Z")
        let finalResult = try #require(
            try RoutineLogHistory.advanceChecklistItem(
                taskID: task.id,
                itemID: milkID,
                completedAt: finalCompletion,
                context: context
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(finalResult.result == .completedRoutine)
        #expect(finalResult.task.completedChecklistItemCount == 0)
        #expect(finalResult.task.lastDone == finalCompletion)
        #expect(finalResult.task.scheduleAnchor == finalCompletion)
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == task.id)
        #expect(logs.first?.timestamp == finalCompletion)
    }

    @Test
    func markChecklistItemsDone_doesNotSaveCompletionLogWhenAnotherRunoutItemIsStillDue() throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let breadID = UUID()
        let milkID = UUID()
        let createdAt = makeDate("2026-03-10T10:00:00Z")
        let doneAt = makeDate("2026-03-18T12:00:00Z")
        let task = makeTask(
            in: context,
            name: "Groceries",
            interval: 1,
            lastDone: nil,
            emoji: nil,
            checklistItems: [
                RoutineChecklistItem(id: breadID, title: "Bread", intervalDays: 3, createdAt: createdAt),
                RoutineChecklistItem(id: milkID, title: "Milk", intervalDays: 5, createdAt: createdAt)
            ],
            scheduleMode: .derivedFromChecklist
        )
        try context.save()

        let result = try #require(
            try RoutineLogHistory.markChecklistItemsDone(
                taskID: task.id,
                itemIDs: [breadID],
                doneAt: doneAt,
                context: context,
                calendar: calendar
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(result.update == RoutineTask.ChecklistRunoutUpdate(updatedItemCount: 1, didCompleteRoutine: false))
        #expect(result.task.lastDone == nil)
        #expect(result.task.dueChecklistItems(referenceDate: doneAt, calendar: calendar).map(\.id) == [milkID])
        #expect(logs.isEmpty)
    }

    @Test
    func markChecklistItemsDone_savesCompletionLogAfterAllDueRunoutItemsReset() throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let breadID = UUID()
        let milkID = UUID()
        let createdAt = makeDate("2026-03-10T10:00:00Z")
        let doneAt = makeDate("2026-03-18T12:00:00Z")
        let task = makeTask(
            in: context,
            name: "Groceries",
            interval: 1,
            lastDone: nil,
            emoji: nil,
            checklistItems: [
                RoutineChecklistItem(id: breadID, title: "Bread", intervalDays: 3, createdAt: createdAt),
                RoutineChecklistItem(id: milkID, title: "Milk", intervalDays: 5, createdAt: createdAt)
            ],
            scheduleMode: .derivedFromChecklist
        )
        try context.save()

        let result = try #require(
            try RoutineLogHistory.markChecklistItemsDone(
                taskID: task.id,
                itemIDs: [breadID, milkID],
                doneAt: doneAt,
                context: context,
                calendar: calendar
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(result.update == RoutineTask.ChecklistRunoutUpdate(updatedItemCount: 2, didCompleteRoutine: true))
        #expect(result.task.lastDone == doneAt)
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == task.id)
        #expect(logs.first?.timestamp == doneAt)
    }

    @Test
    func undoChecklistItemRunoutDone_restoresPreviousItemAndRemovesCreatedCompletionLog() throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let breadID = UUID()
        let previousItemDoneAt = makeDate("2026-03-12T10:00:00Z")
        let previousTaskDoneAt = makeDate("2026-03-11T09:00:00Z")
        let doneAt = makeDate("2026-03-18T12:00:00Z")
        let task = makeTask(
            in: context,
            name: "Groceries",
            interval: 1,
            lastDone: previousTaskDoneAt,
            emoji: nil,
            checklistItems: [
                RoutineChecklistItem(
                    id: breadID,
                    title: "Bread",
                    intervalDays: 3,
                    lastPurchasedAt: previousItemDoneAt,
                    createdAt: makeDate("2026-03-10T10:00:00Z")
                )
            ],
            scheduleMode: .derivedFromChecklist,
            scheduleAnchor: previousTaskDoneAt
        )
        _ = makeLog(in: context, task: task, timestamp: previousTaskDoneAt)
        try context.save()

        _ = try #require(
            try RoutineLogHistory.markChecklistItemsDone(
                taskID: task.id,
                itemIDs: [breadID],
                doneAt: doneAt,
                context: context,
                calendar: calendar
            )
        )
        let undoResult = try #require(
            try RoutineLogHistory.undoChecklistItemRunoutDone(
                taskID: task.id,
                itemID: breadID,
                undoneAt: doneAt,
                context: context,
                calendar: calendar
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let item = undoResult.task.checklistItems.first { $0.id == breadID }

        #expect(undoResult.update == RoutineTask.ChecklistRunoutUndoUpdate(restoredItemCount: 1, removedCompletionAt: doneAt))
        #expect(item?.lastPurchasedAt == previousItemDoneAt)
        #expect(undoResult.task.lastDone == previousTaskDoneAt)
        #expect(undoResult.task.scheduleAnchor == previousTaskDoneAt)
        #expect(logs.count == 1)
        #expect(logs.first?.timestamp == previousTaskDoneAt)
    }

    @Test
    func undoChecklistItemRunoutDone_removesCompletionLogWhenUncheckedItemWasNotLastChecked() throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let breadID = UUID()
        let milkID = UUID()
        let previousTaskDoneAt = makeDate("2026-03-11T09:00:00Z")
        let breadDoneAt = makeDate("2026-03-18T12:00:00Z")
        let milkDoneAt = makeDate("2026-03-18T12:05:00Z")
        let task = makeTask(
            in: context,
            name: "Groceries",
            interval: 1,
            lastDone: previousTaskDoneAt,
            emoji: nil,
            checklistItems: [
                RoutineChecklistItem(
                    id: breadID,
                    title: "Bread",
                    intervalDays: 3,
                    createdAt: makeDate("2026-03-10T10:00:00Z")
                ),
                RoutineChecklistItem(
                    id: milkID,
                    title: "Milk",
                    intervalDays: 5,
                    createdAt: makeDate("2026-03-10T10:00:00Z")
                )
            ],
            scheduleMode: .derivedFromChecklist,
            scheduleAnchor: previousTaskDoneAt
        )
        _ = makeLog(in: context, task: task, timestamp: previousTaskDoneAt)
        try context.save()

        _ = try #require(
            try RoutineLogHistory.markChecklistItemsDone(
                taskID: task.id,
                itemIDs: [breadID],
                doneAt: breadDoneAt,
                context: context,
                calendar: calendar
            )
        )
        _ = try #require(
            try RoutineLogHistory.markChecklistItemsDone(
                taskID: task.id,
                itemIDs: [milkID],
                doneAt: milkDoneAt,
                context: context,
                calendar: calendar
            )
        )
        let undoResult = try #require(
            try RoutineLogHistory.undoChecklistItemRunoutDone(
                taskID: task.id,
                itemID: breadID,
                undoneAt: milkDoneAt,
                context: context,
                calendar: calendar
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(undoResult.update == RoutineTask.ChecklistRunoutUndoUpdate(restoredItemCount: 1, removedCompletionAt: milkDoneAt))
        #expect(undoResult.task.checklistItems.first(where: { $0.id == breadID })?.lastPurchasedAt == nil)
        #expect(undoResult.task.checklistItems.first(where: { $0.id == milkID })?.lastPurchasedAt == milkDoneAt)
        #expect(undoResult.task.lastDone == previousTaskDoneAt)
        #expect(logs.count == 1)
        #expect(logs.first?.timestamp == previousTaskDoneAt)
    }

    @Test
    func removeCompletion_forPausedTaskWithoutRemainingLogs_restoresPausedAnchor() throws {
        let context = makeInMemoryContext()
        let completionDate = makeDate("2026-03-15T09:00:00Z")
        let pausedAt = makeDate("2026-03-16T12:00:00Z")
        let task = makeTask(
            in: context,
            name: "Walk",
            interval: 2,
            lastDone: completionDate,
            emoji: "🚶",
            steps: [RoutineStep(title: "Shoes on")],
            scheduleAnchor: completionDate,
            pausedAt: pausedAt
        )
        _ = makeLog(in: context, task: task, timestamp: completionDate)
        task.completedStepCount = 1
        task.sequenceStartedAt = makeDate("2026-03-15T08:50:00Z")
        try context.save()

        let updatedTask = try #require(
            try RoutineLogHistory.removeCompletion(
                taskID: task.id,
                on: completionDate,
                context: context
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(updatedTask.lastDone == nil)
        #expect(updatedTask.scheduleAnchor == pausedAt)
        #expect(updatedTask.completedStepCount == 0)
        #expect(updatedTask.sequenceStartedAt == nil)
        #expect(logs.isEmpty)
    }

    @Test
    func markExactTimedOccurrenceMissed_recordsMissedLogWithoutCompletion() throws {
        let context = makeInMemoryContext()
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let missedDate = makeDate("2026-05-07T18:30:00Z")
        let task = makeTask(
            in: context,
            name: "Class",
            interval: 1,
            lastDone: nil,
            emoji: "📚",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-05-01T10:00:00Z")
        )

        let updatedTask = try #require(
            try RoutineLogHistory.markExactTimedOccurrenceMissed(
                taskID: task.id,
                missedAt: missedDate,
                context: context,
                calendar: calendar
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(updatedTask.lastDone == nil)
        #expect(logs.count == 1)
        #expect(logs.first?.kind == .missed)
        #expect(logs.first?.timestamp == missedDate)
    }

    @Test
    func advanceTask_replacesMissedLogWhenUserConfirmsDone() throws {
        let context = makeInMemoryContext()
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let missedDate = makeDate("2026-05-07T18:30:00Z")
        let task = makeTask(
            in: context,
            name: "Class",
            interval: 1,
            lastDone: nil,
            emoji: "📚",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-05-01T10:00:00Z")
        )
        _ = makeLog(in: context, task: task, timestamp: missedDate, kind: .missed)
        try context.save()

        let result = try #require(
            try RoutineLogHistory.advanceTask(
                taskID: task.id,
                completedAt: missedDate,
                referenceDate: makeDate("2026-05-08T10:00:00Z"),
                context: context,
                calendar: calendar
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(result.result == .completedRoutine)
        #expect(result.task.lastDone == missedDate)
        #expect(logs.count == 1)
        #expect(logs.first?.kind == .completed)
        #expect(logs.first?.timestamp == missedDate)
    }

    @Test
    func markExactTimedOccurrenceCanceled_recordsCanceledLogWithoutCancelingRoutine() throws {
        let context = makeInMemoryContext()
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let canceledDate = makeDate("2026-05-07T18:30:00Z")
        let task = makeTask(
            in: context,
            name: "Class",
            interval: 1,
            lastDone: nil,
            emoji: "📚",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-05-01T10:00:00Z")
        )

        let updatedTask = try #require(
            try RoutineLogHistory.markExactTimedOccurrenceCanceled(
                taskID: task.id,
                canceledAt: canceledDate,
                context: context,
                calendar: calendar
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(updatedTask.lastDone == nil)
        #expect(updatedTask.canceledAt == nil)
        #expect(logs.count == 1)
        #expect(logs.first?.kind == .canceled)
        #expect(logs.first?.timestamp == canceledDate)
    }

    @Test
    func markExactTimedOccurrenceCanceled_replacesMissedResolutionForSameOccurrence() throws {
        let context = makeInMemoryContext()
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let occurrenceDate = makeDate("2026-05-07T18:30:00Z")
        let task = makeTask(
            in: context,
            name: "Class",
            interval: 1,
            lastDone: nil,
            emoji: "📚",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-05-01T10:00:00Z")
        )
        _ = makeLog(in: context, task: task, timestamp: occurrenceDate, kind: .missed)
        try context.save()

        _ = try #require(
            try RoutineLogHistory.markExactTimedOccurrenceCanceled(
                taskID: task.id,
                canceledAt: occurrenceDate,
                context: context,
                calendar: calendar
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(logs.count == 1)
        #expect(logs.first?.kind == .canceled)
        #expect(logs.first?.timestamp == occurrenceDate)
    }

    @Test
    func advanceTask_replacesCanceledOccurrenceLogWhenUserConfirmsDone() throws {
        let context = makeInMemoryContext()
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let occurrenceDate = makeDate("2026-05-07T18:30:00Z")
        let task = makeTask(
            in: context,
            name: "Class",
            interval: 1,
            lastDone: nil,
            emoji: "📚",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-05-01T10:00:00Z")
        )
        _ = makeLog(in: context, task: task, timestamp: occurrenceDate, kind: .canceled)
        try context.save()

        let result = try #require(
            try RoutineLogHistory.advanceTask(
                taskID: task.id,
                completedAt: occurrenceDate,
                referenceDate: makeDate("2026-05-08T10:00:00Z"),
                context: context,
                calendar: calendar
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(result.result == .completedRoutine)
        #expect(result.task.lastDone == occurrenceDate)
        #expect(result.task.canceledAt == nil)
        #expect(logs.count == 1)
        #expect(logs.first?.kind == .completed)
        #expect(logs.first?.timestamp == occurrenceDate)
    }

    @Test
    func cancelTask_marksTodoCanceledWithoutRecordingCompletion() throws {
        let context = makeInMemoryContext()
        let task = makeTask(
            in: context,
            name: "Buy milk",
            interval: 1,
            lastDone: nil,
            emoji: "🥛",
            scheduleMode: .oneOff
        )
        try context.save()

        let canceledAt = makeDate("2026-03-15T09:00:00Z")
        let canceledTask = try #require(
            try RoutineLogHistory.cancelTask(
                taskID: task.id,
                canceledAt: canceledAt,
                context: context
            )
        )
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(canceledTask.lastDone == nil)
        #expect(canceledTask.canceledAt == canceledAt)
        #expect(canceledTask.isCanceledOneOff)
        #expect(logs.count == 1)
        #expect(logs.first?.kind == .canceled)
        #expect(logs.first?.timestamp == canceledAt)
    }
}

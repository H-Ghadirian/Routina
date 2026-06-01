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

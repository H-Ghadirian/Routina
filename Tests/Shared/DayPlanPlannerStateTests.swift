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
struct DayPlanPlannerStateTests {
    @Test
    func editVisibleFutureBlockKeepsVisibleWeekAnchored() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let selectedDate = try #require(date("2026-05-03T12:00:00Z"))
        let blockDate = try #require(date("2026-05-07T12:00:00Z"))
        let block = dayPlanBlock(on: blockDate, calendar: calendar)
        let planner = DayPlanPlannerState(selectedDate: selectedDate)
        planner.weekBlocksByDayKey = [
            block.dayKey: [block],
        ]

        let visibleDatesBefore = planner.weekDates(calendar: calendar)

        planner.edit(block, on: blockDate, calendar: calendar, context: context)

        #expect(planner.selectedDate == blockDate)
        #expect(planner.weekDates(calendar: calendar) == visibleDatesBefore)
        #expect(planner.selectedBlockID == block.id)
    }

    @Test
    func resizeVisibleFutureBlockKeepsVisibleWeekAnchored() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let selectedDate = try #require(date("2026-05-03T12:00:00Z"))
        let blockDate = try #require(date("2026-05-07T12:00:00Z"))
        let block = dayPlanBlock(on: blockDate, calendar: calendar)
        let planner = DayPlanPlannerState(selectedDate: selectedDate)
        planner.weekBlocksByDayKey = [
            block.dayKey: [block],
        ]

        let visibleDatesBefore = planner.weekDates(calendar: calendar)
        let didResize = planner.resizeBlock(
            block.id,
            on: blockDate,
            startMinute: block.startMinute,
            durationMinutes: block.durationMinutes + 30,
            calendar: calendar,
            context: context
        )

        #expect(didResize)
        #expect(planner.selectedDate == blockDate)
        #expect(planner.weekDates(calendar: calendar) == visibleDatesBefore)
        #expect(planner.selectedBlock?.durationMinutes == block.durationMinutes + 30)
    }

    @Test
    func persistsBlocksInSwiftData() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let blockDate = try #require(date("2026-05-07T12:00:00Z"))
        let block = dayPlanBlock(on: blockDate, calendar: calendar)

        DayPlanStorage.saveBlocks([block], forDayKey: block.dayKey, context: context)

        let loaded = DayPlanStorage.loadBlocks(forDayKey: block.dayKey, context: context)
        #expect(loaded == [block])

        var descriptor = FetchDescriptor<DayPlanBlockRecord>()
        descriptor.predicate = #Predicate<DayPlanBlockRecord> { record in
            record.id == block.id
        }
        let records = try context.fetch(descriptor)
        #expect(records.count == 1)
    }

    @Test
    func timelineTasksIncludeMissedAndCanceledActivityNotAlreadyPlanned() throws {
        let calendar = gregorianCalendar
        let activityDate = try #require(date("2026-05-07T12:00:00Z"))
        let completedAt = try #require(date("2026-05-07T08:00:00Z"))
        let missedAt = try #require(date("2026-05-07T09:00:00Z"))
        let canceledAt = try #require(date("2026-05-07T10:00:00Z"))
        let completedTaskID = UUID()
        let missedTaskID = UUID()
        let canceledTaskID = UUID()
        let completedTask = RoutineTask(
            id: completedTaskID,
            name: "Already planned",
            scheduleMode: .fixedInterval
        )
        let missedTask = RoutineTask(
            id: missedTaskID,
            name: "Missed call",
            scheduleMode: .fixedInterval
        )
        let canceledTask = RoutineTask(
            id: canceledTaskID,
            name: "Canceled errand",
            scheduleMode: .oneOff,
            canceledAt: canceledAt
        )
        let logs = [
            RoutineLog(
                timestamp: completedAt,
                taskID: completedTaskID,
                kind: .completed
            ),
            RoutineLog(
                timestamp: missedAt,
                taskID: missedTaskID,
                kind: .missed
            ),
            RoutineLog(
                timestamp: canceledAt,
                taskID: canceledTaskID,
                kind: .canceled
            ),
        ]
        let plannedBlock = DayPlanBlock(
            taskID: completedTaskID,
            dayKey: DayPlanStorage.dayKey(for: activityDate, calendar: calendar),
            startMinute: 8 * 60,
            durationMinutes: 60,
            titleSnapshot: "Already planned"
        )

        let tasks = DayPlanTimelineTasks.tasks(
            on: activityDate,
            from: [completedTask, missedTask, canceledTask],
            logs: logs,
            plannedBlocks: [plannedBlock],
            calendar: calendar
        )

        #expect(tasks.map(\.id) == [canceledTaskID, missedTaskID])
    }

    @Test
    func timelineActivityBlocksUseLatestActivityAndExcludePlannedTasks() throws {
        let calendar = gregorianCalendar
        let activityDate = try #require(date("2026-05-07T12:00:00Z"))
        let plannedAt = try #require(date("2026-05-07T08:00:00Z"))
        let olderActivityAt = try #require(date("2026-05-07T09:00:00Z"))
        let latestActivityAt = try #require(date("2026-05-07T09:45:00Z"))
        let canceledAt = try #require(date("2026-05-07T10:15:00Z"))
        let plannedTaskID = UUID()
        let activeTaskID = UUID()
        let canceledTaskID = UUID()
        let plannedTask = RoutineTask(
            id: plannedTaskID,
            name: "Already planned",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 60
        )
        let activeTask = RoutineTask(
            id: activeTaskID,
            name: "Review inbox",
            emoji: "📬",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 45
        )
        let canceledTask = RoutineTask(
            id: canceledTaskID,
            name: "Canceled errand",
            scheduleMode: .oneOff,
            canceledAt: canceledAt,
            estimatedDurationMinutes: 35
        )
        let logs = [
            RoutineLog(
                timestamp: plannedAt,
                taskID: plannedTaskID,
                kind: .completed,
                actualDurationMinutes: 20
            ),
            RoutineLog(
                timestamp: olderActivityAt,
                taskID: activeTaskID,
                kind: .missed,
                actualDurationMinutes: 25
            ),
            RoutineLog(
                timestamp: latestActivityAt,
                taskID: activeTaskID,
                kind: .completed,
                actualDurationMinutes: 40
            ),
        ]
        let plannedBlock = DayPlanBlock(
            taskID: plannedTaskID,
            dayKey: DayPlanStorage.dayKey(for: activityDate, calendar: calendar),
            startMinute: 8 * 60,
            durationMinutes: 60,
            titleSnapshot: "Already planned"
        )

        let activityBlocks = DayPlanTimelineTasks.activityBlocks(
            on: activityDate,
            from: [plannedTask, activeTask, canceledTask],
            logs: logs,
            plannedBlocks: [plannedBlock],
            calendar: calendar
        )

        #expect(activityBlocks.map(\.block.taskID) == [activeTaskID, canceledTaskID])
        #expect(activityBlocks.map(\.kind) == [.completed, .canceled])
        #expect(activityBlocks.first?.block.startMinute == 9 * 60 + 45)
        #expect(activityBlocks.first?.block.durationMinutes == 40)
        #expect(activityBlocks.last?.block.durationMinutes == 35)
    }

    @Test
    func movingTimelineActivityUpdatesLogAndTaskCompletionDate() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let originalTimestamp = try #require(date("2026-05-07T09:45:00Z"))
        let targetDate = try #require(date("2026-05-08T12:00:00Z"))
        let task = RoutineTask(
            name: "Review inbox",
            scheduleMode: .fixedInterval,
            lastDone: originalTimestamp,
            estimatedDurationMinutes: 40
        )
        let log = RoutineLog(
            timestamp: originalTimestamp,
            taskID: task.id,
            kind: .completed,
            actualDurationMinutes: 40
        )
        context.insert(task)
        context.insert(log)
        try context.save()

        let activity = try #require(
            DayPlanTimelineTasks.activityBlocks(
                on: originalTimestamp,
                from: [task],
                logs: [log],
                plannedBlocks: [],
                calendar: calendar
            )
            .first
        )

        let didMove = DayPlanTimelineTasks.moveActivity(
            activity,
            to: targetDate,
            startMinute: 11 * 60 + 15,
            tasks: [task],
            logs: [log],
            context: context,
            calendar: calendar
        )

        let expectedTimestamp = try #require(date("2026-05-08T11:15:00Z"))
        #expect(didMove)
        #expect(log.timestamp == expectedTimestamp)
        #expect(task.lastDone == expectedTimestamp)
    }

    @Test
    func movingOlderTimelineCompletionDoesNotLowerLatestTaskCompletionDate() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let originalTimestamp = try #require(date("2026-05-07T09:45:00Z"))
        let latestTimestamp = try #require(date("2026-05-09T14:00:00Z"))
        let targetDate = try #require(date("2026-05-08T12:00:00Z"))
        let task = RoutineTask(
            name: "Review inbox",
            scheduleMode: .fixedInterval,
            lastDone: latestTimestamp,
            estimatedDurationMinutes: 40
        )
        let log = RoutineLog(
            timestamp: originalTimestamp,
            taskID: task.id,
            kind: .completed,
            actualDurationMinutes: 40
        )
        context.insert(task)
        context.insert(log)
        try context.save()

        let activity = try #require(
            DayPlanTimelineTasks.activityBlocks(
                on: originalTimestamp,
                from: [task],
                logs: [log],
                plannedBlocks: [],
                calendar: calendar
            )
            .first
        )

        let didMove = DayPlanTimelineTasks.moveActivity(
            activity,
            to: targetDate,
            startMinute: 11 * 60 + 15,
            tasks: [task],
            logs: [log],
            context: context,
            calendar: calendar
        )

        let expectedMovedTimestamp = try #require(date("2026-05-08T11:15:00Z"))
        #expect(didMove)
        #expect(log.timestamp == expectedMovedTimestamp)
        #expect(task.lastDone == latestTimestamp)
    }

    @Test
    func movingLegacyTimelineActivityCreatesMatchingLog() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let originalTimestamp = try #require(date("2026-05-07T09:45:00Z"))
        let targetDate = try #require(date("2026-05-08T12:00:00Z"))
        let task = RoutineTask(
            name: "Legacy completion",
            scheduleMode: .fixedInterval,
            lastDone: originalTimestamp,
            estimatedDurationMinutes: 40
        )
        context.insert(task)
        try context.save()

        let activity = try #require(
            DayPlanTimelineTasks.activityBlocks(
                on: originalTimestamp,
                from: [task],
                logs: [],
                plannedBlocks: [],
                calendar: calendar
            )
            .first
        )

        let didMove = DayPlanTimelineTasks.moveActivity(
            activity,
            to: targetDate,
            startMinute: 11 * 60 + 15,
            tasks: [task],
            logs: [],
            context: context,
            calendar: calendar
        )

        let expectedTimestamp = try #require(date("2026-05-08T11:15:00Z"))
        let taskID = task.id
        let persistedLogs = try context.fetch(
            FetchDescriptor<RoutineLog>(
                predicate: #Predicate<RoutineLog> { log in
                    log.taskID == taskID
                }
            )
        )
        #expect(didMove)
        #expect(task.lastDone == expectedTimestamp)
        #expect(persistedLogs.count == 1)
        #expect(persistedLogs.first?.kind == .completed)
        #expect(persistedLogs.first?.timestamp == expectedTimestamp)
    }
}

private let gregorianCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func date(_ string: String) -> Date? {
    ISO8601DateFormatter().date(from: string)
}

private func dayPlanBlock(on date: Date, calendar: Calendar) -> DayPlanBlock {
    DayPlanBlock(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
        taskID: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
        dayKey: DayPlanStorage.dayKey(for: date, calendar: calendar),
        startMinute: 18 * 60 + 30,
        durationMinutes: 90,
        titleSnapshot: "Group session",
        emojiSnapshot: "✨",
        createdAt: date,
        updatedAt: date
    )
}

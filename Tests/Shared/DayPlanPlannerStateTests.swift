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

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
struct TaskPauseUntilTests {
    private let calendar = Self.makeCalendar()

    @Test
    func finitePauseIsActiveOnlyBeforeItsExpiry() throws {
        let pausedAt = try #require(Self.date("2026-08-09T09:00:00Z"))
        let pauseUntil = try #require(Self.date("2026-08-10T10:30:00Z"))
        let task = RoutineTask(
            name: "Prepare slides",
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 1),
            pausedAt: pausedAt,
            pauseUntil: pauseUntil
        )

        #expect(task.isPaused(referenceDate: pausedAt.addingTimeInterval(60)))
        #expect(task.isArchived(referenceDate: pausedAt.addingTimeInterval(60), calendar: calendar))
        #expect(!task.isPaused(referenceDate: pauseUntil))
        #expect(!task.isArchived(referenceDate: pauseUntil, calendar: calendar))
    }

    @Test
    func calendarSchedulingHidesPausedTaskThenAllowsItAfterExpiry() throws {
        let pausedAt = try #require(Self.date("2026-08-09T09:00:00Z"))
        let pauseUntil = try #require(Self.date("2026-08-10T10:30:00Z"))
        let pausedDay = try #require(Self.date("2026-08-10T00:00:00Z"))
        let activeDay = try #require(Self.date("2026-08-11T00:00:00Z"))
        let task = RoutineTask(
            name: "Prepare slides",
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 1),
            pausedAt: pausedAt,
            pauseUntil: pauseUntil
        )
        let pausedBlock = DayPlanBlock(
            taskID: task.id,
            dayKey: DayPlanStorage.dayKey(for: pausedDay, calendar: calendar),
            startMinute: 9 * 60,
            durationMinutes: 30,
            titleSnapshot: "Prepare slides"
        )
        let activeBlock = DayPlanBlock(
            taskID: task.id,
            dayKey: DayPlanStorage.dayKey(for: activeDay, calendar: calendar),
            startMinute: 9 * 60,
            durationMinutes: 30,
            titleSnapshot: "Prepare slides"
        )

        #expect(
            DayPlanTaskSorting.availableTasks(
                from: [task],
                referenceDate: pausedDay,
                calendar: calendar
            ).isEmpty
        )
        #expect(
            DayPlanVisibleBlocks.blocks(
                [pausedBlock],
                tasks: [task],
                logs: [],
                calendar: calendar,
                referenceDate: pausedDay
            ).isEmpty
        )

        #expect(
            DayPlanTaskSorting.availableTasks(
                from: [task],
                referenceDate: activeDay,
                calendar: calendar
            ).map(\.id) == [task.id]
        )
        #expect(
            DayPlanVisibleBlocks.blocks(
                [activeBlock],
                tasks: [task],
                logs: [],
                calendar: calendar,
                referenceDate: activeDay
            ) == [activeBlock]
        )
    }

    @Test
    func indefinitePauseRemainsAbsentFromCalendarScheduling() throws {
        let pausedAt = try #require(Self.date("2026-08-09T09:00:00Z"))
        let future = try #require(Self.date("2026-09-09T09:00:00Z"))
        let task = RoutineTask(
            name: "Someday task",
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 1),
            pausedAt: pausedAt
        )

        #expect(task.isPaused(referenceDate: future))
        #expect(
            DayPlanTaskSorting.availableTasks(
                from: [task],
                referenceDate: future,
                calendar: calendar
            ).isEmpty
        )
    }

    private static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private static func date(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}

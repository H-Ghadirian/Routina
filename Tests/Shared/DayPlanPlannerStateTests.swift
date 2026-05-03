import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct DayPlanPlannerStateTests {
    @Test
    func editVisibleFutureBlockKeepsVisibleWeekAnchored() throws {
        let calendar = gregorianCalendar
        let selectedDate = try #require(date("2026-05-03T12:00:00Z"))
        let blockDate = try #require(date("2026-05-07T12:00:00Z"))
        let block = dayPlanBlock(on: blockDate, calendar: calendar)
        let planner = DayPlanPlannerState(selectedDate: selectedDate)
        planner.weekBlocksByDayKey = [
            block.dayKey: [block],
        ]

        let visibleDatesBefore = planner.weekDates(calendar: calendar)

        planner.edit(block, on: blockDate, calendar: calendar)

        #expect(planner.selectedDate == blockDate)
        #expect(planner.weekDates(calendar: calendar) == visibleDatesBefore)
        #expect(planner.selectedBlockID == block.id)
    }

    @Test
    func resizeVisibleFutureBlockKeepsVisibleWeekAnchored() throws {
        let calendar = gregorianCalendar
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
            calendar: calendar
        )

        #expect(didResize)
        #expect(planner.selectedDate == blockDate)
        #expect(planner.weekDates(calendar: calendar) == visibleDatesBefore)
        #expect(planner.selectedBlock?.durationMinutes == block.durationMinutes + 30)
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

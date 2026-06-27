import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct DayPlanDayTaskListPresentationTests {
    @Test
    func itemsShowAllDayTasksBeforeTimedBlocks() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))
        let dayKey = DayPlanStorage.dayKey(for: day, calendar: calendar)
        let allDayTaskID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let morningTaskID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let afternoonTaskID = try #require(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let morningBlockID = try #require(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let afternoonBlockID = try #require(UUID(uuidString: "55555555-5555-5555-5555-555555555555"))
        let allDayEnd = try #require(calendar.date(byAdding: .day, value: 1, to: day))

        let allDayBlock = DayPlanAllDayBlock(
            id: allDayTaskID,
            taskID: allDayTaskID,
            eventID: nil,
            title: "All day review",
            emoji: nil,
            startDate: day,
            endDate: allDayEnd,
            isLegacyDateOnlyCalendarTask: false,
            isEvent: false
        )
        let afternoonBlock = DayPlanBlock(
            id: afternoonBlockID,
            taskID: afternoonTaskID,
            dayKey: dayKey,
            startMinute: 13 * 60,
            durationMinutes: 45,
            titleSnapshot: "Afternoon block"
        )
        let morningBlock = DayPlanBlock(
            id: morningBlockID,
            taskID: morningTaskID,
            dayKey: dayKey,
            startMinute: 9 * 60,
            durationMinutes: 30,
            titleSnapshot: "Morning block"
        )

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [afternoonBlock, morningBlock],
            allDayBlocks: [allDayBlock],
            calendar: calendar
        )

        #expect(items.map(\.title) == ["All day review", "Morning block", "Afternoon block"])
        #expect(items.map(\.placement) == [
            .allDay,
            .timed(startMinute: 9 * 60, durationMinutes: 30),
            .timed(startMinute: 13 * 60, durationMinutes: 45),
        ])
        #expect(items.map(\.blockID) == [nil, morningBlockID, afternoonBlockID])
    }

    @Test
    func itemsIncludeOnlyTaskBackedAllDayBlocksIntersectingSelectedDate() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))
        let previousDay = try #require(calendar.date(byAdding: .day, value: -1, to: day))
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let twoDaysLater = try #require(calendar.date(byAdding: .day, value: 2, to: day))
        let taskID = try #require(UUID(uuidString: "66666666-6666-6666-6666-666666666666"))
        let eventID = try #require(UUID(uuidString: "77777777-7777-7777-7777-777777777777"))
        let otherTaskID = try #require(UUID(uuidString: "88888888-8888-8888-8888-888888888888"))

        let spanningTask = DayPlanAllDayBlock(
            id: taskID,
            taskID: taskID,
            eventID: nil,
            title: "Spanning task",
            emoji: nil,
            startDate: previousDay,
            endDate: nextDay,
            isLegacyDateOnlyCalendarTask: false,
            isEvent: false
        )
        let event = DayPlanAllDayBlock(
            id: eventID,
            taskID: nil,
            eventID: eventID,
            title: "Calendar event",
            emoji: nil,
            startDate: day,
            endDate: nextDay,
            isLegacyDateOnlyCalendarTask: false,
            isEvent: true
        )
        let otherDayTask = DayPlanAllDayBlock(
            id: otherTaskID,
            taskID: otherTaskID,
            eventID: nil,
            title: "Other day task",
            emoji: nil,
            startDate: nextDay,
            endDate: twoDaysLater,
            isLegacyDateOnlyCalendarTask: false,
            isEvent: false
        )

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [],
            allDayBlocks: [event, otherDayTask, spanningTask],
            calendar: calendar
        )

        #expect(items.map(\.title) == ["Spanning task"])
        #expect(items.map(\.taskID) == [taskID])
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func testDate(
        year: Int,
        month: Int,
        day: Int,
        calendar: Calendar
    ) -> Date? {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day
        )
        .date
    }
}

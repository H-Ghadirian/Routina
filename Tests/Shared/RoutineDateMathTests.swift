import Foundation
import Testing
#if os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct RoutineDateMathTests {
    @Test
    func elapsedDaysSinceLastDone_usesCalendarDayBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let lastDone = makeDate("2026-03-14T15:00:00Z")
        let referenceDate = makeDate("2026-03-15T10:00:00Z")

        let elapsedDays = RoutineDateMath.elapsedDaysSinceLastDone(
            from: lastDone,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(elapsedDays == 1)
    }

    @Test
    func elapsedDaysSinceLastDone_returnsZeroWhenNoCompletionExists() {
        let elapsedDays = RoutineDateMath.elapsedDaysSinceLastDone(
            from: nil,
            referenceDate: makeDate("2026-03-15T10:00:00Z")
        )

        #expect(elapsedDays == 0)
    }

    @Test
    func dueDate_prefersScheduleAnchorWhenPresent() {
        let task = RoutineTask(
            interval: 7,
            lastDone: makeDate("2026-03-01T10:00:00Z"),
            scheduleAnchor: makeDate("2026-03-04T10:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-10T10:00:00Z")
        )

        #expect(dueDate == makeDate("2026-03-11T10:00:00Z"))
    }

    @Test
    func dueDate_usesEarliestChecklistItemForChecklistDrivenRoutine() {
        let task = RoutineTask(
            checklistItems: [
                RoutineChecklistItem(
                    title: "Bread",
                    intervalDays: 3,
                    lastPurchasedAt: makeDate("2026-03-18T10:00:00Z"),
                    createdAt: makeDate("2026-03-15T10:00:00Z")
                ),
                RoutineChecklistItem(
                    title: "Milk",
                    intervalDays: 5,
                    lastPurchasedAt: makeDate("2026-03-17T10:00:00Z"),
                    createdAt: makeDate("2026-03-15T10:00:00Z")
                )
            ]
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-20T10:00:00Z")
        )

        #expect(dueDate == makeDate("2026-03-21T10:00:00Z"))
    }

    @Test
    func resumedScheduleAnchor_shiftsByPauseDuration() {
        let task = RoutineTask(
            interval: 7,
            scheduleAnchor: makeDate("2026-03-01T10:00:00Z"),
            pausedAt: makeDate("2026-03-05T10:00:00Z")
        )

        let resumedAnchor = RoutineDateMath.resumedScheduleAnchor(
            for: task,
            resumedAt: makeDate("2026-03-08T10:00:00Z")
        )

        #expect(resumedAnchor == makeDate("2026-03-04T10:00:00Z"))
    }

    @Test
    func dueDate_dailyTimeSchedule_usesSameDayWhenTimeIsStillAhead() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 20, minute: 0)),
            scheduleAnchor: makeDate("2026-03-20T10:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-20T10:00:00Z"),
            calendar: calendar
        )

        #expect(dueDate == makeDate("2026-03-20T20:00:00Z"))
    }

    @Test
    func dueDate_weeklySchedule_usesConfiguredWeekday() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            recurrenceRule: .weekly(on: 6),
            scheduleAnchor: makeDate("2026-03-17T10:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-17T10:00:00Z"),
            calendar: calendar
        )

        #expect(dueDate == makeDate("2026-03-20T00:00:00Z"))
    }

    @Test
    func dueDate_monthlySchedule_clampsToLastDayOfShortMonth() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            recurrenceRule: .monthly(on: 31),
            scheduleAnchor: makeDate("2026-04-01T10:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-04-01T10:00:00Z"),
            calendar: calendar
        )

        #expect(dueDate == makeDate("2026-04-30T00:00:00Z"))
    }

    // Regression: monthly routine created mid-day on the scheduled day of month
    // must not skip to the following month.
    @Test
    func dueDate_monthlySchedule_returnsSameDayWhenCreatedOnScheduledDay() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // Created at 10 AM on the 20th; rule is "every 20th of the month".
        let task = RoutineTask(
            recurrenceRule: .monthly(on: 20),
            scheduleAnchor: makeDate("2026-03-20T10:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-20T10:00:00Z"),
            calendar: calendar
        )

        #expect(dueDate == makeDate("2026-03-20T00:00:00Z"))
    }

    // Regression: weekly routine created mid-day on the scheduled weekday
    // must not skip to the following week.
    @Test
    func dueDate_weeklySchedule_returnsSameDayWhenCreatedOnScheduledWeekday() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // March 20, 2026 is a Friday (weekday 6).
        // Created at 10 AM on Friday; rule is "every Friday".
        let task = RoutineTask(
            recurrenceRule: .weekly(on: 6),
            scheduleAnchor: makeDate("2026-03-20T10:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-20T10:00:00Z"),
            calendar: calendar
        )

        #expect(dueDate == makeDate("2026-03-20T00:00:00Z"))
    }

    @Test
    func canMarkDone_monthlySchedule_returnsTrueOnCreationDayWhenDayMatches() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // Routine created at 10 AM on March 20 with rule "every 20th".
        let task = RoutineTask(
            recurrenceRule: .monthly(on: 20),
            scheduleAnchor: makeDate("2026-03-20T10:00:00Z")
        )

        let canDone = RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-20T10:00:00Z"),
            calendar: calendar
        )

        #expect(canDone == true)
    }

    @Test
    func canMarkDone_monthlySchedule_returnsFalseBeforeScheduledDay() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // Routine created March 1; rule is "every 20th". Should not be markable on March 5.
        let task = RoutineTask(
            recurrenceRule: .monthly(on: 20),
            scheduleAnchor: makeDate("2026-03-01T10:00:00Z")
        )

        let canDone = RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-05T10:00:00Z"),
            calendar: calendar
        )

        #expect(canDone == false)
    }

    @Test
    func canMarkDone_weeklySchedule_returnsTrueOnCreationDayWhenWeekdayMatches() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // March 20, 2026 is a Friday (weekday 6). Created at 10 AM.
        let task = RoutineTask(
            recurrenceRule: .weekly(on: 6),
            scheduleAnchor: makeDate("2026-03-20T10:00:00Z")
        )

        let canDone = RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-20T10:00:00Z"),
            calendar: calendar
        )

        #expect(canDone == true)
    }

    @Test
    func canMarkDone_weeklySchedule_returnsFalseBeforeScheduledWeekday() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // Created Tuesday March 17; rule is "every Friday". Should not be markable on Wednesday March 18.
        let task = RoutineTask(
            recurrenceRule: .weekly(on: 6),
            scheduleAnchor: makeDate("2026-03-17T10:00:00Z")
        )

        let canDone = RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-18T10:00:00Z"),
            calendar: calendar
        )

        #expect(canDone == false)
    }

    @Test
    func canMarkDone_monthlySchedule_returnsTrueForPastOccurrenceBeforeScheduleAnchor() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // Task created on March 28; rule is "every 26th". The March 26 occurrence predates the
        // schedule anchor, but the user should be able to mark it done for that past date.
        let task = RoutineTask(
            recurrenceRule: .monthly(on: 26),
            scheduleAnchor: makeDate("2026-03-28T09:00:00Z")
        )

        let canDone = RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-26T12:00:00Z"),
            calendar: calendar
        )

        #expect(canDone == true)
    }

    @Test
    func canMarkDone_monthlySchedule_returnsFalseForNonScheduledPastDay() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // Task created on March 28; rule is "every 26th". March 25 is not a valid occurrence.
        let task = RoutineTask(
            recurrenceRule: .monthly(on: 26),
            scheduleAnchor: makeDate("2026-03-28T09:00:00Z")
        )

        let canDone = RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-25T12:00:00Z"),
            calendar: calendar
        )

        #expect(canDone == false)
    }

    @Test
    func canMarkDone_monthlySchedule_returnsTrueWhenScheduledDayAlreadyPassedThisMonth() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // Task created on March 29; rule is "every 26th". Today is March 29.
        // The March 26 occurrence already passed, but a new task should still
        // be markable — its first due date is March 26 (overdue).
        let task = RoutineTask(
            recurrenceRule: .monthly(on: 26),
            scheduleAnchor: makeDate("2026-03-29T09:00:00Z")
        )

        let canDone = RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-29T10:00:00Z"),
            calendar: calendar
        )

        #expect(canDone == true)
    }

    @Test
    func dueDate_monthlySchedule_returnsCurrentMonthOccurrenceForNewTask() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // Created on March 29; day-of-month = 26. Due date should be March 26
        // (the current month's occurrence), not April 26.
        let task = RoutineTask(
            recurrenceRule: .monthly(on: 26),
            scheduleAnchor: makeDate("2026-03-29T09:00:00Z")
        )

        let due = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-29T10:00:00Z"),
            calendar: calendar
        )

        let expected = makeDate("2026-03-26T00:00:00Z")
        #expect(due == expected)
    }
}

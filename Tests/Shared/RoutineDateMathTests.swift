import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
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
    func oneOffTodoWithoutDeadlineOrAvailabilityHasNoDueDistance() {
        let task = RoutineTask(scheduleMode: .oneOff)
        let referenceDate = makeDate("2026-03-20T10:00:00Z")

        #expect(RoutineDateMath.daysUntilDue(for: task, referenceDate: referenceDate) == Int.max)
        #expect(RoutineDateMath.overdueDays(for: task, referenceDate: referenceDate) == 0)
    }

    @Test
    func oneOffTodoAvailabilityWindowWithoutDeadlineHasNoDueDistance() {
        let task = RoutineTask(
            availabilityStartDate: makeDate("2026-06-08T00:00:00Z"),
            availabilityEndDate: makeDate("2027-06-12T00:00:00Z"),
            scheduleMode: .oneOff
        )
        let referenceDate = makeDate("2026-06-27T10:00:00Z")

        #expect(RoutineDateMath.daysUntilDue(for: task, referenceDate: referenceDate) == Int.max)
        #expect(RoutineDateMath.overdueDays(for: task, referenceDate: referenceDate) == 0)
        #expect(RoutineDateMath.dueDate(for: task, referenceDate: referenceDate) == referenceDate)
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
    func softIntervalRoutine_neverBecomesOverdue() {
        let task = RoutineTask(
            scheduleMode: .softInterval,
            recurrenceRule: .interval(days: 180),
            lastDone: makeDate("2026-01-01T10:00:00Z"),
            scheduleAnchor: makeDate("2026-01-01T10:00:00Z")
        )

        let daysUntilDue = RoutineDateMath.daysUntilDue(
            for: task,
            referenceDate: makeDate("2026-10-01T10:00:00Z")
        )

        #expect(daysUntilDue == Int.max)
        #expect(RoutineDateMath.overdueDays(for: task, referenceDate: makeDate("2026-10-01T10:00:00Z")) == 0)
    }

    @Test
    func softIntervalThreshold_detectsWhenEnoughTimeHasPassed() {
        let task = RoutineTask(
            scheduleMode: .softInterval,
            recurrenceRule: .interval(days: 180),
            lastDone: makeDate("2026-01-01T10:00:00Z"),
            scheduleAnchor: makeDate("2026-01-01T10:00:00Z")
        )

        #expect(
            !RoutineDateMath.hasPassedSoftIntervalThreshold(
                for: task,
                referenceDate: makeDate("2026-05-01T10:00:00Z")
            )
        )
        #expect(
            RoutineDateMath.hasPassedSoftIntervalThreshold(
                for: task,
                referenceDate: makeDate("2026-07-01T10:00:00Z")
            )
        )
    }

    @Test
    func timedSoftIntervalThreshold_waitsForAvailabilityTime() {
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            scheduleMode: .softInterval,
            recurrenceRule: .interval(days: 7, at: RoutineTimeOfDay(hour: 20, minute: 0)),
            lastDone: makeDate("2026-01-01T10:00:00Z"),
            scheduleAnchor: makeDate("2026-01-01T10:00:00Z")
        )

        #expect(
            !RoutineDateMath.hasPassedSoftIntervalThreshold(
                for: task,
                referenceDate: makeDate("2026-01-08T19:59:00Z"),
                calendar: calendar
            )
        )
        #expect(
            RoutineDateMath.hasPassedSoftIntervalThreshold(
                for: task,
                referenceDate: makeDate("2026-01-08T20:00:00Z"),
                calendar: calendar
            )
        )
    }

    @Test
    func softCalendarThreshold_usesNextCalendarOccurrence() {
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            scheduleMode: .softInterval,
            recurrenceRule: .weekly(on: 2, at: RoutineTimeOfDay(hour: 20, minute: 0)),
            lastDone: makeDate("2026-01-05T10:00:00Z"),
            scheduleAnchor: makeDate("2026-01-05T10:00:00Z")
        )

        #expect(
            !RoutineDateMath.hasPassedSoftIntervalThreshold(
                for: task,
                referenceDate: makeDate("2026-01-12T19:59:00Z"),
                calendar: calendar
            )
        )
        #expect(
            RoutineDateMath.hasPassedSoftIntervalThreshold(
                for: task,
                referenceDate: makeDate("2026-01-12T20:00:00Z"),
                calendar: calendar
            )
        )
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
    func dailyTimeRange_allowsCompletionOnlyInsideWindowAndMissesAfterEnd() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        let task = RoutineTask(
            recurrenceRule: .daily(in: timeRange),
            scheduleAnchor: makeDate("2026-03-20T06:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-20T08:00:00Z"),
            calendar: calendar
        )

        #expect(dueDate == makeDate("2026-03-20T07:00:00Z"))
        #expect(!RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-20T06:30:00Z"),
            calendar: calendar
        ))
        #expect(RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-20T08:00:00Z"),
            calendar: calendar
        ))
        #expect(!RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-20T10:30:00Z"),
            calendar: calendar
        ))
        #expect(
            RoutineDateMath.missedExactTimedOccurrenceDate(
                for: task,
                referenceDate: makeDate("2026-03-20T10:30:00Z"),
                calendar: calendar
            ) == makeDate("2026-03-20T07:00:00Z")
        )
        #expect(
            RoutineDateMath.upcomingDueDate(
                for: task,
                referenceDate: makeDate("2026-03-20T10:30:00Z"),
                calendar: calendar
            ) == makeDate("2026-03-21T07:00:00Z")
        )
    }

    @Test
    func intervalWithExactTime_usesIntervalDayAndTimeAvailability() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            recurrenceRule: .interval(days: 2, at: RoutineTimeOfDay(hour: 20, minute: 0)),
            scheduleAnchor: makeDate("2026-03-01T10:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-03T19:00:00Z"),
            calendar: calendar
        )

        #expect(dueDate == makeDate("2026-03-03T20:00:00Z"))
        #expect(!RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-03T19:59:00Z"),
            calendar: calendar
        ))
        #expect(RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-03T20:00:00Z"),
            calendar: calendar
        ))
        #expect(!RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-04T08:00:00Z"),
            calendar: calendar
        ))
        #expect(
            RoutineDateMath.upcomingDueDate(
                for: task,
                referenceDate: makeDate("2026-03-04T08:00:00Z"),
                calendar: calendar
            ) == makeDate("2026-03-05T20:00:00Z")
        )
    }

    @Test
    func intervalWithTimeRange_allowsCompletionOnlyInsideWindow() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        let task = RoutineTask(
            recurrenceRule: .interval(days: 3, timeRange: timeRange),
            scheduleAnchor: makeDate("2026-03-01T10:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-04T08:00:00Z"),
            calendar: calendar
        )

        #expect(dueDate == makeDate("2026-03-04T07:00:00Z"))
        #expect(!RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-04T06:59:00Z"),
            calendar: calendar
        ))
        #expect(RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-04T08:00:00Z"),
            calendar: calendar
        ))
        #expect(!RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-04T10:00:00Z"),
            calendar: calendar
        ))
        #expect(
            RoutineDateMath.upcomingDueDate(
                for: task,
                referenceDate: makeDate("2026-03-04T10:00:00Z"),
                calendar: calendar
            ) == makeDate("2026-03-07T07:00:00Z")
        )
    }

    @Test
    func completionDisplayDayForOvernightRangeUsesStartDay() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 21, minute: 0),
            end: RoutineTimeOfDay(hour: 3, minute: 0)
        )
        let task = RoutineTask(
            recurrenceRule: .daily(in: timeRange),
            scheduleAnchor: makeDate("2026-03-20T00:00:00Z")
        )

        let displayDay = RoutineDateMath.completionDisplayDay(
            for: task,
            completionDate: makeDate("2026-03-21T01:30:00Z"),
            calendar: calendar
        )

        #expect(displayDay == makeDate("2026-03-20T00:00:00Z"))
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
    func dueDate_weeklyScheduleWithMultipleWeekdays_usesNextSelectedWeekday() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            recurrenceRule: .weekly(on: [2, 4, 6]),
            scheduleAnchor: makeDate("2026-03-17T10:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-17T10:00:00Z"),
            calendar: calendar
        )

        #expect(dueDate == makeDate("2026-03-18T00:00:00Z"))
    }

    @Test
    func dueDate_weeklySchedule_withExactTime_usesConfiguredWeekdayAndTime() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            recurrenceRule: .weekly(on: 6, at: RoutineTimeOfDay(hour: 18, minute: 45)),
            scheduleAnchor: makeDate("2026-03-17T10:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-17T10:00:00Z"),
            calendar: calendar
        )

        #expect(dueDate == makeDate("2026-03-20T18:45:00Z"))
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

    @Test
    func dueDate_monthlyScheduleWithMultipleDays_usesNextSelectedMonthDay() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            recurrenceRule: .monthly(on: [1, 15, 31]),
            scheduleAnchor: makeDate("2026-04-16T10:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-04-16T10:00:00Z"),
            calendar: calendar
        )

        #expect(dueDate == makeDate("2026-04-30T00:00:00Z"))
    }

    @Test
    func dueDate_monthlySchedule_withExactTime_clampsAndUsesConfiguredTime() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            recurrenceRule: .monthly(on: 31, at: RoutineTimeOfDay(hour: 18, minute: 45)),
            scheduleAnchor: makeDate("2026-04-01T10:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-04-01T10:00:00Z"),
            calendar: calendar
        )

        #expect(dueDate == makeDate("2026-04-30T18:45:00Z"))
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
    func dueDate_weeklySchedule_createdAfterScheduledWeekday_returnsNextWeekOccurrence() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // April 19, 2026 is a Sunday. A new "every Monday at 17:00" routine should
        // first be due on April 20, not the previous Monday in the same week.
        let task = RoutineTask(
            recurrenceRule: .weekly(on: 2, at: RoutineTimeOfDay(hour: 17, minute: 0)),
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-04-19T10:00:00Z"),
            calendar: calendar
        )

        #expect(dueDate == makeDate("2026-04-20T17:00:00Z"))
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
    func canMarkDone_weeklySchedule_withExactTime_returnsTrueAfterScheduledTime() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            recurrenceRule: .weekly(on: 2, at: RoutineTimeOfDay(hour: 17, minute: 0)),
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z")
        )

        let canDone = RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-04-20T18:00:00Z"),
            calendar: calendar
        )

        #expect(canDone == true)
    }

    @Test
    func exactTimedOccurrenceBecomesMissedAfterScheduledDayPasses() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z")
        )
        let referenceDate = makeDate("2026-04-24T10:00:00Z")
        let missedDate = makeDate("2026-04-23T18:30:00Z")
        let nextDueDate = makeDate("2026-04-30T18:30:00Z")

        #expect(
            RoutineDateMath.missedExactTimedOccurrenceDate(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ) == missedDate
        )
        #expect(RoutineDateMath.upcomingDueDate(for: task, referenceDate: referenceDate, calendar: calendar) == nextDueDate)
        #expect(RoutineDateMath.daysUntilDue(for: task, referenceDate: referenceDate, calendar: calendar) == 6)
        #expect(RoutineDateMath.overdueDays(for: task, referenceDate: referenceDate, calendar: calendar) == 0)
        #expect(!RoutineDateMath.canMarkDone(for: task, referenceDate: referenceDate, calendar: calendar))
        #expect(
            RoutineDateMath.completionTargetDate(
                for: task,
                selectedDay: referenceDate,
                referenceDate: referenceDate,
                calendar: calendar
            ) == nil
        )
        #expect(
            RoutineDateMath.completionTargetDate(
                for: task,
                selectedDay: missedDate,
                referenceDate: referenceDate,
                calendar: calendar
            ) == missedDate
        )
    }

    @Test
    func intervalRoutineWithoutTimeDueTomorrowDoesNotBecomeMissed() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            recurrenceRule: .interval(days: 2),
            scheduleAnchor: makeDate("2026-06-26T10:00:00Z"),
            createdAt: makeDate("2026-06-26T10:00:00Z")
        )
        let referenceDate = makeDate("2026-06-27T10:00:00Z")

        #expect(
            RoutineDateMath.missedExactTimedOccurrenceDate(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ) == nil
        )
        #expect(RoutineDateMath.upcomingDueDate(for: task, referenceDate: referenceDate, calendar: calendar) == makeDate("2026-06-28T10:00:00Z"))
        #expect(RoutineDateMath.daysUntilDue(for: task, referenceDate: referenceDate, calendar: calendar) == 1)
    }

    @Test
    func exactTimedUpcomingDueAdvancesPastConsecutiveMissedOccurrences() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            recurrenceRule: .weekly(
                on: 5,
                timeRange: RoutineTimeRange(
                    start: RoutineTimeOfDay(hour: 18, minute: 30),
                    end: RoutineTimeOfDay(hour: 20, minute: 0)
                )
            ),
            scheduleAnchor: makeDate("2026-06-12T10:00:00Z"),
            createdAt: makeDate("2026-06-12T10:00:00Z")
        )
        let referenceDate = makeDate("2026-06-27T10:00:00Z")
        let firstMissed = makeDate("2026-06-18T18:30:00Z")
        let secondMissed = makeDate("2026-06-25T18:30:00Z")

        #expect(
            RoutineDateMath.missedExactTimedOccurrenceDates(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ) == [firstMissed, secondMissed]
        )
        #expect(
            RoutineDateMath.upcomingDueDate(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ) == makeDate("2026-07-02T18:30:00Z")
        )
        #expect(
            RoutineDateMath.unresolvedMissedExactTimedOccurrenceDate(
                for: task,
                referenceDate: referenceDate,
                logs: [RoutineLog(timestamp: firstMissed, taskID: task.id, kind: .missed)],
                calendar: calendar
            ) == secondMissed
        )
    }

    @Test
    func selectedPastExactTimedOccurrenceCanBeMarkedDoneWithEarlierUnresolvedMisses() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            recurrenceRule: .weekly(
                on: 5,
                timeRange: RoutineTimeRange(
                    start: RoutineTimeOfDay(hour: 18, minute: 30),
                    end: RoutineTimeOfDay(hour: 20, minute: 0)
                )
            ),
            scheduleAnchor: makeDate("2026-06-12T10:00:00Z"),
            createdAt: makeDate("2026-06-12T10:00:00Z")
        )
        let selectedOccurrence = makeDate("2026-07-02T18:30:00Z")
        let referenceDate = makeDate("2026-07-07T15:00:00Z")

        #expect(RoutineDateMath.missedExactTimedOccurrenceDates(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        ) == [
            makeDate("2026-06-18T18:30:00Z"),
            makeDate("2026-06-25T18:30:00Z"),
            selectedOccurrence
        ])
        #expect(RoutineDateMath.canMarkSelectedExactTimedOccurrenceDone(
            for: task,
            completionDate: selectedOccurrence,
            referenceDate: referenceDate,
            logs: [],
            calendar: calendar
        ))
    }

    @Test
    func canceledExactTimedOccurrenceAcknowledgesMissedAssumption() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z")
        )
        let missedDate = makeDate("2026-04-23T18:30:00Z")
        let logs = [
            RoutineLog(timestamp: missedDate, taskID: task.id, kind: .canceled)
        ]

        #expect(
            RoutineDateMath.unresolvedMissedExactTimedOccurrenceDate(
                for: task,
                referenceDate: makeDate("2026-04-24T10:00:00Z"),
                logs: logs,
                calendar: calendar
            ) == nil
        )
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
    func canMarkDone_monthlySchedule_returnsFalseWhenScheduledDayAlreadyPassedAtCreation() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // Task created on March 29; rule is "every 26th". A new task should not
        // immediately become overdue for March 26, so it is not markable yet.
        let task = RoutineTask(
            recurrenceRule: .monthly(on: 26),
            scheduleAnchor: makeDate("2026-03-29T09:00:00Z")
        )

        let canDone = RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: makeDate("2026-03-29T10:00:00Z"),
            calendar: calendar
        )

        #expect(canDone == false)
    }

    @Test
    func dueDate_monthlySchedule_createdAfterScheduledDay_returnsNextMonthOccurrence() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // Created on March 29; day-of-month = 26. The first due date should be the
        // next valid occurrence after creation, not the already-passed March 26.
        let task = RoutineTask(
            recurrenceRule: .monthly(on: 26),
            scheduleAnchor: makeDate("2026-03-29T09:00:00Z")
        )

        let due = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-29T10:00:00Z"),
            calendar: calendar
        )

        let expected = makeDate("2026-04-26T00:00:00Z")
        #expect(due == expected)
    }
}

import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TaskDetailCalendarGridSupportTests {
    @Test
    func orderedWeekdaySymbolsStartsAtCalendarFirstWeekday() {
        var calendar = gregorianUTC
        calendar.firstWeekday = 2

        #expect(calendar.orderedShortStandaloneWeekdaySymbols.prefix(3) == ["Mon", "Tue", "Wed"])
    }

    @Test
    func daysInMonthGridPadsLeadingAndTrailingEmptyDays() {
        var calendar = gregorianUTC
        calendar.firstWeekday = 2
        let monthStart = date(year: 2026, month: 5, day: 1, calendar: calendar)
        let days = calendar.daysInMonthGrid(for: monthStart)

        #expect(days.count == 35)
        #expect(days.prefix(4).allSatisfy { $0 == nil })
        #expect(components(of: days[4]!, calendar: calendar) == DateComponents(year: 2026, month: 5, day: 1))
        #expect(components(of: days[34]!, calendar: calendar) == DateComponents(year: 2026, month: 5, day: 31))
    }

    @Test
    func todayButtonShowsWhenSelectedTodayIsNotVisibleInDisplayedMonth() {
        let calendar = gregorianUTC
        let today = date(year: 2026, month: 7, day: 7, calendar: calendar)
        let displayedMonthStart = date(year: 2026, month: 8, day: 1, calendar: calendar)

        #expect(TaskDetailCalendarTodayButtonVisibility.showsButton(
            selectedDate: today,
            displayedMonthStart: displayedMonthStart,
            referenceDate: today,
            calendar: calendar
        ))
    }

    @Test
    func todayButtonHidesWhenSelectedTodayIsVisibleInDisplayedMonth() {
        let calendar = gregorianUTC
        let today = date(year: 2026, month: 7, day: 7, calendar: calendar)
        let displayedMonthStart = date(year: 2026, month: 7, day: 1, calendar: calendar)

        #expect(!TaskDetailCalendarTodayButtonVisibility.showsButton(
            selectedDate: today,
            displayedMonthStart: displayedMonthStart,
            referenceDate: today,
            calendar: calendar
        ))
    }

    @Test
    func todayButtonShowsWhenAnotherDateIsSelected() {
        let calendar = gregorianUTC
        let today = date(year: 2026, month: 7, day: 7, calendar: calendar)
        let selectedDate = date(year: 2026, month: 7, day: 8, calendar: calendar)
        let displayedMonthStart = date(year: 2026, month: 7, day: 1, calendar: calendar)

        #expect(TaskDetailCalendarTodayButtonVisibility.showsButton(
            selectedDate: selectedDate,
            displayedMonthStart: displayedMonthStart,
            referenceDate: today,
            calendar: calendar
        ))
    }

    @Test
    func overdueRangeStopsAfterLateCompletion() {
        let calendar = gregorianUTC
        let dueDate = date(year: 2026, month: 6, day: 25, calendar: calendar)
        let completionDate = date(year: 2026, month: 6, day: 26, calendar: calendar)
        let referenceDate = date(year: 2026, month: 6, day: 29, calendar: calendar)

        let dueDay = TaskDetailCalendarPresentation.dayPresentation(
            day: dueDate,
            doneDates: [completionDate],
            assumedDates: [],
            dueDate: dueDate,
            createdAt: nil,
            pausedAt: nil,
            isOrangeUrgencyToday: false,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let completionDay = TaskDetailCalendarPresentation.dayPresentation(
            day: completionDate,
            doneDates: [completionDate],
            assumedDates: [],
            dueDate: dueDate,
            createdAt: nil,
            pausedAt: nil,
            isOrangeUrgencyToday: false,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let dayAfterCompletion = TaskDetailCalendarPresentation.dayPresentation(
            day: date(year: 2026, month: 6, day: 27, calendar: calendar),
            doneDates: [completionDate],
            assumedDates: [],
            dueDate: dueDate,
            createdAt: nil,
            pausedAt: nil,
            isOrangeUrgencyToday: false,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(dueDay.isDueToTodayRangeDate)
        #expect(completionDay.isDoneDate)
        #expect(!dayAfterCompletion.isDueToTodayRangeDate)
    }

    @Test
    func overdueLegendHidesWhenTaskWasDoneOnDueDate() {
        let calendar = gregorianUTC
        let dueDate = date(year: 2026, month: 6, day: 25, calendar: calendar)
        let referenceDate = date(year: 2026, month: 6, day: 29, calendar: calendar)

        #expect(!TaskDetailCalendarPresentation.hasVisibleOverdueRange(
            dueDate: dueDate,
            doneDates: [dueDate],
            missedDates: [],
            canceledDates: [],
            referenceDate: referenceDate,
            calendar: calendar
        ))
    }

    @Test
    func oneOffOverdueRangeDoesNotBeginAfterEarlyCompletion() {
        let calendar = gregorianUTC
        let completionDate = date(year: 2026, month: 6, day: 24, calendar: calendar)
        let dueDate = date(year: 2026, month: 6, day: 25, calendar: calendar)
        let referenceDate = date(year: 2026, month: 6, day: 29, calendar: calendar)

        let dueDay = TaskDetailCalendarPresentation.dayPresentation(
            day: dueDate,
            doneDates: [completionDate],
            assumedDates: [],
            dueDate: dueDate,
            createdAt: nil,
            pausedAt: nil,
            isOrangeUrgencyToday: false,
            resolvesOverdueBeforeDueDate: true,
            referenceDate: referenceDate,
            calendar: calendar
        )
        #expect(!dueDay.isDueToTodayRangeDate)
        #expect(!TaskDetailCalendarPresentation.hasVisibleOverdueRange(
            dueDate: dueDate,
            doneDates: [completionDate],
            missedDates: [],
            canceledDates: [],
            resolvesBeforeDueDate: true,
            referenceDate: referenceDate,
            calendar: calendar
        ))
    }
}

private let gregorianUTC: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

private func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
    DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: year, month: month, day: day).date!
}

private func components(of date: Date, calendar: Calendar) -> DateComponents {
    calendar.dateComponents([.year, .month, .day], from: date)
}

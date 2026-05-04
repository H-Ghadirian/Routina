import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TaskDetailCalendarNavigationTests {
    @Test
    func previousMonthReturnsStartOfPreviousMonth() {
        let calendar = gregorianUTC
        let result = TaskDetailCalendarNavigation.previousMonth(
            from: date(year: 2026, month: 5, day: 18, calendar: calendar),
            calendar: calendar
        )

        #expect(components(of: result, calendar: calendar) == DateComponents(year: 2026, month: 4, day: 1))
    }

    @Test
    func nextMonthReturnsStartOfNextMonthAcrossYearBoundary() {
        let calendar = gregorianUTC
        let result = TaskDetailCalendarNavigation.nextMonth(
            from: date(year: 2026, month: 12, day: 31, calendar: calendar),
            calendar: calendar
        )

        #expect(components(of: result, calendar: calendar) == DateComponents(year: 2027, month: 1, day: 1))
    }
}

private let gregorianUTC: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

private func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
    DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: year, month: month, day: day).date!
}

private func components(of date: Date, calendar: Calendar) -> DateComponents {
    calendar.dateComponents([.year, .month, .day], from: date)
}

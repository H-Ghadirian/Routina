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

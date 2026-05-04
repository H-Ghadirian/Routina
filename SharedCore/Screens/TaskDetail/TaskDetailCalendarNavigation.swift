import Foundation

enum TaskDetailCalendarNavigation {
    static func previousMonth(from date: Date, calendar: Calendar = .current) -> Date {
        month(from: date, offset: -1, calendar: calendar)
    }

    static func nextMonth(from date: Date, calendar: Calendar = .current) -> Date {
        month(from: date, offset: 1, calendar: calendar)
    }

    private static func month(from date: Date, offset: Int, calendar: Calendar) -> Date {
        let monthStart = calendar.startOfMonth(for: date)
        return calendar.date(byAdding: .month, value: offset, to: monthStart) ?? monthStart
    }
}

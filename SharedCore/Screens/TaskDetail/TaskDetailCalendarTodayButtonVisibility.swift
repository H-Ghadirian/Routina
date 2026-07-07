import Foundation

enum TaskDetailCalendarTodayButtonVisibility {
    static func showsButton(
        selectedDate: Date,
        displayedMonthStart: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        !calendar.isDate(selectedDate, inSameDayAs: referenceDate)
            || !isTodayVisible(
                displayedMonthStart: displayedMonthStart,
                referenceDate: referenceDate,
                calendar: calendar
            )
    }

    private static func isTodayVisible(
        displayedMonthStart: Date,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        calendar.daysInMonthGrid(for: displayedMonthStart).contains { day in
            guard let day else { return false }
            return calendar.isDate(day, inSameDayAs: referenceDate)
        }
    }
}

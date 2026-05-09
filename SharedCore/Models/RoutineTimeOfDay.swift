import Foundation

struct RoutineTimeOfDay: Codable, Equatable, Hashable, Sendable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    var minutesFromStartOfDay: Int {
        hour * 60 + minute
    }

    static let defaultValue = RoutineTimeOfDay(
        hour: NotificationPreferences.defaultReminderHour,
        minute: NotificationPreferences.defaultReminderMinute
    )

    static func from(
        _ date: Date,
        calendar: Calendar = .current
    ) -> RoutineTimeOfDay {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return RoutineTimeOfDay(
            hour: components.hour ?? defaultValue.hour,
            minute: components.minute ?? defaultValue.minute
        )
    }

    func date(
        on date: Date,
        calendar: Calendar = .current
    ) -> Date {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let components = DateComponents(
            year: dayComponents.year,
            month: dayComponents.month,
            day: dayComponents.day,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: components) ?? date
    }

    func formatted(calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date(on: Date(), calendar: calendar))
    }

    func addingMinutes(_ minutes: Int) -> RoutineTimeOfDay {
        let dayMinutes = 24 * 60
        let total = (minutesFromStartOfDay + minutes) % dayMinutes
        let normalized = total >= 0 ? total : total + dayMinutes
        return RoutineTimeOfDay(hour: normalized / 60, minute: normalized % 60)
    }
}

struct RoutineTimeRange: Codable, Equatable, Hashable, Sendable {
    var start: RoutineTimeOfDay
    var end: RoutineTimeOfDay

    init(start: RoutineTimeOfDay, end: RoutineTimeOfDay) {
        self.start = start
        self.end = start.minutesFromStartOfDay == end.minutesFromStartOfDay
            ? start.addingMinutes(60)
            : end
    }

    static let defaultValue = RoutineTimeRange(
        start: RoutineTimeOfDay(hour: 7, minute: 0),
        end: RoutineTimeOfDay(hour: 10, minute: 0)
    )

    var isOvernight: Bool {
        end.minutesFromStartOfDay <= start.minutesFromStartOfDay
    }

    func startDate(
        on date: Date,
        calendar: Calendar = .current
    ) -> Date {
        start.date(on: date, calendar: calendar)
    }

    func endDate(
        on date: Date,
        calendar: Calendar = .current
    ) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let baseEnd = end.date(on: startOfDay, calendar: calendar)
        guard isOvernight else { return baseEnd }
        return calendar.date(byAdding: .day, value: 1, to: baseEnd) ?? baseEnd
    }

    func contains(
        _ date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let minutes = RoutineTimeOfDay.from(date, calendar: calendar).minutesFromStartOfDay
        let startMinutes = start.minutesFromStartOfDay
        let endMinutes = end.minutesFromStartOfDay

        if isOvernight {
            return minutes >= startMinutes || minutes < endMinutes
        }
        return minutes >= startMinutes && minutes < endMinutes
    }

    func formatted(calendar: Calendar = .current) -> String {
        "\(start.formatted(calendar: calendar)) to \(end.formatted(calendar: calendar))"
    }
}

enum PersianDateDisplay {
    static func supplementaryText(for date: Date, enabled: Bool) -> String? {
        guard enabled else { return nil }
        return rightToLeft(date.formatted(persianDateStyle))
    }

    static func appendingSupplementaryDate(
        to text: String,
        for date: Date,
        enabled: Bool
    ) -> String {
        guard let supplementaryText = supplementaryText(for: date, enabled: enabled) else {
            return text
        }
        return "\(text) (\(supplementaryText))"
    }

    private static let persianDateStyle: Date.FormatStyle = {
        var calendar = Calendar(identifier: .persian)
        calendar.locale = Locale(identifier: "fa_IR")
        var style = Date.FormatStyle()
            .day()
            .month(.wide)
            .year()
        style.calendar = calendar
        style.locale = Locale(identifier: "fa_IR")
        return style
    }()

    private static func rightToLeft(_ text: String) -> String {
        "\u{2067}\(text)\u{2069}"
    }
}

import Foundation

struct RoutineTimeOfDay: Codable, Equatable, Hashable, Sendable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
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

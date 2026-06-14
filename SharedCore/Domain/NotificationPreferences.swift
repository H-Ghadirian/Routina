import Foundation

enum NotificationPreferences {
    static let reminderHourDefaultsKey = "appSettingNotificationHour"
    static let reminderMinuteDefaultsKey = "appSettingNotificationMinute"
    static let defaultReminderHour = 20
    static let defaultReminderMinute = 0

    static var notificationsEnabled: Bool {
        SharedDefaults.app[.appSettingNotificationsEnabled]
    }

    static func reminderTimeDate(
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Date {
        reminderDate(on: now, calendar: calendar)
    }

    static func storeReminderTime(
        _ date: Date,
        calendar: Calendar = .current
    ) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        SharedDefaults.app.set(components.hour ?? defaultReminderHour, forKey: reminderHourDefaultsKey)
        SharedDefaults.app.set(components.minute ?? defaultReminderMinute, forKey: reminderMinuteDefaultsKey)
    }

    static func reminderDate(
        on date: Date,
        calendar: Calendar = .current
    ) -> Date {
        reminderDate(
            on: date,
            hour: reminderHour(),
            minute: reminderMinute(),
            calendar: calendar
        )
    }

    static func defaultReminderDate(
        on date: Date,
        calendar: Calendar = .current
    ) -> Date {
        reminderDate(
            on: date,
            hour: defaultReminderHour,
            minute: defaultReminderMinute,
            calendar: calendar
        )
    }

    private static func reminderDate(
        on date: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar
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

    static func nextReminderDate(
        after date: Date,
        calendar: Calendar = .current
    ) -> Date {
        let sameDayReminder = reminderDate(on: date, calendar: calendar)
        if sameDayReminder > date {
            return sameDayReminder
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        return reminderDate(on: tomorrow, calendar: calendar)
    }

    private static func reminderHour() -> Int {
        let defaults = SharedDefaults.app
        if defaults.object(forKey: reminderHourDefaultsKey) == nil {
            return defaultReminderHour
        }
        return defaults.integer(forKey: reminderHourDefaultsKey)
    }

    private static func reminderMinute() -> Int {
        let defaults = SharedDefaults.app
        if defaults.object(forKey: reminderMinuteDefaultsKey) == nil {
            return defaultReminderMinute
        }
        return defaults.integer(forKey: reminderMinuteDefaultsKey)
    }
}

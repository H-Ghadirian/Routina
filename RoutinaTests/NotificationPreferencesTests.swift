import Foundation
import Testing
@testable @preconcurrency import Routina

@Suite(.serialized)
struct NotificationPreferencesTests {
    @Test
    func reminderTimeDate_usesStoredHourAndMinuteOnRequestedDay() {
        let defaults = SharedDefaults.app
        let previousHour = defaults.object(forKey: NotificationPreferences.reminderHourDefaultsKey)
        let previousMinute = defaults.object(forKey: NotificationPreferences.reminderMinuteDefaultsKey)
        defer {
            restore(previousHour, forKey: NotificationPreferences.reminderHourDefaultsKey, defaults: defaults)
            restore(previousMinute, forKey: NotificationPreferences.reminderMinuteDefaultsKey, defaults: defaults)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        NotificationPreferences.storeReminderTime(
            makeDate("2026-03-17T06:45:00Z"),
            calendar: calendar
        )

        let reminder = NotificationPreferences.reminderTimeDate(
            calendar: calendar,
            now: makeDate("2026-03-18T12:00:00Z")
        )

        #expect(reminder == makeDate("2026-03-18T06:45:00Z"))
    }

    @Test
    func nextReminderDate_returnsSameDayWhenReminderHasNotPassedYet() {
        let defaults = SharedDefaults.app
        let previousHour = defaults.object(forKey: NotificationPreferences.reminderHourDefaultsKey)
        let previousMinute = defaults.object(forKey: NotificationPreferences.reminderMinuteDefaultsKey)
        defer {
            restore(previousHour, forKey: NotificationPreferences.reminderHourDefaultsKey, defaults: defaults)
            restore(previousMinute, forKey: NotificationPreferences.reminderMinuteDefaultsKey, defaults: defaults)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        NotificationPreferences.storeReminderTime(
            makeDate("2026-03-17T20:30:00Z"),
            calendar: calendar
        )

        let nextReminder = NotificationPreferences.nextReminderDate(
            after: makeDate("2026-03-18T19:00:00Z"),
            calendar: calendar
        )

        #expect(nextReminder == makeDate("2026-03-18T20:30:00Z"))
    }

    @Test
    func nextReminderDate_rollsForwardWhenReminderAlreadyPassed() {
        let defaults = SharedDefaults.app
        let previousHour = defaults.object(forKey: NotificationPreferences.reminderHourDefaultsKey)
        let previousMinute = defaults.object(forKey: NotificationPreferences.reminderMinuteDefaultsKey)
        defer {
            restore(previousHour, forKey: NotificationPreferences.reminderHourDefaultsKey, defaults: defaults)
            restore(previousMinute, forKey: NotificationPreferences.reminderMinuteDefaultsKey, defaults: defaults)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        NotificationPreferences.storeReminderTime(
            makeDate("2026-03-17T08:15:00Z"),
            calendar: calendar
        )

        let nextReminder = NotificationPreferences.nextReminderDate(
            after: makeDate("2026-03-18T09:00:00Z"),
            calendar: calendar
        )

        #expect(nextReminder == makeDate("2026-03-19T08:15:00Z"))
    }

    private func restore(_ value: Any?, forKey key: String, defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

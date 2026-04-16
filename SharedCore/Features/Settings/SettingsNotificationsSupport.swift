import Foundation

enum SettingsNotificationsEditor {
    static func setNotificationsEnabled(
        _ isEnabled: Bool,
        state: inout SettingsNotificationsState
    ) {
        state.notificationsEnabled = isEnabled
    }

    static func applyAuthorizationResult(
        _ isGranted: Bool,
        state: inout SettingsNotificationsState
    ) {
        state.notificationsEnabled = isGranted
        state.systemSettingsNotificationsEnabled = isGranted
    }

    static func updateReminderTime(
        _ reminderTime: Date,
        state: inout SettingsNotificationsState
    ) {
        state.notificationReminderTime = reminderTime
    }

    static func updateSystemPermission(
        _ isEnabled: Bool,
        state: inout SettingsNotificationsState
    ) {
        state.systemSettingsNotificationsEnabled = isEnabled
    }

    static func refreshFromSettings(
        notificationsEnabled: Bool,
        reminderTime: Date,
        state: inout SettingsNotificationsState
    ) {
        state.notificationsEnabled = notificationsEnabled
        state.notificationReminderTime = reminderTime
    }
}

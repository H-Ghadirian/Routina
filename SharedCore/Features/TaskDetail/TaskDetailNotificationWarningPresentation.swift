enum TaskDetailNotificationWarningPresentation {
    static func warningText(
        hasLoadedNotificationStatus: Bool,
        expectsClockTimeNotification: Bool,
        appNotificationsEnabled: Bool,
        systemNotificationsAuthorized: Bool
    ) -> String? {
        guard hasLoadedNotificationStatus else { return nil }
        guard expectsClockTimeNotification else { return nil }
        if !appNotificationsEnabled {
            return "Notifications are off in Routina. You won't be notified for this scheduled time."
        }
        if !systemNotificationsAuthorized {
            return "Notifications are disabled in system settings. You won't be notified for this scheduled time."
        }
        return nil
    }

    static func actionTitle(
        warningText: String?,
        appNotificationsEnabled: Bool
    ) -> String? {
        guard warningText != nil else { return nil }
        return appNotificationsEnabled ? "Open System Settings" : "Turn On Notifications"
    }
}

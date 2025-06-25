import SwiftData

enum SettingsNotificationsExecution {
    static func disableNotifications(
        notificationClient: NotificationClient
    ) async {
        await notificationClient.cancelAll()
    }

    static func requestAuthorization(
        notificationClient: NotificationClient
    ) async -> Bool {
        await notificationClient.requestAuthorizationIfNeeded()
    }

    @MainActor
    static func reconcileAuthorizationResult(
        isGranted: Bool,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        appSettingsClient: AppSettingsClient,
        notificationClient: NotificationClient
    ) async {
        guard isGranted else { return }

        try? await SettingsExecutionSupport.rescheduleNotificationsIfNeeded(
            in: modelContext(),
            appSettingsClient: appSettingsClient,
            notificationClient: notificationClient
        )
    }

    @MainActor
    static func reconcileReminderChange(
        notificationsEnabled: Bool,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        appSettingsClient: AppSettingsClient,
        notificationClient: NotificationClient
    ) async {
        guard notificationsEnabled else { return }

        try? await SettingsExecutionSupport.rescheduleNotificationsIfNeeded(
            in: modelContext(),
            appSettingsClient: appSettingsClient,
            notificationClient: notificationClient
        )
    }

    @MainActor
    static func reconcileEnabledState(
        notificationsEnabled: Bool,
        systemNotificationsEnabled: Bool,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        appSettingsClient: AppSettingsClient,
        notificationClient: NotificationClient
    ) async {
        guard notificationsEnabled else { return }

        if systemNotificationsEnabled {
            try? await SettingsExecutionSupport.rescheduleNotificationsIfNeeded(
                in: modelContext(),
                appSettingsClient: appSettingsClient,
                notificationClient: notificationClient
            )
        } else {
            await notificationClient.cancelAll()
        }
    }
}

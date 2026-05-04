import ComposableArchitecture
import Foundation

enum TaskDetailNotificationActionHandler {
    typealias State = TaskDetailFeature.State
    typealias Action = TaskDetailFeature.Action

    static func notificationDisabledWarningTapped(
        state: inout State,
        now: () -> Date,
        calendar: () -> Calendar,
        notificationClient: () -> NotificationClient,
        appSettingsClient: () -> AppSettingsClient,
        urlOpenerClient: () -> URLOpenerClient
    ) -> Effect<Action> {
        if !state.appNotificationsEnabled {
            let referenceDate = now()
            let calendar = calendar()
            let notificationPayload = NotificationCoordinator.shouldScheduleNotification(
                for: state.task,
                referenceDate: referenceDate,
                calendar: calendar
            )
                ? NotificationCoordinator.notificationPayload(
                    for: state.task,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
                : nil
            let notificationClient = notificationClient()
            let appSettingsClient = appSettingsClient()
            let urlOpenerClient = urlOpenerClient()
            return .run { @MainActor send in
                let granted = await notificationClient.requestAuthorizationIfNeeded()
                appSettingsClient.setNotificationsEnabled(granted)
                if granted, let notificationPayload {
                    await notificationClient.schedule(notificationPayload)
                } else if let url = urlOpenerClient.notificationSettingsURL() {
                    urlOpenerClient.open(url)
                }
                await send(.notificationStatusLoaded(appEnabled: granted, systemAuthorized: granted))
            }
        }

        guard !state.systemNotificationsAuthorized else { return .none }
        let urlOpenerClient = urlOpenerClient()
        return .run { @MainActor _ in
            guard let url = urlOpenerClient.notificationSettingsURL() else { return }
            urlOpenerClient.open(url)
        }
    }

    static func notificationStatusLoaded(
        appEnabled: Bool,
        systemAuthorized: Bool,
        state: inout State
    ) -> Effect<Action> {
        state.hasLoadedNotificationStatus = true
        state.appNotificationsEnabled = appEnabled
        state.systemNotificationsAuthorized = systemAuthorized
        return .none
    }
}

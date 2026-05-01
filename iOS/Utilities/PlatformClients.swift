import Foundation
import UserNotifications

extension RoutinaAppBootstrap.PlatformClients {
    static let iOSLive = RoutinaAppBootstrap.PlatformClients(
        notificationClient: .live,
        appIconClient: .live,
        locationClient: .live
    )
}

extension AppIconClient {
    static let live = AppIconClient(
        requestChange: { option in
            await PlatformSupport.requestAppIconChange(to: option)
        }
    )
}

extension LocationClient {
    static let live = LocationClient(
        snapshot: { requestAuthorizationIfNeeded in
            await OneShotLocationProvider().fetchSnapshot(
                requestAuthorizationIfNeeded: requestAuthorizationIfNeeded
            )
        }
    )
}

extension NotificationClient {
    static let live = NotificationClient(
        schedule: { payload in
            guard NotificationPreferences.notificationsEnabled else { return }
            guard !payload.isArchived else {
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: [payload.identifier])
                center.removeDeliveredNotifications(withIdentifiers: [payload.identifier])
                return
            }

            let request = UNNotificationRequest(
                identifier: payload.identifier,
                content: NotificationCoordinator.createNotificationContent(for: payload),
                trigger: NotificationCoordinator.createNotificationTrigger(for: payload)
            )
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [payload.identifier])
            center.removeDeliveredNotifications(withIdentifiers: [payload.identifier])
            try? await center.add(request)
        },
        cancel: { identifier in
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.removeDeliveredNotifications(withIdentifiers: [identifier])
        },
        cancelAll: {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
        },
        requestAuthorizationIfNeeded: {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                return true
            case .denied:
                return false
            case .notDetermined:
                return (try? await center.requestAuthorization(options: notificationAuthorizationOptions())) ?? false
            @unknown default:
                return false
            }
        },
        systemNotificationsAuthorized: {
            let settings = await UNUserNotificationCenter.current().notificationSettings()

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                return true
            case .denied, .notDetermined:
                return false
            @unknown default:
                return false
            }
        }
    )

    private static func notificationAuthorizationOptions() -> UNAuthorizationOptions {
        [.alert, .sound, .badge]
    }
}

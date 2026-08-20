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
#if ROUTINA_IOS_LOCATION_SERVICES
            await OneShotLocationProvider().fetchSnapshot(
                requestAuthorizationIfNeeded: requestAuthorizationIfNeeded
            )
#else
            _ = requestAuthorizationIfNeeded
            return LocationSnapshot(authorizationStatus: .notDetermined)
#endif
        }
    )
}

extension NotificationClient {
    static let live = NotificationClient(
        schedule: { payload in
            await NotificationCoordinator.scheduleNotification(payload)
        },
        cancel: { identifier in
            NotificationCoordinator.cancelNotification(identifier)
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
        },
        pendingScheduledNotifications: {
            let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
            return NotificationClient.scheduledNotificationSummaries(from: requests)
        },
        removeScheduledNotification: { notification in
            await NotificationCoordinator.removeScheduledNotification(notification)
        },
        pauseScheduledNotification: { notification, until in
            await NotificationCoordinator.pauseScheduledNotification(notification, until: until)
        }
    )

    private static func notificationAuthorizationOptions() -> UNAuthorizationOptions {
        [.alert, .sound, .badge]
    }
}

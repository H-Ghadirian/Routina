import Foundation
import UIKit
import UserNotifications

public final class RemoteNotificationIOSDelegate: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard !AppEnvironment.isAutomatedTestMode else { return true }
        NotificationCoordinator.configureCurrentCenter(delegate: self)
        return true
    }

    public func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        CloudKitSyncDiagnostics.recordPushRegistrationSuccess(tokenByteCount: deviceToken.count)
    }

    public func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        CloudKitSyncDiagnostics.recordPushRegistrationFailure(error)
    }

    public func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        CloudKitSyncDiagnostics.recordRemoteNotificationReceived()
        NotificationCenter.default.postRoutineDidUpdate()
        completionHandler(.noData)
    }
}

extension RemoteNotificationIOSDelegate: UNUserNotificationCenterDelegate {
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await NotificationCoordinator.handleResponse(
            actionIdentifier: response.actionIdentifier,
            requestIdentifier: response.notification.request.identifier
        )
    }
}

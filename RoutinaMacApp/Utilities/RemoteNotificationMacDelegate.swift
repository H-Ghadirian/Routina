import AppKit
import Foundation
import UserNotifications

public final class RemoteNotificationMacDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isAutomatedTestMode else { return }
        NotificationCoordinator.configureCurrentCenter(delegate: self)
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    public func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        CloudKitSyncDiagnostics.recordPushRegistrationSuccess(tokenByteCount: deviceToken.count)
    }

    public func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        CloudKitSyncDiagnostics.recordPushRegistrationFailure(error)
    }

    public func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        CloudKitSyncDiagnostics.recordRemoteNotificationReceived()
        NotificationCenter.default.postRoutineDidUpdate()
    }
}

extension RemoteNotificationMacDelegate: UNUserNotificationCenterDelegate {
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

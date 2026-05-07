import CloudKit
import Foundation
import SwiftData
import UIKit
import UserNotifications
import WidgetKit

public final class RemoteNotificationIOSDelegate: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard !AppEnvironment.isAutomatedTestMode else { return true }
        NotificationCoordinator.configureCurrentCenter(delegate: self)
        handleLaunchURLIfPresent(launchOptions)
        return true
    }

    @available(iOS, introduced: 2.0, deprecated: 26.0, message: "SwiftUI scene URL handling is primary; this keeps older app-delegate URL delivery paths routed.")
    public func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        handleIncomingURL(url)
    }

    public func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        if let webpageURL = userActivity.webpageURL, handleIncomingURL(webpageURL) {
            return true
        }

        if userActivity.activityType == NSUserActivityTypeLiveActivity {
            NSLog("Routina Live Activity continuation received")
            Task { @MainActor in
                RoutinaActiveFocusOpenDispatcher.requestOpen()
            }
            return true
        }

        return false
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

    public func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            do {
                try await CloudSharingService.acceptShare(
                    metadata: cloudKitShareMetadata,
                    into: PersistenceController.shared.container.mainContext
                )
            } catch {
                NSLog("Failed to accept CloudKit share: \(error.localizedDescription)")
            }
        }
    }

    private func handleIncomingURL(_ url: URL) -> Bool {
        guard let deepLink = RoutinaDeepLink(url: url) else { return false }
        NSLog("Routina deep link URL received: \(url.absoluteString)")
        Task { @MainActor in
            RoutinaDeepLinkDispatcher.open(deepLink)
        }
        return true
    }

    private func handleLaunchURLIfPresent(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        let launchURLKey = UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsURLKey")
        guard let url = launchOptions?[launchURLKey] as? URL else { return }
        _ = handleIncomingURL(url)
    }
}

extension RemoteNotificationIOSDelegate: UNUserNotificationCenterDelegate {
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if let deepLink = RoutinaDeepLink(notificationUserInfo: response.notification.request.content.userInfo) {
            await MainActor.run {
                RoutinaDeepLinkDispatcher.open(deepLink)
            }
            return
        }

        await NotificationCoordinator.handleResponse(
            actionIdentifier: response.actionIdentifier,
            requestIdentifier: response.notification.request.identifier
        )
    }
}

import Foundation

#if os(iOS)
import UIKit
import UserNotifications

final class RemoteNotificationIOSDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NotificationCoordinator.configureCurrentCenter(delegate: self)
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        CloudKitSyncDiagnostics.recordPushRegistrationSuccess(tokenByteCount: deviceToken.count)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        CloudKitSyncDiagnostics.recordPushRegistrationFailure(error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        CloudKitSyncDiagnostics.recordRemoteNotificationReceived()
        NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
        completionHandler(.noData)
    }

}

extension RemoteNotificationIOSDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await NotificationCoordinator.handleResponse(
            actionIdentifier: response.actionIdentifier,
            requestIdentifier: response.notification.request.identifier
        )
    }
}
#elseif os(macOS)
import AppKit
import UserNotifications

final class RemoteNotificationMacDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCoordinator.configureCurrentCenter(delegate: self)
        NSWindow.allowsAutomaticWindowTabbing = false
        DispatchQueue.main.async {
            MacMenuCleanup.removeUnneededMenus()
        }
    }

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        CloudKitSyncDiagnostics.recordPushRegistrationSuccess(tokenByteCount: deviceToken.count)
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        CloudKitSyncDiagnostics.recordPushRegistrationFailure(error)
    }

    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        CloudKitSyncDiagnostics.recordRemoteNotificationReceived()
        NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
    }

}

@MainActor
private enum MacMenuCleanup {
    private static let rootMenusToRemove: Set<String> = [
        "File",
        "View",
        "Help"
    ]

    private static let submenuTitlesToRemove: Set<String> = [
        "Hide Tab Bar",
        "Show Tab Bar",
        "Show All Tabs",
        "Merge All Windows",
        "Move Tab to New Window"
    ]

    private static let submenuActionsToRemove: Set<Selector> = [
        NSSelectorFromString("toggleTabBar:"),
        NSSelectorFromString("showAllTabs:"),
        NSSelectorFromString("toggleTabOverview:"),
        NSSelectorFromString("mergeAllWindows:"),
        NSSelectorFromString("moveTabToNewWindow:")
    ]

    static func removeUnneededMenus() {
        guard let mainMenu = NSApp.mainMenu else { return }

        removeRootMenus(from: mainMenu)
        removeSubmenuItems(from: mainMenu)
    }

    private static func removeRootMenus(from menu: NSMenu) {
        for item in Array(menu.items).reversed() {
            if rootMenusToRemove.contains(item.title) {
                menu.removeItem(item)
            }
        }
    }

    private static func removeSubmenuItems(from menu: NSMenu) {
        for item in Array(menu.items).reversed() {
            let matchesAction = item.action.map(submenuActionsToRemove.contains) ?? false

            if submenuTitlesToRemove.contains(item.title) || matchesAction {
                menu.removeItem(item)
                continue
            }

            if let submenu = item.submenu {
                removeSubmenuItems(from: submenu)
            }
        }
    }
}

extension RemoteNotificationMacDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await NotificationCoordinator.handleResponse(
            actionIdentifier: response.actionIdentifier,
            requestIdentifier: response.notification.request.identifier
        )
    }
}
#endif

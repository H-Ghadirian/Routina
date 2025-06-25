import SwiftUI
import UserNotifications
import CoreData
import ComposableArchitecture

class SettingsViewModel: ObservableObject {
    @Published var appSettingNotifEnabled: Bool = false
    @Published var systemSettingsNotificationsEnabled: Bool = false
    @Published var showNotificationAlert = false

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    @Dependency(\.notificationClient) var notificationClient

    init() {
        appSettingNotifEnabled = SharedDefaults.app[.appSettingNotificationsEnabled]
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            SharedDefaults.app[.requestNotificationPermission] = true
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
                return
            }
        }
    }

    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let systemEnabled = settings.authorizationStatus == .authorized
                let userEnabled = SharedDefaults.app[.appSettingNotificationsEnabled]
                self.systemSettingsNotificationsEnabled = systemEnabled
                self.appSettingNotifEnabled = systemEnabled && userEnabled
            }
        }
    }

    func updateNotificationSettings(enabled: Bool) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .denied {
                    if enabled { self.openAppNotificationSystemSettings() }
                    self.systemSettingsNotificationsEnabled = false
                    return
                }

                self.systemSettingsNotificationsEnabled = settings.authorizationStatus == .authorized
                if self.systemSettingsNotificationsEnabled && enabled {
                    self.requestAuthorization()
                    self.scheduleNotificationsForAllRoutines()
                } else {
                    self.disableNotifications()
                }
                SharedDefaults.app[.appSettingNotificationsEnabled] = self.appSettingNotifEnabled
            }
        }
    }

    func openAppNotificationSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    func disableNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        appSettingNotifEnabled = false
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.appSettingNotifEnabled = granted
            }
        }
    }

    func scheduleNotificationsForAllRoutines() {
        let fetchRequest = NSFetchRequest<RoutineTask>(entityName: "RoutineTask")
        do {
            let routines = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
            for routine in routines {
                Task {
                    await notificationClient.schedule(routine)
                }
            }
        } catch {
            print("Failed to fetch routines: \(error.localizedDescription)")
        }
    }

    func openEmail() {
        if let emailURL = URL(string: "mailto:h.qadirian@gmail.com") {
            UIApplication.shared.open(emailURL)
        }
    }
}

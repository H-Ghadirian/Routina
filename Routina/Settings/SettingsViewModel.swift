import SwiftUI
import UserNotifications
import CoreData

class SettingsViewModel: ObservableObject {
    @Published var appSettingNotificationsEnabled: Bool = false
    @Published var systemSettingsNotificationsEnabled: Bool = false
    @Published var showNotificationAlert = false

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    init() {
        UserDefaults.standard.register(defaults: ["appSettingNotificationsEnabled": true])
        appSettingNotificationsEnabled = UserDefaults.standard.bool(forKey: "appSettingNotificationsEnabled")
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            UserDefaults.standard.set(true, forKey: "requestNotificationPermission")
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
                let userEnabled = UserDefaults.standard.bool(forKey: "appSettingNotificationsEnabled")
                self.systemSettingsNotificationsEnabled = systemEnabled
                self.appSettingNotificationsEnabled = systemEnabled && userEnabled
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
                UserDefaults.standard.set(self.appSettingNotificationsEnabled, forKey: "appSettingNotificationsEnabled")
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
        appSettingNotificationsEnabled = false
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.appSettingNotificationsEnabled = granted
            }
        }
    }

    func scheduleNotificationsForAllRoutines() {
        let fetchRequest = NSFetchRequest<RoutineTask>(entityName: "RoutineTask")
        do {
            let routines = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
            for routine in routines {
                scheduleNotification(for: routine)
            }
        } catch {
            print("Failed to fetch routines: \(error.localizedDescription)")
        }
    }

    func scheduleNotification(for task: RoutineTask) {
        let request = UNNotificationRequest(
            identifier: task.objectID.uriRepresentation().absoluteString,
            content: createContent(for: task.name ?? "your routine"),
            trigger: createTrigger(for: task)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }

    func createTrigger(for task: RoutineTask) -> UNCalendarNotificationTrigger {
        let dueDate = Calendar.current.date(
            byAdding: .day, value: Int(task.interval), to: task.lastDone ?? Date()
        ) ?? Date()
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        return trigger
    }

    func createContent(for taskName: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Time to complete \(taskName)!"
        content.body = "Your routine is due today."
        content.sound = .default
        return content
    }

    func openEmail() {
        if let emailURL = URL(string: "mailto:h.qadirian@gmail.com") {
            UIApplication.shared.open(emailURL)
        }
    }
}

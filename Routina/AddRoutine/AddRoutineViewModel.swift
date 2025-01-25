import UserNotifications
import SwiftUI
import CoreData

class AddRoutineViewModel: ObservableObject {
    @Published var routineName: String = ""
    @Published var interval: Int = 1
    @Published var notificationsDisabled = false
    @Published var showNotificationAlert = false
    @Published var selectedTab: String = Tab.home.rawValue

    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsDisabled = settings.authorizationStatus != .authorized || !UserDefaults.standard.bool(forKey: "appSettingNotificationsEnabled")
            }
        }
    }

#if os(iOS)
    func openSettings(dismiss: DismissAction) {
        if !UserDefaults.standard.bool(forKey: "requestNotificationPermission") {
            showNotificationAlert = true
            return
        }
        selectedTab = Tab.settings.rawValue
        dismiss()
    }
#endif

    func addRoutine(context: NSManagedObjectContext, dismiss: DismissAction) {
        if notificationsDisabled, !UserDefaults.standard.bool(forKey: "requestNotificationPermission") {
            showNotificationAlert = true
            return
        }
        let newRoutine = RoutineTask(context: context)
        newRoutine.name = routineName
        newRoutine.interval = Int16(interval)
        newRoutine.lastDone = Date()

        do {
            try context.save()
            scheduleNotification(for: newRoutine)
            dismiss() // Now `dismiss` can be called directly
        } catch {
            print("Error saving routine: \(error.localizedDescription)")
        }
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
}

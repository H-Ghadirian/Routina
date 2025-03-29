import UserNotifications
import SwiftUI
import CoreData
import ComposableArchitecture

class AddRoutineViewModel: ObservableObject {
    @Published var routineName: String = ""
    @Published var interval: Int = 1
    @Published var notificationsDisabled = false
    @Published var showNotificationAlert = false
    @Published var selectedTab: String = Tab.home.rawValue
    @Dependency(\.notificationClient) var notificationClient

    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsDisabled = settings.authorizationStatus != .authorized || !SharedDefaults.app[.appSettingNotificationsEnabled]
            }
        }
    }

#if os(iOS)
    func openSettings(dismiss: DismissAction) {
        if !SharedDefaults.app[.requestNotificationPermission] {
            showNotificationAlert = true
            return
        }
        selectedTab = Tab.settings.rawValue
        dismiss()
    }
#endif

    func addRoutine(context: NSManagedObjectContext, dismiss: DismissAction) {
        if notificationsDisabled, !SharedDefaults.app[.requestNotificationPermission] {
            showNotificationAlert = true
            return
        }
        let newRoutine = RoutineTask(context: context)
        newRoutine.name = routineName
        newRoutine.interval = Int16(interval)
        newRoutine.lastDone = Date()

        do {
            try context.save()
            Task {
                await notificationClient.schedule(newRoutine)
            }
            dismiss() // Now `dismiss` can be called directly
        } catch {
            print("Error saving routine: \(error.localizedDescription)")
        }
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
}

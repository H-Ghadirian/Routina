import SwiftUI
import UserNotifications
import CoreData

struct SettingsView: View {
    @State private var appSettingNotificationsEnabled: Bool = false
    @State private var systemSettingsNotificationsEnabled: Bool = false
    @State private var showNotificationAlert = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    init() {
        UserDefaults.standard.register(defaults: ["appSettingNotificationsEnabled": true])
        appSettingNotificationsEnabled = UserDefaults.standard.bool(forKey: "appSettingNotificationsEnabled")
    }

    var body: some View {
        NavigationView {
            List {
#if os(iOS)
                notificationSectionView

                supportSectionView
#endif
                aboutSectionView
            }
            .navigationTitle("Settings")
            .onAppear {
                checkNotificationStatus()
            }.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                checkNotificationStatus()
            }
            .alert("Enable Notifications", isPresented: $showNotificationAlert) {
                Button("Cancel", role: .cancel) {}
                Button("OK") {
                    requestNotificationPermission()
                }
            } message: {
                Text("To remind you about your routines, please enable notifications in Settings.")
            }
        }
    }

#if os(iOS)
    private var notificationSectionView: some View {
        Section(header: Text("Notifications")) {
            Toggle("Enable Notifications", isOn: $appSettingNotificationsEnabled)
                .onChange(of: appSettingNotificationsEnabled) { _, newValue in
                    updateNotificationSettings(enabled: newValue)
                }
                .disabled(!systemSettingsNotificationsEnabled)

            if !systemSettingsNotificationsEnabled {
                Button("Allow Notifications in System Settings is disabled") {
                    if !UserDefaults.standard.bool(forKey: "requestNotificationPermission") {
                        showNotificationAlert = true
                        return
                    }
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
    }

    private var supportSectionView: some View {
        Section(header: Text("Support")) {
            Button(action: openEmail) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.blue)
                    Text("Contact Us")
                }
            }
        }
    }
#endif

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            UserDefaults.standard.set(true, forKey: "requestNotificationPermission")
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
                return
            }
        }
    }

    private var aboutSectionView: some View {
        Section(header: Text("About")) {
            HStack {
                Text("App Version")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.gray)
            }
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
        DispatchQueue.main.async {
                let systemEnabled = settings.authorizationStatus == .authorized
                let userEnabled = UserDefaults.standard.bool(forKey: "appSettingNotificationsEnabled")
                systemSettingsNotificationsEnabled = systemEnabled
                appSettingNotificationsEnabled = systemEnabled && userEnabled
            }
        }
    }

#if os(iOS)
    private func updateNotificationSettings(enabled: Bool) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .denied {
                    if enabled { openAppNotificationSystemSettings() }
                    systemSettingsNotificationsEnabled = false
                    return
                }

                systemSettingsNotificationsEnabled = settings.authorizationStatus == .authorized

                if systemSettingsNotificationsEnabled && enabled {
                    requestAuthorization()
                    scheduleNotificationsForAllRoutines()
                } else {
                    disableNotifications()
                }
                UserDefaults.standard.set(appSettingNotificationsEnabled, forKey: "appSettingNotificationsEnabled")

            }
        }
    }

    private func openAppNotificationSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func disableNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        appSettingNotificationsEnabled = false
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                appSettingNotificationsEnabled = granted
            }
        }
    }

    private func openEmail() {
        if let emailURL = URL(string: "mailto:h.qadirian@gmail.com") {
            UIApplication.shared.open(emailURL)
        }
    }
    
    private func scheduleNotificationsForAllRoutines() {
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

    private func scheduleNotification(for task: RoutineTask) {

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
    
    private func createTrigger(for task: RoutineTask) -> UNCalendarNotificationTrigger {
        let dueDate = Calendar.current.date(
            byAdding: .day, value: Int(task.interval), to: task.lastDone ?? Date()
        ) ?? Date()
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        return trigger
    }

    private func createContent(for taskName: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Time to complete \(taskName)!"
        content.body = "Your routine is due today."
        content.sound = .default
        return content
    }

#endif
}

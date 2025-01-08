import SwiftUI
import UserNotifications

struct SettingsView: View {
    @State private var notificationsEnabled: Bool = false

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    var body: some View {
        VStack {
            Text("Settings")
                .font(.largeTitle)
                .padding()

            Toggle("Enable Notifications", isOn: $notificationsEnabled)
                .padding()
                .onChange(of: notificationsEnabled) { newValue in
                    updateNotificationSettings(enabled: newValue)
                }

            if !notificationsEnabled {
                Button("Disable Notifications in Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .padding()
                .foregroundColor(.red)
            }

            Text("App Version: \(appVersion)")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .onAppear {
            checkNotificationStatus()
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }

    private func updateNotificationSettings(enabled: Bool) {
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                DispatchQueue.main.async {
                    notificationsEnabled = granted
                }
            }
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            notificationsEnabled = false // Users must disable notifications manually in settings.
        }
    }
}

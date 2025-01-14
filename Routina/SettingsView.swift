import SwiftUI
import UserNotifications

struct SettingsView: View {
    @State private var notificationsEnabled: Bool = false

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
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
            }
        }
    }

#if os(iOS)
    private var notificationSectionView: some View {
        Section(header: Text("Notifications")) {
            Toggle("Enable Notifications", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, newValue in
                    updateNotificationSettings(enabled: newValue)
                }

            if !notificationsEnabled {
                Button("Disable Notifications in Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
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
                let userEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
                notificationsEnabled = systemEnabled && userEnabled
            }
        }
    }

#if os(iOS)
    private func updateNotificationSettings(enabled: Bool) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .denied {
                    openAppNotificationSystemSettings()
                    notificationsEnabled = false
                    return
                }

                UserDefaults.standard.set(enabled, forKey: "notificationsEnabled")

                let systemEnabled = settings.authorizationStatus == .authorized
                let userEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
                notificationsEnabled = systemEnabled && userEnabled

                if notificationsEnabled {
                    requestAuthorization()
                } else {
                    disableNotifications()
                }
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
        notificationsEnabled = false
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                notificationsEnabled = granted
            }
        }
    }

    private func openEmail() {
        if let emailURL = URL(string: "mailto:h.qadirian@gmail.com") {
            UIApplication.shared.open(emailURL)
        }
    }
#endif
}

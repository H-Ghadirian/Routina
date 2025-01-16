import SwiftUI
import UserNotifications

struct SettingsView: View {
    @State private var appSettingNotificationsEnabled: Bool = false
    @State private var systemSettingsNotificationsEnabled: Bool = false

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
#endif
}

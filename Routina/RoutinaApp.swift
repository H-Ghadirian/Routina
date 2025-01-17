import SwiftUI
import UserNotifications

@main
struct RoutinaApp: App {
    let persistenceController = PersistenceController.shared
    @State private var showSettingsBadge: Bool = false

    var body: some Scene {
        WindowGroup {
            TabView {
                homeView
                settingsView
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                requestNotificationPermission()
            }
        }
    }

    private var homeView: some View {
        HomeView()
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
    }

    private var settingsView: some View {
        SettingsView()
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .badge(showSettingsBadge ? "!" : nil)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let systemEnabled = settings.authorizationStatus == .authorized
                let userEnabled = UserDefaults.standard.bool(forKey: "appSettingNotificationsEnabled")
                showSettingsBadge = userEnabled && !systemEnabled
            }
        }
    }

}

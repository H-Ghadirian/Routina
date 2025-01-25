import SwiftUI
import UserNotifications

enum Tab: String {
    case home = "Home"
    case settings = "Settings"
}

@main
struct RoutinaApp: App {
    let persistenceController = PersistenceController.shared
    @State private var showSettingsBadge: Bool = false
    @StateObject var viewModel = AddRoutineViewModel()

    var body: some Scene {
        WindowGroup {
            TabView(selection: $viewModel.selectedTab) {
                homeView
                    .tag(Tab.home.rawValue)

                settingsView
                    .tag(Tab.settings.rawValue)

            }
            .environmentObject(viewModel)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                requestNotificationPermission()
            }
        }
    }

    private var homeView: some View {
        HomeView()
            .tabItem {
                Label(Tab.home.rawValue, systemImage: "house")
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
    }

    private var settingsView: some View {
        SettingsView()
            .tabItem {
                Label(Tab.settings.rawValue, systemImage: "gear")
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

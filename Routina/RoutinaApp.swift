import SwiftUI
import UserNotifications

@main
struct RoutinaApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                homeView
                settingsView
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
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
                return
            }

            if !granted {
                DispatchQueue.main.async {
                    #if os(iOS)
                    showSettingsAlert()
                    #endif
                }
            }
        }
    }

#if os(iOS)
    private func showSettingsAlert() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alertController, animated: true)
        }
    }

    private var alertController: UIAlertController {
        let alert = UIAlertController(
            title: "Enable Notifications",
            message: "To receive reminders for your routines, please enable notifications in Settings.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        return alert
    }
#endif

}

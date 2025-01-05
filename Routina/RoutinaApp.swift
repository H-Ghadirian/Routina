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
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
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
                    showSettingsAlert()
                }
            }
        }
    }

    private func showSettingsAlert() {
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

        // Show the alert (requires a UIViewController)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

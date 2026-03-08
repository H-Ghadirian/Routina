import ComposableArchitecture
import SwiftData
import SwiftUI
import UIKit

@main
struct RoutinaTCAApp: App {
    @UIApplicationDelegateAdaptor(RemoteNotificationIOSDelegate.self) private var remoteNotificationDelegate

    init() {
        RoutinaAppBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            let persistence = PersistenceController.shared
            let store = RoutinaAppBootstrap.makeStore(using: persistence)

            AppView(store: store)
                .routinaAppRootWindowFrame()
                .modelContainer(persistence.container)
                .onAppear {
                    UIApplication.shared.registerForRemoteNotifications()
                    Task {
                        await CloudKitPushSubscriptionService.ensureSubscriptionIfNeeded(
                            containerIdentifier: AppEnvironment.cloudKitContainerIdentifier
                        )
                    }
                    WatchRoutineSyncBridge.shared.startIfNeeded {
                        persistence.container.mainContext
                    }
                }
        }
        .routinaAppWindowDefaults()
    }
}

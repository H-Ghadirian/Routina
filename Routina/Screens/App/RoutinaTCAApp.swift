import ComposableArchitecture
import SwiftData
import SwiftUI
import UIKit

@main
struct RoutinaTCAApp: App {
    @UIApplicationDelegateAdaptor(RemoteNotificationIOSDelegate.self) private var remoteNotificationDelegate
    private let persistence: PersistenceController
    private let store: StoreOf<AppFeature>

    @MainActor
    init() {
        RoutinaAppBootstrap.configure()

        let persistence = PersistenceController.shared
        self.persistence = persistence
        self.store = RoutinaAppBootstrap.makeStore(using: persistence)
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
                .routinaAppRootWindowFrame()
                .modelContainer(persistence.container)
                .onAppear {
                    guard !AppEnvironment.isAutomatedTestMode else { return }
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

#if os(iOS)
import ComposableArchitecture
import SwiftData
import SwiftUI
import UIKit

public struct RoutinaIOSRootScene: Scene {
    private let persistence: PersistenceController
    private let store: StoreOf<AppFeature>

    @MainActor
    public init() {
        let persistence = RoutinaSupportBootstrap.prepare()
        self.persistence = persistence
        self.store = RoutinaAppBootstrap.makeStore(using: persistence)
    }

    public var body: some Scene {
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
#endif

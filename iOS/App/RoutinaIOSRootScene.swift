import ComposableArchitecture
import SwiftData
import SwiftUI
import UIKit

struct RoutinaIOSRootScene: Scene {
    private let persistence: PersistenceController
    private let store: StoreOf<AppFeature>

    @MainActor
    init() {
        let persistence = RoutinaAppSceneBootstrap.preparePersistence()
        self.persistence = persistence
        self.store = RoutinaAppBootstrap.makeStore(
            using: persistence,
            platformClients: .iOSLive
        )
        if !AppEnvironment.isAutomatedTestMode {
            WatchRoutineSyncBridge.shared.startIfNeeded {
                persistence.container.mainContext
            }
            LocalBatteryRoutineMonitor.shared.startIfNeeded {
                persistence.container.mainContext
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
                .routinaAppRootWindowFrame()
                .modelContainer(persistence.container)
                .onAppear {
                    guard !AppEnvironment.isAutomatedTestMode else { return }
                    DeviceActivityRecorder.recordCurrentDeviceSession(
                        in: persistence.container.mainContext
                    )
                    UIApplication.shared.registerForRemoteNotifications()
                    PlatformSupport.applyAppIcon(.persistedSelection)
                    Task {
                        await CloudKitPushSubscriptionService.ensureSubscriptionIfNeeded(
                            containerIdentifier: AppEnvironment.cloudKitContainerIdentifier
                        )
                    }
                }
        }
        .routinaAppWindowDefaults()
    }
}

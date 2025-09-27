import ComposableArchitecture
import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@main
struct RoutinaTCAApp: App {
#if os(iOS)
    @UIApplicationDelegateAdaptor(RemoteNotificationIOSDelegate.self) private var remoteNotificationDelegate
#elseif os(macOS)
    @NSApplicationDelegateAdaptor(RemoteNotificationMacDelegate.self) private var remoteNotificationDelegate
#endif

    init() {
        let cloudContainer = AppEnvironment.cloudKitContainerIdentifier ?? "disabled"
        NSLog(
            "Routina data mode: \(AppEnvironment.dataModeLabel), defaults suite: \(AppEnvironment.userDefaultsSuiteName), cloud container: \(cloudContainer)"
        )
        CloudKitSyncDiagnostics.startIfNeeded()
        SharedDefaults.app.register(defaults: [
            .appSettingNotificationsEnabled: true
        ])
    }

    var body: some Scene {
        WindowGroup {
            let persistence = PersistenceController.shared
            let store = Store(
                initialState: AppFeature.State(),
                reducer: { AppFeature() },
                withDependencies: {
                    $0.modelContext = { @MainActor in persistence.container.mainContext }
                }
            )

            AppView(store: store)
                .routinaAppRootWindowFrame()
                .modelContainer(persistence.container)
#if os(iOS)
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
#elseif os(macOS)
                .onAppear {
                    NSApplication.shared.registerForRemoteNotifications()
                    Task {
                        await CloudKitPushSubscriptionService.ensureSubscriptionIfNeeded(
                            containerIdentifier: AppEnvironment.cloudKitContainerIdentifier
                        )
                    }
                }
#endif
        }
        .routinaAppWindowDefaults()
    }
}

import ComposableArchitecture
import Foundation
import SwiftData

enum RoutinaAppBootstrap {
    struct PlatformClients: Sendable {
        var notificationClient: NotificationClient
        var appIconClient: AppIconClient
        var locationClient: LocationClient
    }

    static func configure() {
        let cloudContainer = AppEnvironment.cloudKitContainerIdentifier ?? "disabled"
        NSLog(
            "Routina data mode: \(AppEnvironment.dataModeLabel), defaults suite: \(AppEnvironment.userDefaultsSuiteName), cloud container: \(cloudContainer)"
        )
        if !AppEnvironment.isAutomatedTestMode {
            CloudKitSyncDiagnostics.startIfNeeded()
            Task { @MainActor in
                CloudSyncedSurfaceRefreshCoordinator.startIfNeeded()
            }
            CloudSettingsKeyValueSync.startIfNeeded()
        }
        SharedDefaults.app.register(defaults: AppSettingsDefaults.boolValues)
        SharedDefaults.app.register(defaults: AppSettingsDefaults.stringValues)
        SharedDefaults.app.register(defaults: AppSettingsDefaults.intValues)
    }

    @MainActor
    static func makeStore(
        using persistence: PersistenceController,
        platformClients: PlatformClients
    ) -> StoreOf<AppFeature> {
        Store(
            initialState: AppFeature.State(),
            reducer: { AppFeature() },
            withDependencies: {
                $0.modelContext = { @MainActor in persistence.container.mainContext }
                $0.notificationClient = platformClients.notificationClient
                $0.appIconClient = platformClients.appIconClient
                $0.locationClient = platformClients.locationClient
            }
        )
    }
}

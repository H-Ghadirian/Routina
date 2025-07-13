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
        }
        SharedDefaults.app.register(defaults: [
            .appSettingNotificationsEnabled: false,
            .appSettingHideUnavailableRoutines: false,
            .appSettingAppLockEnabled: false
        ])
        SharedDefaults.app.register(defaults: [
            UserDefaultStringValueKey.appSettingRoutineListSectioningMode.rawValue: RoutineListSectioningMode.defaultValue.rawValue
        ])
        SharedDefaults.app.register(defaults: [
            NotificationPreferences.reminderHourDefaultsKey: NotificationPreferences.defaultReminderHour,
            NotificationPreferences.reminderMinuteDefaultsKey: NotificationPreferences.defaultReminderMinute
        ])
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

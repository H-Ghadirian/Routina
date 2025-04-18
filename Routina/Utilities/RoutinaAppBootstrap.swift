import ComposableArchitecture
import Foundation
import SwiftData

enum RoutinaAppBootstrap {
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
            .appSettingHideUnavailableRoutines: false
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
    static func makeStore(using persistence: PersistenceController) -> StoreOf<AppFeature> {
        Store(
            initialState: AppFeature.State(),
            reducer: { AppFeature() },
            withDependencies: {
                $0.modelContext = { @MainActor in persistence.container.mainContext }
            }
        )
    }
}

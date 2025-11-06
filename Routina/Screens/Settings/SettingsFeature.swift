import ComposableArchitecture
import CoreData
import SwiftUI
import UserNotifications

@Reducer
struct SettingsFeature {

    @ObservableState
    struct State: Equatable {
        var appVersion: String = ""
        var notificationsEnabled: Bool = SharedDefaults.app[.appSettingNotificationsEnabled]
        var systemSettingsNotificationsEnabled: Bool = true
        var isCloudSyncInProgress: Bool = false
        var cloudSyncStatusMessage: String = ""
    }

    enum Action: Equatable {
        case toggleNotifications(Bool)
        case openAppSettingsTapped
        case onAppear
        case onAppBecameActive
        case contactUsTapped
        case systemNotificationPermissionChecked(Bool)
        case syncNowTapped
        case cloudSyncFinished(success: Bool, message: String)
    }

    @Dependency(\.managedObjectContext) var viewContext

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleNotifications(let isOn):
                state.notificationsEnabled = isOn
                SharedDefaults.app[.appSettingNotificationsEnabled] = isOn
                return .none

            case .openAppSettingsTapped:
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                return .none
                
            case .onAppear:
                state.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                return .run { @MainActor send in
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    let systemEnabled = settings.authorizationStatus == .authorized
                    await send(.systemNotificationPermissionChecked(systemEnabled))
                }
                
            case .contactUsTapped:
                if let emailURL = URL(string: "mailto:h.qadirian@gmail.com") {
                    return .run { @MainActor _ in
                        UIApplication.shared.open(emailURL)
                    }
                }
                return .none

            case let .systemNotificationPermissionChecked(value):
                state.systemSettingsNotificationsEnabled = value
                return .none
            case .onAppBecameActive:
                return .run { @MainActor send in
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    let systemEnabled = settings.authorizationStatus == .authorized
                    await send(.systemNotificationPermissionChecked(systemEnabled))
                }

            case .syncNowTapped:
                state.isCloudSyncInProgress = true
                state.cloudSyncStatusMessage = "Syncing with iCloud..."
                return .run { @MainActor [viewContext] send in
                    do {
                        if viewContext.hasChanges {
                            try viewContext.save()
                        }
                        viewContext.refreshAllObjects()

                        // Trigger a UI refresh for features observing this notification.
                        NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)

                        await send(
                            .cloudSyncFinished(
                                success: true,
                                message: "Sync requested. iCloud updates may take a moment."
                            )
                        )
                    } catch {
                        await send(
                            .cloudSyncFinished(
                                success: false,
                                message: "Sync failed: \(error.localizedDescription)"
                            )
                        )
                    }
                }

            case let .cloudSyncFinished(_, message):
                state.isCloudSyncInProgress = false
                state.cloudSyncStatusMessage = message
                return .none
            }
        }
    }
}

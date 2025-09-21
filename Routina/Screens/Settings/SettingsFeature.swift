import CloudKit
import ComposableArchitecture
import SwiftData
import SwiftUI
import UserNotifications

@Reducer
struct SettingsFeature {

    @ObservableState
    struct State: Equatable {
        var appVersion: String = ""
        var dataModeDescription: String = AppEnvironment.dataModeLabel
        var iCloudContainerDescription: String = AppEnvironment.cloudKitContainerIdentifier ?? "Disabled"
        var cloudDiagnosticsSummary: String = CloudKitSyncDiagnostics.snapshot().summary
        var cloudDiagnosticsTimestamp: String = CloudKitSyncDiagnostics.snapshot().timestampText
        var pushDiagnosticsStatus: String = CloudKitSyncDiagnostics.snapshot().pushStatus
        var isDebugSectionVisible: Bool = false
        var cloudSyncAvailable: Bool = AppEnvironment.isCloudSyncEnabled
        var notificationsEnabled: Bool = SharedDefaults.app[.appSettingNotificationsEnabled]
        var systemSettingsNotificationsEnabled: Bool = true
        var isCloudSyncInProgress: Bool = false
        var isCloudDataResetInProgress: Bool = false
        var isCloudDataResetConfirmationPresented: Bool = false
        var cloudStatusMessage: String = ""
    }

    enum Action: Equatable {
        case toggleNotifications(Bool)
        case openAppSettingsTapped
        case onAppear
        case onAppBecameActive
        case contactUsTapped
        case aboutSectionLongPressed
        case systemNotificationPermissionChecked(Bool)
        case cloudDiagnosticsUpdated
        case syncNowTapped
        case setCloudDataResetConfirmation(Bool)
        case resetCloudDataConfirmed
        case cloudSyncFinished(success: Bool, message: String)
        case cloudDataResetFinished(success: Bool, message: String)
    }

    @Dependency(\.modelContext) var modelContext

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleNotifications(let isOn):
                state.notificationsEnabled = isOn
                SharedDefaults.app[.appSettingNotificationsEnabled] = isOn
                return .none

            case .openAppSettingsTapped:
                if let url = PlatformSupport.notificationSettingsURL {
                    return .run { @MainActor _ in
                        PlatformSupport.open(url)
                    }
                }
                return .none

            case .onAppear:
                state.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                state.isDebugSectionVisible = false
                let diagnostics = CloudKitSyncDiagnostics.snapshot()
                state.cloudDiagnosticsSummary = diagnostics.summary
                state.cloudDiagnosticsTimestamp = diagnostics.timestampText
                state.pushDiagnosticsStatus = diagnostics.pushStatus
                return .run { @MainActor send in
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    let systemEnabled = settings.authorizationStatus == .authorized
                    send(.systemNotificationPermissionChecked(systemEnabled))
                }

            case .contactUsTapped:
                if let emailURL = URL(string: "mailto:h.qadirian@gmail.com") {
                    return .run { @MainActor _ in
                        PlatformSupport.open(emailURL)
                    }
                }
                return .none

            case .aboutSectionLongPressed:
                state.isDebugSectionVisible = true
                return .none

            case let .systemNotificationPermissionChecked(value):
                state.systemSettingsNotificationsEnabled = value
                return .none

            case .cloudDiagnosticsUpdated:
                let diagnostics = CloudKitSyncDiagnostics.snapshot()
                state.cloudDiagnosticsSummary = diagnostics.summary
                state.cloudDiagnosticsTimestamp = diagnostics.timestampText
                state.pushDiagnosticsStatus = diagnostics.pushStatus
                return .none

            case .onAppBecameActive:
                return .run { @MainActor send in
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    let systemEnabled = settings.authorizationStatus == .authorized
                    send(.systemNotificationPermissionChecked(systemEnabled))
                }

            case .syncNowTapped:
                guard !state.isCloudDataResetInProgress else {
                    return .none
                }
                guard state.cloudSyncAvailable else {
                    state.cloudStatusMessage = "iCloud sync is disabled in this build."
                    return .none
                }

                state.isCloudSyncInProgress = true
                state.cloudStatusMessage = "Syncing with iCloud..."
                return .run { @MainActor send in
                    do {
                        let context = modelContext()
                        if context.hasChanges {
                            try context.save()
                        }
                        if let containerIdentifier = AppEnvironment.cloudKitContainerIdentifier {
                            try await CloudKitDirectPullService.pullLatestIntoLocalStore(
                                containerIdentifier: containerIdentifier,
                                modelContext: context
                            )
                        }
                        NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
                        await send(
                            .cloudSyncFinished(
                                success: true,
                                message: "Sync completed."
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

            case let .setCloudDataResetConfirmation(isPresented):
                state.isCloudDataResetConfirmationPresented = isPresented
                return .none

            case .resetCloudDataConfirmed:
                state.isCloudDataResetConfirmationPresented = false

                guard !state.isCloudSyncInProgress,
                      !state.isCloudDataResetInProgress
                else {
                    return .none
                }

                guard state.cloudSyncAvailable,
                      let cloudContainerIdentifier = AppEnvironment.cloudKitContainerIdentifier
                else {
                    state.cloudStatusMessage = "iCloud sync is disabled in this build."
                    return .none
                }

                state.isCloudDataResetInProgress = true
                state.cloudStatusMessage = "Deleting iCloud data..."
                return .run { @MainActor send in
                    do {
                        try await CloudDataResetService.resetAllUserData(
                            cloudKitContainerIdentifier: cloudContainerIdentifier,
                            modelContext: modelContext()
                        )
                        NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
                        await send(
                            .cloudDataResetFinished(
                                success: true,
                                message: "All Routina data was deleted from iCloud and this device."
                            )
                        )
                    } catch {
                        await send(
                            .cloudDataResetFinished(
                                success: false,
                                message: cloudDataResetErrorMessage(for: error)
                            )
                        )
                    }
                }

            case let .cloudSyncFinished(_, message):
                state.isCloudSyncInProgress = false
                state.cloudStatusMessage = message
                return .none

            case let .cloudDataResetFinished(_, message):
                state.isCloudDataResetInProgress = false
                state.cloudStatusMessage = message
                return .none
            }
        }
    }

    private func cloudDataResetErrorMessage(for error: Error) -> String {
        guard let cloudError = error as? CKError else {
            return "Data reset failed: \(error.localizedDescription)"
        }

        switch cloudError.code {
        case .notAuthenticated:
            return "Please sign in to iCloud and try again."
        case .networkUnavailable, .networkFailure:
            return "Network issue while deleting iCloud data. Please try again."
        case .serviceUnavailable, .requestRateLimited:
            return "iCloud is temporarily unavailable. Please try again shortly."
        default:
            return "Data reset failed: \(cloudError.localizedDescription)"
        }
    }
}

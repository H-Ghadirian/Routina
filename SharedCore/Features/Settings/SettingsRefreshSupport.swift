import Foundation

struct SettingsOnAppearSnapshot: Equatable {
    var appVersion: String
    var dataModeDescription: String
    var iCloudContainerDescription: String
    var cloudSyncAvailable: Bool
    var gitHubConnection: GitHubConnectionStatus
    var gitLabConnection: GitLabConnectionStatus
    var notificationsEnabled: Bool
    var notificationReminderTime: Date
    var routineListSectioningMode: RoutineListSectioningMode
    var tagCounterDisplayMode: TagCounterDisplayMode
    var appColorScheme: AppColorScheme
    var appLockEnabled: Bool
    var gitFeaturesEnabled: Bool
    var showPersianDates: Bool
    var deviceAuthenticationStatus: DeviceAuthenticationStatus
    var selectedAppIcon: AppIconOption
    var hasTemporaryViewStateToReset: Bool
    var cloudDiagnosticsSummary: String
    var cloudDiagnosticsTimestamp: String
    var pushDiagnosticsStatus: String
}

enum SettingsRefreshEditor {
    static func hydrateOnAppear(
        _ snapshot: SettingsOnAppearSnapshot,
        state: inout SettingsFeatureState
    ) {
        state.diagnostics.appVersion = snapshot.appVersion
        state.diagnostics.dataModeDescription = snapshot.dataModeDescription
        state.diagnostics.iCloudContainerDescription = snapshot.iCloudContainerDescription
        state.diagnostics.isDebugSectionVisible = false
        state.diagnostics.cloudDiagnosticsSummary = snapshot.cloudDiagnosticsSummary
        state.diagnostics.cloudDiagnosticsTimestamp = snapshot.cloudDiagnosticsTimestamp
        state.diagnostics.pushDiagnosticsStatus = snapshot.pushDiagnosticsStatus
        state.cloud.cloudSyncAvailable = snapshot.cloudSyncAvailable
        state.github.scope = snapshot.gitHubConnection.scope
        state.github.connectedScope = snapshot.gitHubConnection.scope
        state.github.repositoryOwner = snapshot.gitHubConnection.repository?.owner ?? ""
        state.github.repositoryName = snapshot.gitHubConnection.repository?.name ?? ""
        state.github.connectedRepository = snapshot.gitHubConnection.repository
        state.github.connectedViewerLogin = snapshot.gitHubConnection.viewerLogin
        state.github.hasSavedAccessToken = snapshot.gitHubConnection.hasAccessToken
        state.github.accessTokenDraft = ""
        state.github.isOperationInProgress = false
        state.github.statusMessage = ""
        state.gitlab.connectedUsername = snapshot.gitLabConnection.username
        state.gitlab.hasSavedAccessToken = snapshot.gitLabConnection.hasAccessToken
        state.gitlab.accessTokenDraft = ""
        state.gitlab.isOperationInProgress = false
        state.gitlab.statusMessage = ""

        SettingsNotificationsEditor.refreshFromSettings(
            notificationsEnabled: snapshot.notificationsEnabled,
            reminderTime: snapshot.notificationReminderTime,
            state: &state.notifications
        )
        SettingsAppearanceEditor.updateRoutineListSectioningMode(
            snapshot.routineListSectioningMode,
            state: &state.appearance
        )
        SettingsAppearanceEditor.updateTagCounterDisplayMode(
            snapshot.tagCounterDisplayMode,
            state: &state.appearance
        )
        SettingsAppearanceEditor.refreshFromSettings(
            appColorScheme: snapshot.appColorScheme,
            appLockEnabled: snapshot.appLockEnabled,
            gitFeaturesEnabled: snapshot.gitFeaturesEnabled,
            showPersianDates: snapshot.showPersianDates,
            deviceAuthenticationStatus: snapshot.deviceAuthenticationStatus,
            selectedAppIcon: snapshot.selectedAppIcon,
            hasTemporaryViewStateToReset: snapshot.hasTemporaryViewStateToReset,
            state: &state.appearance
        )
    }

    static func refreshOnAppBecameActive(
        hasTemporaryViewStateToReset: Bool,
        appLockEnabled: Bool,
        gitFeaturesEnabled: Bool,
        deviceAuthenticationStatus: DeviceAuthenticationStatus,
        state: inout SettingsFeatureState
    ) {
        state.appearance.hasTemporaryViewStateToReset = hasTemporaryViewStateToReset
        state.appearance.isAppLockEnabled = appLockEnabled
        state.appearance.isGitFeaturesEnabled = gitFeaturesEnabled
        state.appearance.appLockMethodDescription = deviceAuthenticationStatus.methodDescription
        state.appearance.appLockUnavailableReason = deviceAuthenticationStatus.unavailableReason
    }
}

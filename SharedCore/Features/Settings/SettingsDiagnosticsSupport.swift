import Foundation

enum SettingsDiagnosticsLoader {
    static func makeOnAppearSnapshot(
        appInfoClient: AppInfoClient,
        appSettingsClient: AppSettingsClient,
        gitHubConnection: GitHubConnectionStatus
    ) -> SettingsOnAppearSnapshot {
        let diagnostics = CloudKitSyncDiagnostics.snapshot()
        return SettingsOnAppearSnapshot(
            appVersion: appInfoClient.versionString(),
            dataModeDescription: appInfoClient.dataModeDescription(),
            iCloudContainerDescription: appInfoClient.cloudContainerDescription(),
            cloudSyncAvailable: appInfoClient.isCloudSyncEnabled(),
            gitHubConnection: gitHubConnection,
            notificationsEnabled: appSettingsClient.notificationsEnabled(),
            notificationReminderTime: appSettingsClient.notificationReminderTime(),
            routineListSectioningMode: appSettingsClient.routineListSectioningMode(),
            tagCounterDisplayMode: appSettingsClient.tagCounterDisplayMode(),
            selectedAppIcon: appSettingsClient.selectedAppIcon(),
            hasTemporaryViewStateToReset: SettingsExecutionSupport.hasTemporaryViewStateToReset(
                appSettingsClient: appSettingsClient
            ),
            cloudDiagnosticsSummary: diagnostics.summary,
            cloudDiagnosticsTimestamp: diagnostics.timestampText,
            pushDiagnosticsStatus: diagnostics.pushStatus
        )
    }

    static func refreshCloudDiagnostics(
        state: inout SettingsDiagnosticsState
    ) {
        let diagnostics = CloudKitSyncDiagnostics.snapshot()
        state.cloudDiagnosticsSummary = diagnostics.summary
        state.cloudDiagnosticsTimestamp = diagnostics.timestampText
        state.pushDiagnosticsStatus = diagnostics.pushStatus
    }
}

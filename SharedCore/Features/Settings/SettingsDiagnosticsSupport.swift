import Foundation

enum SettingsDiagnosticsLoader {
    static func makeOnAppearSnapshot(
        appInfoClient: AppInfoClient,
        appSettingsClient: AppSettingsClient,
        deviceAuthenticationClient: DeviceAuthenticationClient,
        gitHubConnection: GitHubConnectionStatus,
        gitLabConnection: GitLabConnectionStatus
    ) -> SettingsOnAppearSnapshot {
        let diagnostics = CloudKitSyncDiagnostics.snapshot()
        return SettingsOnAppearSnapshot(
            appVersion: appInfoClient.versionString(),
            dataModeDescription: appInfoClient.dataModeDescription(),
            iCloudContainerDescription: appInfoClient.cloudContainerDescription(),
            cloudSyncAvailable: appInfoClient.isCloudSyncEnabled(),
            gitHubConnection: gitHubConnection,
            gitLabConnection: gitLabConnection,
            notificationsEnabled: appSettingsClient.notificationsEnabled(),
            notificationReminderTime: appSettingsClient.notificationReminderTime(),
            routineListSectioningMode: appSettingsClient.routineListSectioningMode(),
            tagCounterDisplayMode: appSettingsClient.tagCounterDisplayMode(),
            taskRowVisibility: appSettingsClient.taskRowVisibility(),
            timelineRowVisibility: appSettingsClient.timelineRowVisibility(),
            appColorScheme: appSettingsClient.appColorScheme(),
            appLockEnabled: appSettingsClient.appLockEnabled(),
            gitFeaturesEnabled: appSettingsClient.gitFeaturesEnabled(),
            taskSharingEnabled: appSettingsClient.taskSharingEnabled(),
            taskRelationshipVisualizerEnabled: appSettingsClient.taskRelationshipVisualizerEnabled(),
            placesEnabled: appSettingsClient.placesEnabled(),
            notesEnabled: appSettingsClient.notesEnabled(),
            awayEnabled: appSettingsClient.awayEnabled(),
            showPersianDates: appSettingsClient.showPersianDates(),
            automaticPlaceCheckInEnabled: appSettingsClient.automaticPlaceCheckInEnabled(),
            showTimelineTasksInDayPlanner: appSettingsClient.showTimelineTasksInDayPlanner(),
            separateDailyRoutinesInTaskList: appSettingsClient.separateDailyRoutinesInTaskList(),
            deviceAuthenticationStatus: deviceAuthenticationClient.status(),
            selectedAppIcon: appSettingsClient.selectedAppIcon(),
            hasTemporaryViewStateToReset: SettingsExecutionSupport.hasTemporaryViewStateToReset(
                appSettingsClient: appSettingsClient
            ),
            lastRoutineDataBackupDate: appSettingsClient.lastRoutineDataBackupDate(),
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

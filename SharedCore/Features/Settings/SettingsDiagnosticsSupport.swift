import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

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
            buildNumber: appInfoClient.buildNumber(),
            operatingSystemDescription: appInfoClient.operatingSystemDescription(),
            dataModeDescription: appInfoClient.dataModeDescription(),
            iCloudContainerDescription: appInfoClient.cloudContainerDescription(),
            signedCloudKitEnvironmentDescription: appInfoClient.signedCloudKitEnvironmentDescription(),
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
            filterQuerySectionsEnabled: appSettingsClient.filterQuerySectionsEnabled(),
            showPersianDates: appSettingsClient.showPersianDates(),
            automaticPlaceCheckInEnabled: appSettingsClient.automaticPlaceCheckInEnabled(),
            showTimelineTasksInDayPlanner: appSettingsClient.showTimelineTasksInDayPlanner(),
            separateDailyRoutinesInTaskList: appSettingsClient.separateDailyRoutinesInTaskList(),
            showTomorrowInTaskList: appSettingsClient.showTomorrowInTaskList(),
            showDoneCountInToolbar: appSettingsClient.showDoneCountInToolbar(),
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

enum SettingsDiagnosticsReport {
    static func text(for diagnostics: SettingsDiagnosticsState) -> String {
        [
            "Routina Diagnostics",
            "App Version: \(diagnostics.appVersion)",
            "Build Number: \(diagnostics.buildNumber)",
            "Operating System: \(diagnostics.operatingSystemDescription)",
            "Data Mode: \(diagnostics.dataModeDescription)",
            "iCloud Container: \(diagnostics.iCloudContainerDescription)",
            "Signed CloudKit Environment: \(diagnostics.signedCloudKitEnvironmentDescription)",
            "Last CloudKit Event: \(diagnostics.cloudDiagnosticsTimestamp)",
            "CloudKit Detail: \(diagnostics.cloudDiagnosticsSummary)",
            "Push Status: \(diagnostics.pushDiagnosticsStatus)"
        ].joined(separator: "\n")
    }
}

enum SettingsDiagnosticsClipboard {
    @MainActor
    static func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif
    }
}

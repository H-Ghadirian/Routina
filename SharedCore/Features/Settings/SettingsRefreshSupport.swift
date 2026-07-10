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
    var taskRowVisibility: HomeTaskRowVisibility
    var timelineRowVisibility: HomeTimelineRowVisibility
    var appColorScheme: AppColorScheme
    var appLockEnabled: Bool
    var gitFeaturesEnabled: Bool
    var taskSharingEnabled: Bool
    var taskRelationshipVisualizerEnabled: Bool
    var placesEnabled: Bool
    var notesEnabled: Bool
    var awayEnabled: Bool
    var filterQuerySectionsEnabled: Bool
    var unlockUnlimitedTasks: Bool
    var showPersianDates: Bool
    var automaticPlaceCheckInEnabled: Bool
    var showTimelineTasksInDayPlanner: Bool
    var separateDailyRoutinesInTaskList: Bool
    var showTomorrowInTaskList: Bool
    var showDoneCountInToolbar: Bool
    var deviceAuthenticationStatus: DeviceAuthenticationStatus
    var selectedAppIcon: AppIconOption
    var hasTemporaryViewStateToReset: Bool
    var lastRoutineDataBackupDate: Date?
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
        state.dataTransfer.lastSuccessfulBackupDate = snapshot.lastRoutineDataBackupDate
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
        state.places.isAutomaticCheckInEnabled = snapshot.automaticPlaceCheckInEnabled

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
        SettingsAppearanceEditor.updateTaskRowVisibility(
            snapshot.taskRowVisibility,
            state: &state.appearance
        )
        SettingsAppearanceEditor.updateTimelineRowVisibility(
            snapshot.timelineRowVisibility,
            state: &state.appearance
        )
        SettingsAppearanceEditor.refreshFromSettings(
            appColorScheme: snapshot.appColorScheme,
            appLockEnabled: snapshot.appLockEnabled,
            gitFeaturesEnabled: snapshot.gitFeaturesEnabled,
            taskSharingEnabled: snapshot.taskSharingEnabled,
            taskRelationshipVisualizerEnabled: snapshot.taskRelationshipVisualizerEnabled,
            placesEnabled: snapshot.placesEnabled,
            notesEnabled: snapshot.notesEnabled,
            awayEnabled: snapshot.awayEnabled,
            filterQuerySectionsEnabled: snapshot.filterQuerySectionsEnabled,
            unlockUnlimitedTasks: snapshot.unlockUnlimitedTasks,
            showPersianDates: snapshot.showPersianDates,
            showTimelineTasksInDayPlanner: snapshot.showTimelineTasksInDayPlanner,
            separateDailyRoutinesInTaskList: snapshot.separateDailyRoutinesInTaskList,
            showTomorrowInTaskList: snapshot.showTomorrowInTaskList,
            showDoneCountInToolbar: snapshot.showDoneCountInToolbar,
            taskRowVisibility: snapshot.taskRowVisibility,
            timelineRowVisibility: snapshot.timelineRowVisibility,
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
        taskSharingEnabled: Bool,
        taskRelationshipVisualizerEnabled: Bool,
        placesEnabled: Bool,
        notesEnabled: Bool,
        awayEnabled: Bool,
        filterQuerySectionsEnabled: Bool,
        unlockUnlimitedTasks: Bool,
        lastRoutineDataBackupDate: Date?,
        deviceAuthenticationStatus: DeviceAuthenticationStatus,
        state: inout SettingsFeatureState
    ) {
        state.appearance.hasTemporaryViewStateToReset = hasTemporaryViewStateToReset
        state.appearance.isAppLockEnabled = appLockEnabled
        state.appearance.isGitFeaturesEnabled = gitFeaturesEnabled
        state.appearance.isTaskSharingEnabled = taskSharingEnabled
        state.appearance.isTaskRelationshipVisualizerEnabled = taskRelationshipVisualizerEnabled
        state.appearance.isPlacesEnabled = placesEnabled
        state.appearance.isNotesEnabled = notesEnabled
        state.appearance.isAwayEnabled = awayEnabled
        state.appearance.showsFilterQuerySections = filterQuerySectionsEnabled
        state.appearance.unlocksUnlimitedTasks = unlockUnlimitedTasks
        state.dataTransfer.lastSuccessfulBackupDate = lastRoutineDataBackupDate
        state.appearance.appLockMethodDescription = deviceAuthenticationStatus.methodDescription
        state.appearance.appLockUnavailableReason = deviceAuthenticationStatus.unavailableReason
    }
}

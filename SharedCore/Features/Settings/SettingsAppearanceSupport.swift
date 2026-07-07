import Foundation

enum SettingsAppearanceEditor {
    static func updateAppColorScheme(
        _ scheme: AppColorScheme,
        state: inout SettingsAppearanceState
    ) {
        state.appColorScheme = scheme
    }

    static func updateRoutineListSectioningMode(
        _ mode: RoutineListSectioningMode,
        state: inout SettingsAppearanceState
    ) {
        state.routineListSectioningMode = mode.availableValue
    }

    static func updateTagCounterDisplayMode(
        _ mode: TagCounterDisplayMode,
        state: inout SettingsAppearanceState
    ) {
        state.tagCounterDisplayMode = mode
    }

    static func updateTaskRowVisibility(
        _ visibility: HomeTaskRowVisibility,
        state: inout SettingsAppearanceState
    ) {
        state.taskRowVisibility = visibility
    }

    static func updateTaskRowField(
        _ field: HomeTaskRowField,
        isVisible: Bool,
        state: inout SettingsAppearanceState
    ) {
        state.taskRowVisibility = state.taskRowVisibility.setting(field, visible: isVisible)
    }

    static func updateTimelineRowVisibility(
        _ visibility: HomeTimelineRowVisibility,
        state: inout SettingsAppearanceState
    ) {
        state.timelineRowVisibility = visibility
    }

    static func updateTimelineRowField(
        _ field: HomeTimelineRowField,
        isVisible: Bool,
        state: inout SettingsAppearanceState
    ) {
        state.timelineRowVisibility = state.timelineRowVisibility.setting(field, visible: isVisible)
    }

    static func refreshFromSettings(
        appColorScheme: AppColorScheme,
        appLockEnabled: Bool,
        gitFeaturesEnabled: Bool,
        taskSharingEnabled: Bool,
        taskRelationshipVisualizerEnabled: Bool,
        placesEnabled: Bool,
        notesEnabled: Bool,
        awayEnabled: Bool,
        filterQuerySectionsEnabled: Bool,
        unlockUnlimitedTasks: Bool,
        showPersianDates: Bool,
        showTimelineTasksInDayPlanner: Bool,
        separateDailyRoutinesInTaskList: Bool,
        showTomorrowInTaskList: Bool,
        taskRowVisibility: HomeTaskRowVisibility,
        timelineRowVisibility: HomeTimelineRowVisibility,
        deviceAuthenticationStatus: DeviceAuthenticationStatus,
        selectedAppIcon: AppIconOption,
        hasTemporaryViewStateToReset: Bool,
        state: inout SettingsAppearanceState
    ) {
        state.appColorScheme = appColorScheme
        state.isAppLockEnabled = appLockEnabled
        state.isGitFeaturesEnabled = gitFeaturesEnabled
        state.isTaskSharingEnabled = taskSharingEnabled
        state.isTaskRelationshipVisualizerEnabled = taskRelationshipVisualizerEnabled
        state.isPlacesEnabled = placesEnabled
        state.isNotesEnabled = notesEnabled
        state.isAwayEnabled = awayEnabled
        state.showsFilterQuerySections = filterQuerySectionsEnabled
        state.unlocksUnlimitedTasks = unlockUnlimitedTasks
        state.showPersianDates = showPersianDates
        state.showsTimelineTasksInDayPlanner = showTimelineTasksInDayPlanner
        state.separatesDailyRoutinesInTaskList = separateDailyRoutinesInTaskList
        state.showsTomorrowInTaskList = showTomorrowInTaskList
        state.taskRowVisibility = taskRowVisibility
        state.isAppLockToggleInProgress = false
        state.appLockMethodDescription = deviceAuthenticationStatus.methodDescription
        state.appLockUnavailableReason = deviceAuthenticationStatus.unavailableReason
        state.appLockStatusMessage = ""
        state.selectedAppIcon = selectedAppIcon
        state.timelineRowVisibility = timelineRowVisibility
        state.hasTemporaryViewStateToReset = hasTemporaryViewStateToReset
        state.appIconStatusMessage = ""
        state.temporaryViewStateStatusMessage = ""
        state.isSettingsResetAuthenticationInProgress = false
    }

    static func resetTemporaryViewState(
        state: inout SettingsAppearanceState
    ) {
        state.hasTemporaryViewStateToReset = false
        state.temporaryViewStateStatusMessage = "Saved filters and temporary selections were reset."
    }

    static func beginSettingsResetAuthentication(
        appLockEnabled: Bool,
        deviceAuthenticationStatus: DeviceAuthenticationStatus,
        state: inout SettingsAppearanceState
    ) -> Bool {
        state.appLockMethodDescription = deviceAuthenticationStatus.methodDescription
        state.appLockUnavailableReason = deviceAuthenticationStatus.unavailableReason
        state.settingsResetStatusMessage = ""

        guard appLockEnabled else {
            state.settingsResetStatusMessage = "Turn on App Lock before resetting settings."
            state.isSettingsResetAuthenticationInProgress = false
            return false
        }

        guard deviceAuthenticationStatus.isAvailable else {
            state.settingsResetStatusMessage = deviceAuthenticationStatus.unavailableReason
                ?? "Device authentication is unavailable."
            state.isSettingsResetAuthenticationInProgress = false
            return false
        }

        state.isSettingsResetAuthenticationInProgress = true
        return true
    }

    static func finishSettingsResetAuthentication(
        _ result: DeviceAuthenticationResult,
        state: inout SettingsAppearanceState
    ) -> Bool {
        state.isSettingsResetAuthenticationInProgress = false
        switch result {
        case .success:
            return true
        case .failure(let message):
            state.settingsResetStatusMessage = message
            return false
        }
    }

    static func resetAllSettingsToDefaults(
        deviceAuthenticationStatus: DeviceAuthenticationStatus,
        notificationReminderTime: Date,
        state: inout SettingsFeatureState
    ) {
        state.notifications = SettingsNotificationsState(notificationReminderTime: notificationReminderTime)
        state.appearance = SettingsAppearanceState(
            appLockMethodDescription: deviceAuthenticationStatus.methodDescription,
            appLockUnavailableReason: deviceAuthenticationStatus.unavailableReason,
            settingsResetStatusMessage: "Settings were reset to defaults."
        )
        state.places.isAutomaticCheckInEnabled = true
        state.tags.fastFilterTags = []
        state.tags.tagColors = [:]
        state.tags.relatedTagRules = []
        state.tags.relatedTagDrafts = [:]
        state.dataTransfer.dataTransferStatusMessage = ""
    }

    static func beginAppIconChange(
        state: inout SettingsAppearanceState
    ) {
        state.appIconStatusMessage = ""
    }

    static func beginAppLockToggle(
        requiresAuthentication: Bool,
        deviceAuthenticationStatus: DeviceAuthenticationStatus,
        state: inout SettingsAppearanceState
    ) {
        state.appLockMethodDescription = deviceAuthenticationStatus.methodDescription
        state.appLockUnavailableReason = deviceAuthenticationStatus.unavailableReason
        state.appLockStatusMessage = ""
        state.isAppLockToggleInProgress = requiresAuthentication && deviceAuthenticationStatus.isAvailable
    }

    static func finishAppLockToggle(
        enabled: Bool,
        message: String?,
        deviceAuthenticationStatus: DeviceAuthenticationStatus,
        state: inout SettingsAppearanceState
    ) {
        state.isAppLockEnabled = enabled
        state.isAppLockToggleInProgress = false
        state.appLockMethodDescription = deviceAuthenticationStatus.methodDescription
        state.appLockUnavailableReason = deviceAuthenticationStatus.unavailableReason
        state.appLockStatusMessage = message ?? ""
    }

    static func finishAppIconChange(
        requestedOption: AppIconOption,
        errorMessage: String?,
        state: inout SettingsAppearanceState
    ) {
        if let errorMessage {
            state.appIconStatusMessage = "App icon update failed: \(errorMessage)"
        } else {
            state.selectedAppIcon = requestedOption
            AppIconOption.persist(requestedOption)
        }
    }
}

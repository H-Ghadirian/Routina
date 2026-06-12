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
        state.routineListSectioningMode = mode
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
        showPersianDates: Bool,
        showTimelineTasksInDayPlanner: Bool,
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
        state.showPersianDates = showPersianDates
        state.showsTimelineTasksInDayPlanner = showTimelineTasksInDayPlanner
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
    }

    static func resetTemporaryViewState(
        state: inout SettingsAppearanceState
    ) {
        state.hasTemporaryViewStateToReset = false
        state.temporaryViewStateStatusMessage = "Saved filters and temporary selections were reset."
    }

    static func beginAppIconChange(
        state: inout SettingsAppearanceState
    ) {
        state.appIconStatusMessage = ""
    }

    static func beginAppLockToggle(
        enabling: Bool,
        deviceAuthenticationStatus: DeviceAuthenticationStatus,
        state: inout SettingsAppearanceState
    ) {
        state.appLockMethodDescription = deviceAuthenticationStatus.methodDescription
        state.appLockUnavailableReason = deviceAuthenticationStatus.unavailableReason
        state.appLockStatusMessage = ""
        state.isAppLockToggleInProgress = enabling && deviceAuthenticationStatus.isAvailable
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

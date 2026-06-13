import ComposableArchitecture
import Foundation

enum SettingsAppearanceActionHandler {
    static func appColorSchemeChanged(
        _ scheme: AppColorScheme,
        state: inout SettingsAppearanceState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        SettingsAppearanceEditor.updateAppColorScheme(scheme, state: &state)
        appSettingsClient.setAppColorScheme(scheme)
        return .none
    }

    static func routineListSectioningModeChanged(
        _ mode: RoutineListSectioningMode,
        state: inout SettingsAppearanceState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        SettingsAppearanceEditor.updateRoutineListSectioningMode(mode, state: &state)
        appSettingsClient.setRoutineListSectioningMode(mode)
        return .none
    }

    static func tagCounterDisplayModeChanged(
        _ mode: TagCounterDisplayMode,
        state: inout SettingsAppearanceState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        SettingsAppearanceEditor.updateTagCounterDisplayMode(mode, state: &state)
        appSettingsClient.setTagCounterDisplayMode(mode)
        return .none
    }

    static func taskRowFieldVisibilityChanged(
        _ field: HomeTaskRowField,
        isVisible: Bool,
        state: inout SettingsAppearanceState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        SettingsAppearanceEditor.updateTaskRowField(
            field,
            isVisible: isVisible,
            state: &state
        )
        appSettingsClient.setTaskRowVisibility(state.taskRowVisibility)
        return .none
    }

    static func timelineRowFieldVisibilityChanged(
        _ field: HomeTimelineRowField,
        isVisible: Bool,
        state: inout SettingsAppearanceState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        SettingsAppearanceEditor.updateTimelineRowField(
            field,
            isVisible: isVisible,
            state: &state
        )
        appSettingsClient.setTimelineRowVisibility(state.timelineRowVisibility)
        return .none
    }

    static func appLockToggled(
        _ isEnabled: Bool,
        state: inout SettingsAppearanceState,
        appSettingsClient: AppSettingsClient,
        deviceAuthenticationClient: DeviceAuthenticationClient
    ) -> Effect<SettingsFeature.Action> {
        let authenticationStatus = deviceAuthenticationClient.status()
        SettingsAppearanceEditor.beginAppLockToggle(
            requiresAuthentication: true,
            deviceAuthenticationStatus: authenticationStatus,
            state: &state
        )

        let unavailableMessage = isEnabled
            ? authenticationStatus.unavailableReason ?? "Device authentication is unavailable."
            : "Device authentication is unavailable, so App Lock stays on."

        guard authenticationStatus.isAvailable else {
            SettingsAppearanceEditor.finishAppLockToggle(
                enabled: state.isAppLockEnabled,
                message: unavailableMessage,
                deviceAuthenticationStatus: authenticationStatus,
                state: &state
            )
            return .none
        }

        return .run { send in
            let reason = isEnabled
                ? "Enable app lock for Routina"
                : "Disable app lock for Routina"
            let result = await deviceAuthenticationClient.authenticate(reason)
            let action: SettingsFeature.Action = isEnabled
                ? .appLockEnableFinished(result)
                : .appLockDisableFinished(result)
            await send(action)
        }
    }

    static func appLockEnableFinished(
        _ result: DeviceAuthenticationResult,
        state: inout SettingsAppearanceState,
        appSettingsClient: AppSettingsClient,
        deviceAuthenticationClient: DeviceAuthenticationClient
    ) -> Effect<SettingsFeature.Action> {
        let authenticationStatus = deviceAuthenticationClient.status()
        switch result {
        case .success:
            appSettingsClient.setAppLockEnabled(true)
            SettingsAppearanceEditor.finishAppLockToggle(
                enabled: true,
                message: "App lock is on.",
                deviceAuthenticationStatus: authenticationStatus,
                state: &state
            )
        case .failure(let message):
            SettingsAppearanceEditor.finishAppLockToggle(
                enabled: false,
                message: message,
                deviceAuthenticationStatus: authenticationStatus,
                state: &state
            )
        }
        return .none
    }

    static func appLockDisableFinished(
        _ result: DeviceAuthenticationResult,
        state: inout SettingsAppearanceState,
        appSettingsClient: AppSettingsClient,
        deviceAuthenticationClient: DeviceAuthenticationClient
    ) -> Effect<SettingsFeature.Action> {
        let authenticationStatus = deviceAuthenticationClient.status()
        switch result {
        case .success:
            appSettingsClient.setAppLockEnabled(false)
            SettingsAppearanceEditor.finishAppLockToggle(
                enabled: false,
                message: "App lock is off.",
                deviceAuthenticationStatus: authenticationStatus,
                state: &state
            )
        case .failure(let message):
            SettingsAppearanceEditor.finishAppLockToggle(
                enabled: true,
                message: message,
                deviceAuthenticationStatus: authenticationStatus,
                state: &state
            )
        }
        return .none
    }

    static func gitFeaturesToggled(
        _ isEnabled: Bool,
        state: inout SettingsAppearanceState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        state.isGitFeaturesEnabled = isEnabled
        appSettingsClient.setGitFeaturesEnabled(isEnabled)
        return .none
    }

    static func showPersianDatesToggled(
        _ isEnabled: Bool,
        state: inout SettingsAppearanceState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        state.showPersianDates = isEnabled
        appSettingsClient.setShowPersianDates(isEnabled)
        return .none
    }

    static func showTimelineTasksInDayPlannerToggled(
        _ isEnabled: Bool,
        state: inout SettingsAppearanceState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        state.showsTimelineTasksInDayPlanner = isEnabled
        appSettingsClient.setShowTimelineTasksInDayPlanner(isEnabled)
        return .none
    }

    static func resetTemporaryViewStateTapped(
        state: inout SettingsAppearanceState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        appSettingsClient.resetTemporaryViewState()
        SettingsAppearanceEditor.resetTemporaryViewState(state: &state)
        return .none
    }
}

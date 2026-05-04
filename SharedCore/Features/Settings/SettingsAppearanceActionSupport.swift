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

    static func appLockToggled(
        _ isEnabled: Bool,
        state: inout SettingsAppearanceState,
        appSettingsClient: AppSettingsClient,
        deviceAuthenticationClient: DeviceAuthenticationClient
    ) -> Effect<SettingsFeature.Action> {
        let authenticationStatus = deviceAuthenticationClient.status()
        SettingsAppearanceEditor.beginAppLockToggle(
            enabling: isEnabled,
            deviceAuthenticationStatus: authenticationStatus,
            state: &state
        )

        guard isEnabled else {
            appSettingsClient.setAppLockEnabled(false)
            SettingsAppearanceEditor.finishAppLockToggle(
                enabled: false,
                message: "",
                deviceAuthenticationStatus: authenticationStatus,
                state: &state
            )
            return .none
        }

        guard authenticationStatus.isAvailable else {
            SettingsAppearanceEditor.finishAppLockToggle(
                enabled: false,
                message: authenticationStatus.unavailableReason
                    ?? "Device authentication is unavailable.",
                deviceAuthenticationStatus: authenticationStatus,
                state: &state
            )
            return .none
        }

        return .run { send in
            let result = await deviceAuthenticationClient.authenticate("Enable app lock for Routina")
            await send(.appLockEnableFinished(result))
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

    static func resetTemporaryViewStateTapped(
        state: inout SettingsAppearanceState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        appSettingsClient.resetTemporaryViewState()
        SettingsAppearanceEditor.resetTemporaryViewState(state: &state)
        return .none
    }
}

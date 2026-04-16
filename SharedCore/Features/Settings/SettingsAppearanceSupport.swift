import Foundation

enum SettingsAppearanceEditor {
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

    static func refreshFromSettings(
        selectedAppIcon: AppIconOption,
        hasTemporaryViewStateToReset: Bool,
        state: inout SettingsAppearanceState
    ) {
        state.selectedAppIcon = selectedAppIcon
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

import ComposableArchitecture
import Foundation

enum SettingsAppIconActionHandler {
    static func appIconSelected(
        _ option: AppIconOption,
        state: inout SettingsAppearanceState,
        appIconClient: AppIconClient
    ) -> Effect<SettingsFeature.Action> {
        SettingsAppearanceEditor.beginAppIconChange(state: &state)
        return .run { send in
            let errorMessage = await SettingsAppInteractionExecution.requestAppIconChange(
                option,
                appIconClient: appIconClient
            )
            await send(.appIconChangeFinished(requestedOption: option, errorMessage: errorMessage))
        }
    }

    static func appIconChangeFinished(
        requestedOption: AppIconOption,
        errorMessage: String?,
        state: inout SettingsAppearanceState
    ) -> Effect<SettingsFeature.Action> {
        SettingsAppearanceEditor.finishAppIconChange(
            requestedOption: requestedOption,
            errorMessage: errorMessage,
            state: &state
        )
        return .none
    }
}

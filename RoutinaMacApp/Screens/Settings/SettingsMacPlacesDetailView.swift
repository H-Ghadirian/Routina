import ComposableArchitecture
import SwiftUI

struct SettingsMacPlacesDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
SettingsMacDetailShell(
    title: "Places",
    subtitle: "Configure place-based automation behavior."
) {
    SettingsMacDetailCard(title: "Location") {
        Text(store.places.locationHelpText)
            .font(.footnote)
            .foregroundStyle(.secondary)

        Toggle("Auto check in at saved places", isOn: automaticCheckInBinding)
            .toggleStyle(.switch)

        Text("When enabled, Routina can start and end device-created check-ins when your current location enters or leaves a saved place.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        if !store.places.placeStatusMessage.isEmpty {
                Text(store.places.placeStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
        }
    }
}
    }

    private var automaticCheckInBinding: Binding<Bool> {
        Binding(
            get: { store.places.isAutomaticCheckInEnabled },
            set: { store.send(.automaticPlaceCheckInToggled($0)) }
        )
    }
}

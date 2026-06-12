import ComposableArchitecture
import SwiftUI

struct SettingsPlacesDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
List {
    Section("Location") {
        Text(store.places.locationHelpText)
            .foregroundStyle(.secondary)

        if store.places.locationAuthorizationStatus.needsSettingsChange {
            Button("Open System Settings") {
                store.send(.openLocationSettingsTapped)
            }
        }
    }

    Section("Automatic Check-In") {
        Toggle("Auto check in at saved places", isOn: automaticCheckInBinding)

        Text("When enabled, Routina can start and end device-created check-ins when your current location enters or leaves a saved place.")
            .foregroundStyle(.secondary)
    }

    if !store.places.placeStatusMessage.isEmpty {
        Section("Status") {
            Text(store.places.placeStatusMessage)
                .foregroundStyle(.secondary)
        }
    }
}
.listStyle(.insetGrouped)
.navigationTitle("Places")
.navigationBarTitleDisplayMode(.inline)
    }

    private var automaticCheckInBinding: Binding<Bool> {
        Binding(
            get: { store.places.isAutomaticCheckInEnabled },
            set: { store.send(.automaticPlaceCheckInToggled($0)) }
        )
    }
}

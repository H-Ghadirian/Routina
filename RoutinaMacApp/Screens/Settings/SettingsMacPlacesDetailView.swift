import ComposableArchitecture
import SwiftUI

struct SettingsMacPlacesDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
SettingsMacDetailShell(
    title: "Places"
) {
    VStack(alignment: .leading, spacing: 14) {
        Toggle("Auto check in at saved places", isOn: automaticCheckInBinding)
            .toggleStyle(.switch)
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

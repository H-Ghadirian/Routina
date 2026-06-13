import ComposableArchitecture
import SwiftUI

struct SettingsPlacesDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
List {
    Section {
        Toggle("Auto check in at saved places", isOn: automaticCheckInBinding)
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

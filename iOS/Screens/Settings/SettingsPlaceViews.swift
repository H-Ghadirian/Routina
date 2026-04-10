import ComposableArchitecture
import SwiftUI

struct SettingsPlaceManagerPresentationView: View {
    let store: StoreOf<SettingsFeature>
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            SettingsPlacesDetailView(store: store)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

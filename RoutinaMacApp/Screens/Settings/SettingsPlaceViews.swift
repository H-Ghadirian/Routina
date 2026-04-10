import ComposableArchitecture
import SwiftUI

struct SettingsPlaceManagerPresentationView: View {
    let store: StoreOf<SettingsFeature>
    @Environment(\.dismiss) var dismiss
    @State private var isPlacePickerPresented = false

    var body: some View {
        NavigationStack {
            SettingsMacPlacesDetailView(
                store: store,
                isPlacePickerPresented: $isPlacePickerPresented
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $isPlacePickerPresented) {
            PlaceLocationPickerSheet(
                initialCoordinate: store.placeDraftCoordinate,
                initialRadiusMeters: store.placeDraftRadiusMeters,
                fallbackCoordinate: store.placeDraftCoordinate ?? store.lastKnownLocationCoordinate
            ) { coordinate, radiusMeters in
                store.send(.placeDraftCoordinateChanged(coordinate))
                store.send(.placeDraftRadiusChanged(radiusMeters))
                isPlacePickerPresented = false
            } onCancel: {
                isPlacePickerPresented = false
            }
        }
        .alert(
            "Delete Place?",
            isPresented: deletePlaceConfirmationBinding
        ) {
            Button("Delete", role: .destructive) {
                store.send(.deletePlaceConfirmed)
            }
            Button("Cancel", role: .cancel) {
                store.send(.setDeletePlaceConfirmation(false))
            }
        } message: {
            Text(store.deletePlaceConfirmationMessage)
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    private var deletePlaceConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.isDeletePlaceConfirmationPresented },
            set: { store.send(.setDeletePlaceConfirmation($0)) }
        )
    }
}

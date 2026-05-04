import ComposableArchitecture
import SwiftUI

struct SettingsMacPresentationModifier: ViewModifier {
    let store: StoreOf<SettingsFeature>
    @Binding var isPlacePickerPresented: Bool

    func body(content: Content) -> some View {
        content
            .alert(
                "Delete iCloud Data?",
                isPresented: cloudDataResetConfirmationBinding
            ) {
                Button("Delete Data", role: .destructive) {
                    store.send(.resetCloudDataConfirmed)
                }
                Button("Cancel", role: .cancel) {
                    store.send(.setCloudDataResetConfirmation(false))
                }
            } message: {
                Text("This permanently deletes all Routina data from iCloud and from this device.")
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
                Text(store.places.deleteConfirmationMessage)
            }
            .sheet(isPresented: $isPlacePickerPresented) {
                PlaceLocationPickerSheet(
                    initialCoordinate: store.places.placeDraftCoordinate,
                    initialRadiusMeters: store.places.placeDraftRadiusMeters,
                    fallbackCoordinate: store.places.placeDraftCoordinate ?? store.places.lastKnownLocationCoordinate
                ) { coordinate, radiusMeters in
                    store.send(.placeDraftCoordinateChanged(coordinate))
                    store.send(.placeDraftRadiusChanged(radiusMeters))
                    isPlacePickerPresented = false
                } onCancel: {
                    isPlacePickerPresented = false
                }
            }
    }

    private var cloudDataResetConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.cloud.isCloudDataResetConfirmationPresented },
            set: { store.send(.setCloudDataResetConfirmation($0)) }
        )
    }

    private var deletePlaceConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.places.isDeletePlaceConfirmationPresented },
            set: { store.send(.setDeletePlaceConfirmation($0)) }
        )
    }
}

extension View {
    func settingsMacPresentations(
        store: StoreOf<SettingsFeature>,
        isPlacePickerPresented: Binding<Bool>
    ) -> some View {
        modifier(
            SettingsMacPresentationModifier(
                store: store,
                isPlacePickerPresented: isPlacePickerPresented
            )
        )
    }
}

import ComposableArchitecture
import SwiftUI

struct SettingsMacPresentationModifier: ViewModifier {
    let store: StoreOf<SettingsFeature>
    @Binding var isPlacePickerPresented: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: cloudDataResetConfirmationBinding) {
                SettingsMacCloudDataResetConfirmationSheet(store: store)
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

private struct SettingsMacCloudDataResetConfirmationSheet: View {
    let store: StoreOf<SettingsFeature>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
VStack(alignment: .leading, spacing: 18) {
    VStack(alignment: .leading, spacing: 6) {
        Text("Delete iCloud Data")
            .font(.title3.bold())
        Text("This permanently deletes all Routina data from iCloud and from this device.")
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    VStack(alignment: .leading, spacing: 8) {
        Text("Deletion Password")
            .font(.headline)

        SecureField("Create Password", text: passwordBinding)
        SecureField("Re-enter Password", text: passwordConfirmationBinding)

        Text(store.cloud.cloudDataResetPasswordStatusText)
            .font(.caption)
            .foregroundStyle(store.cloud.isCloudDataResetPasswordReady ? Color.secondary : Color.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    HStack {
        Spacer()
        Button("Cancel") {
            store.send(.setCloudDataResetConfirmation(false))
            dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Button("Delete", role: .destructive) {
            store.send(.resetCloudDataConfirmed)
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!store.cloud.isCloudDataResetPasswordReady)
    }
}
.padding(24)
.frame(width: 420)
    }

    private var passwordBinding: Binding<String> {
        Binding(
            get: { store.cloud.cloudDataResetPasswordDraft },
            set: { store.send(.cloudDataResetPasswordChanged($0)) }
        )
    }

    private var passwordConfirmationBinding: Binding<String> {
        Binding(
            get: { store.cloud.cloudDataResetPasswordConfirmationDraft },
            set: { store.send(.cloudDataResetPasswordConfirmationChanged($0)) }
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

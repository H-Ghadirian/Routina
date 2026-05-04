import ComposableArchitecture
import SwiftUI

struct SettingsMacPlacesDetailView: View {
    let store: StoreOf<SettingsFeature>
    @Binding var isPlacePickerPresented: Bool

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "Places",
                subtitle: "Save map areas that power place-based routines and keep them easy to manage."
            ) {
                SettingsMacDetailCard(title: "Add Place") {
                    TextField("Place name", text: placeDraftNameBinding)
                        .textFieldStyle(.roundedBorder)

                    if let validationMessage = store.places.saveValidationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    HStack(spacing: 12) {
                        Button {
                            isPlacePickerPresented = true
                        } label: {
                            Label(store.places.selectionButtonTitle, systemImage: "map")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            store.send(.savePlaceTapped)
                        } label: {
                            if store.places.isPlaceOperationInProgress {
                                ProgressView()
                            } else {
                                Label("Save Place", systemImage: "mappin.and.ellipse")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.places.isSaveDisabled)

                        if store.places.locationAuthorizationStatus.needsSettingsChange {
                            Button("Open System Settings") {
                                store.send(.openAppSettingsTapped)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Text(store.places.draftSelectionSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Location") {
                    Text(store.places.locationHelpText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !store.places.placeStatusMessage.isEmpty {
                        Text(store.places.placeStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                SettingsMacDetailCard(title: "Saved Places") {
                    if store.places.savedPlaces.isEmpty {
                        Text("No places saved yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.places.savedPlaces.enumerated()), id: \.element.id) { index, place in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(place.name)
                                        Text(place.settingsSubtitle)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button(role: .destructive) {
                                        store.send(.deletePlaceTapped(place.id))
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(store.places.isPlaceOperationInProgress)
                                }
                                .padding(.vertical, 12)

                                if index < store.places.savedPlaces.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var placeDraftNameBinding: Binding<String> {
        Binding(
            get: { store.places.placeDraftName },
            set: { store.send(.placeDraftNameChanged($0)) }
        )
    }
}

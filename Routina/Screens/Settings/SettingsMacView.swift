#if os(macOS)
import ComposableArchitecture
import SwiftUI

struct SettingsMacView: View {
    let store: StoreOf<SettingsFeature>
    @State private var isPlacePickerPresented = false

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Settings")
                        .font(.largeTitle.weight(.semibold))

                    macSectionCard(title: "Notifications") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Enable notifications", isOn: notificationsBinding)
                                .toggleStyle(.switch)

                            DatePicker(
                                "Reminder time",
                                selection: reminderTimeBinding,
                                displayedComponents: .hourAndMinute
                            )
                            .disabled(store.notificationsEnabled == false)

                            Text("Notifications include quick actions for Done and Snooze.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if store.systemSettingsNotificationsEnabled == false {
                                Text("Notifications are disabled in system settings.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                Button("Allow in System Settings") {
                                    store.send(.openAppSettingsTapped)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    macSectionCard(title: "Places") {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Place name", text: placeDraftNameBinding)
                                .textFieldStyle(.roundedBorder)

                            HStack(spacing: 12) {
                                Button {
                                    isPlacePickerPresented = true
                                } label: {
                                    Label(store.placeSelectionButtonTitle, systemImage: "map")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    store.send(.savePlaceTapped)
                                } label: {
                                    if store.isPlaceOperationInProgress {
                                        ProgressView()
                                    } else {
                                        Label("Save Place", systemImage: "mappin.and.ellipse")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(store.isPlaceOperationInProgress)

                                if store.locationAuthorizationStatus.needsSettingsChange {
                                    Button("Open System Settings") {
                                        store.send(.openAppSettingsTapped)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            Text(store.placeLocationHelpText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text(store.placeDraftSelectionSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if !store.placeStatusMessage.isEmpty {
                                Text(store.placeStatusMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if store.savedPlaces.isEmpty {
                                Text("No places saved yet.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(store.savedPlaces) { place in
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(place.name)
                                                Text(settingsPlaceSubtitle(for: place))
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            Button(role: .destructive) {
                                                store.send(.deletePlaceTapped(place.id))
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .buttonStyle(.borderless)
                                            .disabled(store.isPlaceOperationInProgress)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    macSectionCard(title: "App Icon") {
                        VStack(alignment: .leading, spacing: 14) {
                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: 118), spacing: 12)
                                ],
                                spacing: 12
                            ) {
                                ForEach(AppIconOption.allCases) { option in
                                    macAppIconButton(option)
                                }
                            }

                            Text("Changes the Dock and app switcher icon immediately. Finder keeps the bundled app icon.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    macSectionCard(title: "Support") {
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                store.send(.contactUsTapped)
                            } label: {
                                Label("Contact Us", systemImage: "envelope")
                            }
                            .buttonStyle(.bordered)

                            Text("h.qadirian@gmail.com")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    macSectionCard(title: "iCloud") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Button {
                                    store.send(.syncNowTapped)
                                } label: {
                                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath.icloud")
                                }
                                .buttonStyle(.bordered)
                                .disabled(
                                    store.isCloudSyncInProgress ||
                                    store.isCloudDataResetInProgress ||
                                    !store.cloudSyncAvailable
                                )

                                Button(role: .destructive) {
                                    store.send(.setCloudDataResetConfirmation(true))
                                } label: {
                                    Label("Delete iCloud Data", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                                .disabled(
                                    store.isCloudSyncInProgress ||
                                    store.isCloudDataResetInProgress ||
                                    !store.cloudSyncAvailable
                                )

                                if store.isCloudSyncInProgress || store.isCloudDataResetInProgress {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }

                            Text(store.syncStatusText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    macSectionCard(title: "Data Backup") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Button {
                                    store.send(.exportRoutineDataTapped)
                                } label: {
                                    Label("Save JSON", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.bordered)
                                .disabled(store.isDataTransferInProgress)

                                Button {
                                    store.send(.importRoutineDataTapped)
                                } label: {
                                    Label("Load JSON", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                                .disabled(store.isDataTransferInProgress)

                                if store.isDataTransferInProgress {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }

                            Text(store.dataTransferStatusText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    macSectionCard(title: "About") {
                        VStack(alignment: .leading, spacing: 8) {
                            macInfoRow(title: "App Version", value: store.appVersion)
                        }
                    }
                    .onLongPressGesture(minimumDuration: 5) {
                        store.send(.aboutSectionLongPressed)
                    }

                    if store.isDebugSectionVisible {
                        macSectionCard(title: "Debug") {
                            VStack(alignment: .leading, spacing: 8) {
                                macInfoRow(title: "Data Mode", value: store.dataModeDescription)
                                macInfoRow(title: "iCloud Container", value: store.iCloudContainerDescription)
                                Text("Last CloudKit Event: \(store.cloudDiagnosticsTimestamp)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text(store.cloudDiagnosticsSummary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text(store.pushDiagnosticsStatus)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
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
                Text(store.deletePlaceConfirmationMessage)
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
        }
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.notificationsEnabled },
            set: { store.send(.toggleNotifications($0)) }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { store.notificationReminderTime },
            set: { store.send(.notificationReminderTimeChanged($0)) }
        )
    }

    private var placeDraftNameBinding: Binding<String> {
        Binding(
            get: { store.placeDraftName },
            set: { store.send(.placeDraftNameChanged($0)) }
        )
    }

    private var cloudDataResetConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.isCloudDataResetConfirmationPresented },
            set: { store.send(.setCloudDataResetConfirmation($0)) }
        )
    }

    private var deletePlaceConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.isDeletePlaceConfirmationPresented },
            set: { store.send(.setDeletePlaceConfirmation($0)) }
        )
    }

    private var sectionCardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor)
    }

    private var sectionCardStroke: Color {
        Color.gray.opacity(0.18)
    }

    @ViewBuilder
    private func macSectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(sectionCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(sectionCardStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func macInfoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func macAppIconButton(_ option: AppIconOption) -> some View {
        let isSelected = store.selectedAppIcon == option

        Button {
            store.send(.appIconSelected(option))
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(option.assetName)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(spacing: 6) {
                    Text(option.title)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : sectionCardStroke, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
#endif

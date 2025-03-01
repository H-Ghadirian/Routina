import ComposableArchitecture
import SwiftUI

struct SettingsIOSRootView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            List {
                Section {
                    NavigationLink {
                        SettingsNotificationsDetailView(store: store)
                    } label: {
                        SettingsNavigationRow(
                            icon: "bell.badge.fill",
                            tint: .red,
                            title: "Notifications",
                            subtitle: notificationsOverviewSubtitle,
                            value: store.notificationsEnabled ? "On" : "Off"
                        )
                    }

                    NavigationLink {
                        SettingsPlacesDetailView(store: store)
                    } label: {
                        SettingsNavigationRow(
                            icon: "mappin.and.ellipse",
                            tint: .blue,
                            title: "Places",
                            subtitle: placesOverviewSubtitle
                        )
                    }

                    NavigationLink {
                        SettingsTagsDetailView(store: store)
                    } label: {
                        SettingsNavigationRow(
                            icon: "tag.fill",
                            tint: .pink,
                            title: "Tags",
                            subtitle: store.tagsOverviewSubtitle
                        )
                    }

                    NavigationLink {
                        SettingsAppearanceDetailView(store: store)
                    } label: {
                        SettingsNavigationRow(
                            icon: "app.badge.fill",
                            tint: .orange,
                            title: "Appearance",
                            subtitle: "Current icon: \(store.selectedAppIcon.title)"
                        )
                    }

                    NavigationLink {
                        SettingsCloudDetailView(store: store)
                    } label: {
                        SettingsNavigationRow(
                            icon: "icloud.fill",
                            tint: .cyan,
                            title: "iCloud",
                            subtitle: cloudOverviewSubtitle,
                            value: store.cloudSyncAvailable ? nil : "Off"
                        )
                    }
                }

                Section {
                    NavigationLink {
                        SettingsSupportDetailView(store: store)
                    } label: {
                        SettingsNavigationRow(
                            icon: "envelope.fill",
                            tint: .green,
                            title: "Support",
                            subtitle: "Contact us by email"
                        )
                    }

                    NavigationLink {
                        SettingsAboutDetailView(store: store)
                    } label: {
                        SettingsNavigationRow(
                            icon: "info.circle.fill",
                            tint: .gray,
                            title: "About",
                            subtitle: aboutOverviewSubtitle
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var notificationsOverviewSubtitle: String {
        if store.notificationsEnabled {
            let time = store.notificationReminderTime.formatted(date: .omitted, time: .shortened)
            return "Daily reminder at \(time)"
        }
        if store.systemSettingsNotificationsEnabled == false {
            return "Disabled in System Settings"
        }
        return "Routine reminders are turned off"
    }

    private var placesOverviewSubtitle: String {
        switch store.savedPlaces.count {
        case 0:
            return "Save locations for place-based routines"
        case 1:
            return "1 saved place"
        default:
            return "\(store.savedPlaces.count) saved places"
        }
    }

    private var cloudOverviewSubtitle: String {
        if store.isCloudSyncInProgress {
            return "Syncing with iCloud"
        }
        if store.isCloudDataResetInProgress {
            return "Deleting iCloud data"
        }
        if !store.cloudStatusMessage.isEmpty {
            return store.cloudStatusMessage
        }
        if !store.cloudSyncAvailable {
            return "Unavailable in this build"
        }
        return "Sync routines across devices"
    }

    private var aboutOverviewSubtitle: String {
        if store.isDebugSectionVisible {
            return "Version \(store.appVersion) • Diagnostics unlocked"
        }
        if store.appVersion.isEmpty {
            return "App details"
        }
        return "Version \(store.appVersion)"
    }
}

private struct SettingsNotificationsDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("Reminders") {
                    Toggle("Enable notifications", isOn: notificationsBinding)

                    DatePicker(
                        "Reminder time",
                        selection: reminderTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(store.notificationsEnabled == false)
                }

                Section("Info") {
                    Text("Notifications include quick actions for Done and Snooze.")
                        .foregroundStyle(.secondary)
                }

                if store.systemSettingsNotificationsEnabled == false {
                    Section("System Settings") {
                        Button("Allow Notifications in System Settings") {
                            store.send(.openAppSettingsTapped)
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
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
}

private struct SettingsPlacesDetailView: View {
    let store: StoreOf<SettingsFeature>
    @State private var isPlacePickerPresented = false

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("Add Place") {
                    TextField("Place name", text: placeDraftNameBinding)

                    if let validationMessage = store.savePlaceValidationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button {
                        isPlacePickerPresented = true
                    } label: {
                        Label(store.placeSelectionButtonTitle, systemImage: "map")
                    }

                    Text(store.placeDraftSelectionSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        store.send(.savePlaceTapped)
                    } label: {
                        HStack {
                            if store.isPlaceOperationInProgress {
                                ProgressView()
                            } else {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(.blue)
                            }
                            Text("Save Place")
                        }
                    }
                    .disabled(store.isSavePlaceDisabled)
                }

                Section("Location") {
                    Text(store.placeLocationHelpText)
                        .foregroundStyle(.secondary)

                    if store.locationAuthorizationStatus.needsSettingsChange {
                        Button("Open System Settings") {
                            store.send(.openAppSettingsTapped)
                        }
                    }
                }

                if !store.placeStatusMessage.isEmpty {
                    Section("Status") {
                        Text(store.placeStatusMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Saved Places") {
                    if store.savedPlaces.isEmpty {
                        Text("No places saved yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.savedPlaces) { place in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.name)
                                Text(settingsPlaceSubtitle(for: place))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    store.send(.deletePlaceTapped(place.id))
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .disabled(store.isPlaceOperationInProgress)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Places")
            .navigationBarTitleDisplayMode(.inline)
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

    private var placeDraftNameBinding: Binding<String> {
        Binding(
            get: { store.placeDraftName },
            set: { store.send(.placeDraftNameChanged($0)) }
        )
    }

    private var deletePlaceConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.isDeletePlaceConfirmationPresented },
            set: { store.send(.setDeletePlaceConfirmation($0)) }
        )
    }
}

struct SettingsTagsDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("Info") {
                    Text("Rename or delete tags across every routine that uses them.")
                        .foregroundStyle(.secondary)
                }

                Section("Saved Tags") {
                    if store.savedTags.isEmpty {
                        Text("No tags yet. Tags you add to routines will appear here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.savedTags) { tag in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tag.name)
                                    Text(settingsTagSubtitle(for: tag))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Menu {
                                    Button {
                                        store.send(.renameTagTapped(tag.name))
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        store.send(.deleteTagTapped(tag.name))
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                .disabled(store.isTagOperationInProgress)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    store.send(.renameTagTapped(tag.name))
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    store.send(.deleteTagTapped(tag.name))
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                if !store.tagStatusMessage.isEmpty {
                    Section("Status") {
                        Text(store.tagStatusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "Delete Tag?",
                isPresented: deleteTagConfirmationBinding
            ) {
                Button("Delete", role: .destructive) {
                    store.send(.deleteTagConfirmed)
                }
                Button("Cancel", role: .cancel) {
                    store.send(.setDeleteTagConfirmation(false))
                }
            } message: {
                Text(store.deleteTagConfirmationMessage)
            }
            .sheet(isPresented: renameTagSheetBinding) {
                SettingsTagRenameSheet(store: store)
                    .presentationDetents([.height(240)])
            }
        }
    }

    private var deleteTagConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.isDeleteTagConfirmationPresented },
            set: { store.send(.setDeleteTagConfirmation($0)) }
        )
    }

    private var renameTagSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isTagRenameSheetPresented },
            set: { store.send(.setTagRenameSheet($0)) }
        )
    }
}

private struct SettingsAppearanceDetailView: View {
    let store: StoreOf<SettingsFeature>

    private let columns = [
        GridItem(.adaptive(minimum: 108), spacing: 12)
    ]

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("App Icon") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppIconOption.allCases) { option in
                            SettingsAppIconButton(
                                option: option,
                                isSelected: store.selectedAppIcon == option
                            ) {
                                store.send(.appIconSelected(option))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                    Text("iOS confirms icon changes before applying them.")
                        .foregroundStyle(.secondary)
                }

                if !store.appIconStatusMessage.isEmpty {
                    Section("Status") {
                        Text(store.appIconStatusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SettingsCloudDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("Actions") {
                    Button {
                        store.send(.syncNowTapped)
                    } label: {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath.icloud")
                    }
                    .disabled(actionsDisabled)

                    Button(role: .destructive) {
                        store.send(.setCloudDataResetConfirmation(true))
                    } label: {
                        Label("Delete iCloud Data", systemImage: "trash")
                    }
                    .disabled(actionsDisabled)
                }

                Section("Status") {
                    if store.isCloudSyncInProgress || store.isCloudDataResetInProgress {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(store.syncStatusText)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(store.syncStatusText)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("iCloud")
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }

    private var actionsDisabled: Bool {
        store.isCloudSyncInProgress ||
        store.isCloudDataResetInProgress ||
        !store.cloudSyncAvailable
    }

    private var cloudDataResetConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.isCloudDataResetConfirmationPresented },
            set: { store.send(.setCloudDataResetConfirmation($0)) }
        )
    }
}

private struct SettingsSupportDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("Contact") {
                    Button {
                        store.send(.contactUsTapped)
                    } label: {
                        Label("Email Support", systemImage: "envelope")
                    }

                    HStack {
                        Text("Email")
                        Spacer()
                        Text("h.qadirian@gmail.com")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SettingsAboutDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("App") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(store.appVersion)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 5) {
                        store.send(.aboutSectionLongPressed)
                    }
                }

                if store.isDebugSectionVisible {
                    Section("Diagnostics") {
                        infoRow(title: "Data Mode", value: store.dataModeDescription)
                        infoRow(title: "iCloud Container", value: store.iCloudContainerDescription)

                        Text("Last CloudKit Event: \(store.cloudDiagnosticsTimestamp)")
                            .foregroundStyle(.secondary)
                        Text(store.cloudDiagnosticsSummary)
                            .foregroundStyle(.secondary)
                        Text(store.pushDiagnosticsStatus)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SettingsNavigationRow: View {
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String?
    var value: String?

    var body: some View {
        HStack(spacing: 12) {
            SettingsGlyph(icon: icon, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            if let value, !value.isEmpty {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SettingsGlyph: View {
    let icon: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(tint)
            .frame(width: 30, height: 30)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

private struct SettingsAppIconButton: View {
    let option: AppIconOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(option.assetName)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack(spacing: 6) {
                    Text(option.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color(uiColor: .separator), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

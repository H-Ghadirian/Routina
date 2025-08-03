import Combine
import ComposableArchitecture
import SwiftUI

struct SettingsTCAView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            settingsContent
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
                Text(deletePlaceConfirmationMessage)
            }
            .onAppear {
                store.send(.onAppear)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: PlatformSupport.didBecomeActiveNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                store.send(.onAppBecameActive)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: CloudKitSyncDiagnostics.didUpdateNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                store.send(.cloudDiagnosticsUpdated)
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

    private var placeDraftRadiusBinding: Binding<Double> {
        Binding(
            get: { store.placeDraftRadiusMeters },
            set: { store.send(.placeDraftRadiusChanged($0)) }
        )
    }

    private var syncStatusText: String {
        if store.isCloudDataResetInProgress {
            return "Deleting iCloud data..."
        }
        if store.isCloudSyncInProgress {
            return "Syncing..."
        }
        if !store.cloudStatusMessage.isEmpty {
            return store.cloudStatusMessage
        }
        if !store.cloudSyncAvailable {
            return "iCloud sync is disabled in this build."
        }
        return "Ready to sync."
    }

    private var dataTransferStatusText: String {
        if store.isDataTransferInProgress {
            return "Processing JSON file..."
        }
        if !store.dataTransferStatusMessage.isEmpty {
            return store.dataTransferStatusMessage
        }
        return "Export or import all routine data as JSON."
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

    private var deletePlaceConfirmationMessage: String {
        guard let place = store.placePendingDeletion else {
            return "This will remove the place."
        }

        let linkedRoutinesText: String
        if place.linkedRoutineCount == 1 {
            linkedRoutinesText = "1 linked routine will be unlinked"
        } else {
            linkedRoutinesText = "\(place.linkedRoutineCount) linked routines will be unlinked"
        }

        return "Delete \(place.name)? This cannot be undone, and \(linkedRoutinesText)."
    }

    @ViewBuilder
    private var settingsContent: some View {
        #if os(macOS)
        macSettingsContent
        #else
        NavigationStack {
            Form {
                notificationsFormSection
                placesFormSection
                appIconFormSection
                supportFormSection
                iCloudFormSection
                aboutFormSection
                if store.isDebugSectionVisible {
                    debugFormSection
                }
            }
            .navigationTitle("Settings")
        }
        #endif
    }

    @ViewBuilder
    private var notificationsFormSection: some View {
        Section(header: Text("Notifications")) {
            Toggle("Enable notifications", isOn: notificationsBinding)

            DatePicker(
                "Reminder time",
                selection: reminderTimeBinding,
                displayedComponents: .hourAndMinute
            )
            .disabled(store.notificationsEnabled == false)

            Text("Notifications include quick actions for Done and Snooze.")
                .font(.footnote)
                .foregroundColor(.secondary)

            if store.systemSettingsNotificationsEnabled == false {
                Button("Allow Notifications in System Settings") {
                    store.send(.openAppSettingsTapped)
                }
                .foregroundColor(.red)
            }
        }
    }

    @ViewBuilder
    private var supportFormSection: some View {
        Section(header: Text("Support")) {
            Button(action: {
                store.send(.contactUsTapped)
            }) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.blue)
                    Text("Contact Us")
                }
            }

            Text("h.qadirian@gmail.com")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var placesFormSection: some View {
        Section(header: Text("Places")) {
            TextField("Place name", text: placeDraftNameBinding)

            Stepper(value: placeDraftRadiusBinding, in: 25...2_000, step: 25) {
                Text("Radius: \(Int(store.placeDraftRadiusMeters)) m")
            }

            Button {
                store.send(.saveCurrentLocationAsPlaceTapped)
            } label: {
                HStack {
                    if store.isPlaceOperationInProgress {
                        ProgressView()
                    } else {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                    }
                    Text("Save Current Location")
                }
            }
            .disabled(store.isPlaceOperationInProgress)

            Text(placeLocationHelpText)
                .font(.footnote)
                .foregroundColor(.secondary)

            if store.locationAuthorizationStatus.needsSettingsChange {
                Button("Open System Settings") {
                    store.send(.openAppSettingsTapped)
                }
            }

            if !store.placeStatusMessage.isEmpty {
                Text(store.placeStatusMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if store.savedPlaces.isEmpty {
                Text("No places saved yet.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(store.savedPlaces) { place in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.name)
                            Text(placeSubtitle(for: place))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            store.send(.deletePlaceTapped(place.id))
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(store.isPlaceOperationInProgress)
                    }
                }
            }
        }
    }

#if !os(macOS)
    @ViewBuilder
    private var appIconFormSection: some View {
        Section(header: Text("App Icon")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(AppIconOption.allCases) { option in
                        iosAppIconButton(option)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            Text("iOS confirms icon changes before applying them.")
                .font(.footnote)
                .foregroundColor(.secondary)

            if !store.appIconStatusMessage.isEmpty {
                Text(store.appIconStatusMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
#endif

    @ViewBuilder
    private var iCloudFormSection: some View {
        Section(header: Text("iCloud")) {
            Button {
                store.send(.syncNowTapped)
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud")
                        .foregroundColor(.blue)
                    Text("Sync Now")
                }
            }
            .disabled(
                store.isCloudSyncInProgress ||
                store.isCloudDataResetInProgress ||
                !store.cloudSyncAvailable
            )

            Button(role: .destructive) {
                store.send(.setCloudDataResetConfirmation(true))
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("Delete iCloud Data")
                }
            }
            .disabled(
                store.isCloudSyncInProgress ||
                store.isCloudDataResetInProgress ||
                !store.cloudSyncAvailable
            )

            if store.isCloudSyncInProgress || store.isCloudDataResetInProgress {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(syncStatusText)
                        .foregroundColor(.secondary)
                }
            } else if !store.cloudStatusMessage.isEmpty {
                Text(store.cloudStatusMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var aboutFormSection: some View {
        Section(header: Text("About")) {
            HStack {
                Text("App Version")
                Spacer()
                Text(store.appVersion)
                    .foregroundColor(.gray)
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 5) {
                store.send(.aboutSectionLongPressed)
            }
        }
    }

    @ViewBuilder
    private var debugFormSection: some View {
        Section(header: Text("Debug")) {
            HStack {
                Text("Data Mode")
                Spacer()
                Text(store.dataModeDescription)
                    .foregroundColor(.gray)
            }

            HStack {
                Text("iCloud Container")
                Spacer()
                Text(store.iCloudContainerDescription)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.trailing)
            }

            Text("Last CloudKit Event: \(store.cloudDiagnosticsTimestamp)")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text(store.cloudDiagnosticsSummary)
                .font(.footnote)
                .foregroundColor(.secondary)
            Text(store.pushDiagnosticsStatus)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var placeLocationHelpText: String {
        switch store.locationAuthorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "Save your current location as a reusable place. Place-linked routines stay visible whenever location is unavailable."
        case .notDetermined:
            return "You’ll be asked for location access when you save a place."
        case .disabled:
            return "Location services are disabled on this device."
        case .restricted, .denied:
            return "Location access is off. Place-linked routines stay visible until you enable it."
        }
    }

    private func placeSubtitle(for place: RoutinePlaceSummary) -> String {
        let linkedText = place.linkedRoutineCount == 1
            ? "1 linked routine"
            : "\(place.linkedRoutineCount) linked routines"
        return "\(Int(place.radiusMeters)) m radius • \(linkedText)"
    }

#if os(macOS)
    private var sectionCardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor)
    }

    private var sectionCardStroke: Color {
        Color.gray.opacity(0.18)
    }

    private var macSettingsContent: some View {
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

                        Stepper(value: placeDraftRadiusBinding, in: 25...2_000, step: 25) {
                            Text("Radius: \(Int(store.placeDraftRadiusMeters)) m")
                        }

                        HStack(spacing: 12) {
                            Button {
                                store.send(.saveCurrentLocationAsPlaceTapped)
                            } label: {
                                if store.isPlaceOperationInProgress {
                                    ProgressView()
                                } else {
                                    Label("Save Current Location", systemImage: "location.fill")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(store.isPlaceOperationInProgress)

                            if store.locationAuthorizationStatus.needsSettingsChange {
                                Button("Open System Settings") {
                                    store.send(.openAppSettingsTapped)
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        Text(placeLocationHelpText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

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
                                            Text(placeSubtitle(for: place))
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

                        Text(syncStatusText)
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

                        Text(dataTransferStatusText)
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
#else
    @ViewBuilder
    private func iosAppIconButton(_ option: AppIconOption) -> some View {
        let isSelected = store.selectedAppIcon == option

        Button {
            store.send(.appIconSelected(option))
        } label: {
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
            .frame(width: 108, alignment: .leading)
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
#endif
}

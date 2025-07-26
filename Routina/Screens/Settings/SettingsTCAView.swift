import Combine
import ComposableArchitecture
import MapKit
import SwiftUI

struct SettingsTCAView: View {
    let store: StoreOf<SettingsFeature>
    @State private var isPlacePickerPresented = false

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

    private var placeSelectionButtonTitle: String {
        store.placeDraftCoordinate == nil ? "Choose Location on Map" : "Edit Location on Map"
    }

    private var placeDraftSelectionSummary: String {
        guard let coordinate = store.placeDraftCoordinate else {
            if store.lastKnownLocationCoordinate != nil {
                return "No location selected yet. The map will open near your current location."
            }
            return "No location selected yet. Open the map and tap where this place should be centered."
        }

        return "Selected center: \(formattedCoordinate(coordinate)) • \(Int(store.placeDraftRadiusMeters)) m radius"
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

            Button {
                isPlacePickerPresented = true
            } label: {
                Label(placeSelectionButtonTitle, systemImage: "map")
            }

            Text(placeDraftSelectionSummary)
                .font(.footnote)
                .foregroundColor(.secondary)

            Button {
                store.send(.savePlaceTapped)
            } label: {
                HStack {
                    if store.isPlaceOperationInProgress {
                        ProgressView()
                    } else {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.blue)
                    }
                    Text("Save Place")
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
            return "Choose a point on the map and adjust the radius. Routina will show place-based routines when you are inside that circle."
        case .notDetermined:
            return "Choose a point on the map and adjust the radius. Allow location access later so Routina can tell when you are inside the saved circle."
        case .disabled:
            return "Location services are disabled on this device. You can still save places, but Routina will not know when you are inside them."
        case .restricted, .denied:
            return "Location access is off. You can still save places, but place-linked routines stay visible until you enable location again."
        }
    }

    private func formattedCoordinate(_ coordinate: LocationCoordinate) -> String {
        let latitude = coordinate.latitude.formatted(.number.precision(.fractionLength(4)))
        let longitude = coordinate.longitude.formatted(.number.precision(.fractionLength(4)))
        return "\(latitude), \(longitude)"
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

                        HStack(spacing: 12) {
                            Button {
                                isPlacePickerPresented = true
                            } label: {
                                Label(placeSelectionButtonTitle, systemImage: "map")
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

                        Text(placeLocationHelpText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(placeDraftSelectionSummary)
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

private struct PlaceLocationPickerSheet: View {
    let fallbackCoordinate: LocationCoordinate?
    let cameraConfiguration: PlaceLocationPickerCameraConfiguration
    let onUseLocation: (LocationCoordinate, Double) -> Void
    let onCancel: () -> Void

    @State private var selectedCoordinate: LocationCoordinate?
    @State private var draftRadiusMeters: Double
    @State private var cameraAnimationTrigger = 0
    @State private var cameraAnimationTarget: PlaceLocationPickerCameraConfiguration.AnimationTarget?

    init(
        initialCoordinate: LocationCoordinate?,
        initialRadiusMeters: Double,
        fallbackCoordinate: LocationCoordinate?,
        onUseLocation: @escaping (LocationCoordinate, Double) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.fallbackCoordinate = fallbackCoordinate
        self.cameraConfiguration = .make(
            initialCoordinate: initialCoordinate,
            fallbackCoordinate: fallbackCoordinate,
            radiusMeters: initialRadiusMeters
        )
        self.onUseLocation = onUseLocation
        self.onCancel = onCancel
        _selectedCoordinate = State(initialValue: initialCoordinate)
        _draftRadiusMeters = State(initialValue: min(max(initialRadiusMeters, 25), 2_000))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tap the map to place the center point.")
                        .font(.headline)
                    Text("Adjust the radius below. The highlighted circle shows when the place becomes active.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                MapReader { proxy in
                    Map(initialPosition: cameraConfiguration.initialFocus.mapCameraPosition) {
                        UserAnnotation()

                        if let selectedCoordinate {
                            Marker("Selected Place", coordinate: selectedCoordinate.clLocationCoordinate2D)
                            MapCircle(
                                center: selectedCoordinate.clLocationCoordinate2D,
                                radius: draftRadiusMeters
                            )
                            .foregroundStyle(Color.accentColor.opacity(0.18))
                        }
                    }
                    .mapCameraKeyframeAnimator(trigger: cameraAnimationTrigger) { camera in
                        KeyframeTrack(\MapCamera.centerCoordinate) {
                            LinearKeyframe(
                                cameraAnimationTarget?.coordinate.clLocationCoordinate2D ?? camera.centerCoordinate,
                                duration: 0.75,
                                timingCurve: .easeInOut
                            )
                        }
                        KeyframeTrack(\MapCamera.distance) {
                            LinearKeyframe(
                                cameraAnimationTarget?.distance ?? camera.distance,
                                duration: 0.75,
                                timingCurve: .easeInOut
                            )
                        }
                    }
                    .mapStyle(.standard)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        Text(selectedCoordinate == nil ? "Tap to choose a location" : "Tap anywhere to move the center")
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(16)
                    }
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                guard let coordinate = proxy.convert(value.location, from: .local) else {
                                    return
                                }

                                let location = LocationCoordinate(
                                    latitude: coordinate.latitude,
                                    longitude: coordinate.longitude
                                )
                                selectedCoordinate = location
                                animateCamera(to: location)
                            }
                    )
                }
                .frame(minHeight: 360)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Radius")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(draftRadiusMeters)) m")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $draftRadiusMeters, in: 25...2_000, step: 25)

                    if let selectedCoordinate {
                        Text("Center: \(selectedCoordinate.formattedForPlaceSelection)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if let fallbackCoordinate {
                        Text("Map is centered near \(fallbackCoordinate.formattedForPlaceSelection).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No center selected yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .navigationTitle("Choose Place")
#if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Use This Location") {
                        guard let selectedCoordinate else {
                            return
                        }
                        onUseLocation(selectedCoordinate, draftRadiusMeters)
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
        }
        .onChange(of: draftRadiusMeters) { _, _ in
            guard let selectedCoordinate else { return }
            animateCamera(to: selectedCoordinate)
        }
#if os(macOS)
        .frame(minWidth: 680, minHeight: 620)
#endif
    }

    private func animateCamera(to coordinate: LocationCoordinate) {
        cameraAnimationTarget = PlaceLocationPickerCameraConfiguration.animationTarget(
            for: coordinate,
            radiusMeters: draftRadiusMeters
        )
        cameraAnimationTrigger += 1
    }
}

private extension LocationCoordinate {
    var formattedForPlaceSelection: String {
        let latitude = latitude.formatted(.number.precision(.fractionLength(4)))
        let longitude = longitude.formatted(.number.precision(.fractionLength(4)))
        return "\(latitude), \(longitude)"
    }
}

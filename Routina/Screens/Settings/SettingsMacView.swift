import AppKit
import ComposableArchitecture
import SwiftUI

private enum SettingsMacSection: String, CaseIterable, Identifiable, Hashable {
    case notifications
    case places
    case tags
    case appearance
    case iCloud
    case backup
    case support
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notifications:
            return "Notifications"
        case .places:
            return "Places"
        case .tags:
            return "Tags"
        case .appearance:
            return "Appearance"
        case .iCloud:
            return "iCloud"
        case .backup:
            return "Data Backup"
        case .support:
            return "Support"
        case .about:
            return "About"
        }
    }

    var icon: String {
        switch self {
        case .notifications:
            return "bell.badge.fill"
        case .places:
            return "mappin.and.ellipse"
        case .tags:
            return "tag.fill"
        case .appearance:
            return "app.badge.fill"
        case .iCloud:
            return "icloud.fill"
        case .backup:
            return "externaldrive.fill"
        case .support:
            return "envelope.fill"
        case .about:
            return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .notifications:
            return .red
        case .places:
            return .blue
        case .tags:
            return .pink
        case .appearance:
            return .orange
        case .iCloud:
            return .cyan
        case .backup:
            return .indigo
        case .support:
            return .green
        case .about:
            return .gray
        }
    }
}

private enum SettingsMacLayout {
    static let sidebarMinimumWidth: CGFloat = 300
    static let sidebarIdealWidth: CGFloat = 320
    static let sidebarMaximumWidth: CGFloat = 360
}

struct SettingsMacView: View {
    let store: StoreOf<SettingsFeature>
    @State private var selectedSection: SettingsMacSection? = .notifications
    @State private var isPlacePickerPresented = false

    var body: some View {
        WithPerceptionTracking {
            NavigationSplitView {
                List(selection: $selectedSection) {
                    ForEach(SettingsMacSection.allCases) { section in
                        SettingsMacSidebarRow(
                            section: section,
                            store: store
                        )
                        .tag(section)
                    }
                }
                .listStyle(.sidebar)
                .navigationTitle("Settings")
                .toolbar(removing: .sidebarToggle)
                .navigationSplitViewColumnWidth(
                    min: SettingsMacLayout.sidebarMinimumWidth,
                    ideal: SettingsMacLayout.sidebarIdealWidth,
                    max: SettingsMacLayout.sidebarMaximumWidth
                )
                .background(
                    SettingsMacSidebarSplitViewConfigurator(
                        minimumWidth: SettingsMacLayout.sidebarMinimumWidth
                    )
                )
            } detail: {
                SettingsMacDetailView(
                    section: selectedSection ?? .notifications,
                    store: store,
                    isPlacePickerPresented: $isPlacePickerPresented
                )
            }
            .navigationSplitViewStyle(.balanced)
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
}

private struct SettingsMacSidebarRow: View {
    let section: SettingsMacSection
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            HStack(spacing: 12) {
                SettingsMacGlyph(icon: section.icon, tint: section.tint)

                VStack(alignment: .leading, spacing: 3) {
                    Text(section.title)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if let value, !value.isEmpty {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var subtitle: String {
        switch section {
        case .notifications:
            if store.notificationsEnabled {
                let time = store.notificationReminderTime.formatted(date: .omitted, time: .shortened)
                return "Daily reminder at \(time)"
            }
            if store.systemSettingsNotificationsEnabled == false {
                return "Disabled in System Settings"
            }
            return "Routine reminders are turned off"

        case .places:
            switch store.savedPlaces.count {
            case 0:
                return "Save locations for place-based routines"
            case 1:
                return "1 saved place"
            default:
                return "\(store.savedPlaces.count) saved places"
            }

        case .tags:
            return store.tagsOverviewSubtitle

        case .appearance:
            return "Current icon: \(store.selectedAppIcon.title)"

        case .iCloud:
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

        case .backup:
            if store.isDataTransferInProgress {
                return "Importing or exporting JSON"
            }
            if !store.dataTransferStatusMessage.isEmpty {
                return store.dataTransferStatusMessage
            }
            return "Export or import your routine data"

        case .support:
            return "Contact us by email"

        case .about:
            if store.isDebugSectionVisible {
                return "Version \(store.appVersion) • Diagnostics unlocked"
            }
            if store.appVersion.isEmpty {
                return "App details"
            }
            return "Version \(store.appVersion)"
        }
    }

    private var value: String? {
        switch section {
        case .notifications:
            return store.notificationsEnabled ? "On" : "Off"
        case .iCloud:
            return store.cloudSyncAvailable ? nil : "Off"
        default:
            return nil
        }
    }
}

private struct SettingsMacSidebarSplitViewConfigurator: NSViewRepresentable {
    let minimumWidth: CGFloat

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard
                let splitView = nsView.enclosingSplitView,
                let splitViewController = splitView.delegate as? NSSplitViewController,
                let sidebarItem = splitViewController.splitViewItems.first
            else {
                return
            }

            sidebarItem.canCollapse = false
            sidebarItem.canCollapseFromWindowResize = false
            sidebarItem.minimumThickness = minimumWidth
            sidebarItem.holdingPriority = .defaultHigh
            splitViewController.minimumThicknessForInlineSidebars = minimumWidth

            guard
                splitView.subviews.count > 1,
                let sidebarView = splitView.subviews.first,
                sidebarView.frame.width < minimumWidth
            else {
                return
            }

            splitView.setPosition(minimumWidth, ofDividerAt: 0)
        }
    }
}

private extension NSView {
    var enclosingSplitView: NSSplitView? {
        sequence(first: superview, next: { $0?.superview })
            .compactMap { $0 as? NSSplitView }
            .first
    }
}

private struct SettingsMacDetailView: View {
    let section: SettingsMacSection
    let store: StoreOf<SettingsFeature>
    @Binding var isPlacePickerPresented: Bool

    var body: some View {
        switch section {
        case .notifications:
            SettingsMacNotificationsDetailView(store: store)
        case .places:
            SettingsMacPlacesDetailView(
                store: store,
                isPlacePickerPresented: $isPlacePickerPresented
            )
        case .tags:
            SettingsMacTagsDetailView(store: store)
        case .appearance:
            SettingsMacAppearanceDetailView(store: store)
        case .iCloud:
            SettingsMacCloudDetailView(store: store)
        case .backup:
            SettingsMacBackupDetailView(store: store)
        case .support:
            SettingsMacSupportDetailView(store: store)
        case .about:
            SettingsMacAboutDetailView(store: store)
        }
    }
}

private struct SettingsMacNotificationsDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "Notifications",
                subtitle: "Choose if Routina should remind you and when those reminders should arrive."
            ) {
                SettingsMacDetailCard(title: "Routine Reminders") {
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
                }

                if store.systemSettingsNotificationsEnabled == false {
                    SettingsMacDetailCard(title: "System Settings") {
                        Text("Notifications are disabled in system settings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button("Allow in System Settings") {
                            store.send(.openAppSettingsTapped)
                        }
                        .buttonStyle(.borderedProminent)
                    }
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
}

private struct SettingsMacPlacesDetailView: View {
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

                    Text(store.placeDraftSelectionSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Location") {
                    Text(store.placeLocationHelpText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !store.placeStatusMessage.isEmpty {
                        Text(store.placeStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                SettingsMacDetailCard(title: "Saved Places") {
                    if store.savedPlaces.isEmpty {
                        Text("No places saved yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.savedPlaces.enumerated()), id: \.element.id) { index, place in
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
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(store.isPlaceOperationInProgress)
                                }
                                .padding(.vertical, 12)

                                if index < store.savedPlaces.count - 1 {
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
            get: { store.placeDraftName },
            set: { store.send(.placeDraftNameChanged($0)) }
        )
    }
}

struct SettingsMacTagsDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "Tags",
                subtitle: "Review every tag in Routina and rename or remove them globally."
            ) {
                SettingsMacDetailCard(title: "All Tags") {
                    if store.savedTags.isEmpty {
                        Text("No tags yet. Tags you add to routines will appear here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.savedTags.enumerated()), id: \.element.id) { index, tag in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(tag.name)
                                        Text(settingsTagSubtitle(for: tag))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        store.send(.renameTagTapped(tag.name))
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(store.isTagOperationInProgress)

                                    Button(role: .destructive) {
                                        store.send(.deleteTagTapped(tag.name))
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(store.isTagOperationInProgress)
                                }
                                .padding(.vertical, 12)

                                if index < store.savedTags.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                if !store.tagStatusMessage.isEmpty {
                    SettingsMacDetailCard(title: "Status") {
                        Text(store.tagStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
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

private struct SettingsMacAppearanceDetailView: View {
    let store: StoreOf<SettingsFeature>

    private let columns = [
        GridItem(.adaptive(minimum: 124), spacing: 12)
    ]

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "Appearance",
                subtitle: "Pick the app icon you want to see in the Dock and app switcher."
            ) {
                SettingsMacDetailCard(title: "App Icon") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppIconOption.allCases) { option in
                            SettingsMacAppIconButton(
                                option: option,
                                isSelected: store.selectedAppIcon == option
                            ) {
                                store.send(.appIconSelected(option))
                            }
                        }
                    }

                    Text("Changes the Dock and app switcher icon immediately. Finder keeps the bundled app icon.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !store.appIconStatusMessage.isEmpty {
                    SettingsMacDetailCard(title: "Status") {
                        Text(store.appIconStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct SettingsMacCloudDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "iCloud",
                subtitle: "Keep your routines synced across devices and manage the cloud copy when needed."
            ) {
                SettingsMacDetailCard(title: "Actions") {
                    HStack(spacing: 10) {
                        Button {
                            store.send(.syncNowTapped)
                        } label: {
                            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath.icloud")
                        }
                        .buttonStyle(.bordered)
                        .disabled(actionsDisabled)

                        Button(role: .destructive) {
                            store.send(.setCloudDataResetConfirmation(true))
                        } label: {
                            Label("Delete iCloud Data", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(actionsDisabled)

                        if store.isCloudSyncInProgress || store.isCloudDataResetInProgress {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }

                SettingsMacDetailCard(title: "Status") {
                    Text(store.syncStatusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var actionsDisabled: Bool {
        store.isCloudSyncInProgress ||
        store.isCloudDataResetInProgress ||
        !store.cloudSyncAvailable
    }
}

private struct SettingsMacBackupDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "Data Backup",
                subtitle: "Export your routines as JSON or bring a previous backup back into Routina."
            ) {
                SettingsMacDetailCard(title: "JSON Backup") {
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
        }
    }
}

private struct SettingsMacSupportDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        SettingsMacDetailShell(
            title: "Support",
            subtitle: "Reach out if something feels off or you want help with Routina."
        ) {
            SettingsMacDetailCard(title: "Contact") {
                Button {
                    store.send(.contactUsTapped)
                } label: {
                    Label("Email Support", systemImage: "envelope")
                }
                .buttonStyle(.borderedProminent)

                Text("h.qadirian@gmail.com")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SettingsMacAboutDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "About",
                subtitle: "Version details and, if unlocked, the app’s diagnostic information."
            ) {
                SettingsMacDetailCard(title: "App") {
                    settingsInfoRow(title: "Version", value: store.appVersion)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 5) {
                            store.send(.aboutSectionLongPressed)
                        }
                }

                if store.isDebugSectionVisible {
                    SettingsMacDetailCard(title: "Diagnostics") {
                        settingsInfoRow(title: "Data Mode", value: store.dataModeDescription)
                        settingsInfoRow(title: "iCloud Container", value: store.iCloudContainerDescription)

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
    }
}

private struct SettingsMacDetailShell<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.largeTitle.weight(.semibold))

                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                content
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 760, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SettingsMacDetailCard<Content: View>: View {
    let title: String
    let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline.weight(.semibold))

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct SettingsMacGlyph: View {
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

private struct SettingsMacAppIconButton: View {
    let option: AppIconOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(option.assetName)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(spacing: 6) {
                    Text(option.title)
                        .font(.subheadline.weight(.medium))

                    Spacer(minLength: 0)

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
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.18), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private func settingsInfoRow(title: String, value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
        Text(title)
            .foregroundStyle(.secondary)

        Spacer()

        Text(value)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
    }
}

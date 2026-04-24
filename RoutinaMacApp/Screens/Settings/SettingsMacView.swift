import AppKit
import ComposableArchitecture
import SwiftUI

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
                    ForEach(SettingsMacSection.visibleSections(isGitFeaturesEnabled: store.appearance.isGitFeaturesEnabled)) { section in
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
                    section: selectedDetailSection,
                    store: store,
                    isPlacePickerPresented: $isPlacePickerPresented
                )
            }
            .navigationSplitViewStyle(.balanced)
            .onChange(of: store.appearance.isGitFeaturesEnabled) { _, isEnabled in
                if !isEnabled, selectedSection == .git {
                    selectedSection = .appearance
                }
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
    }

    private var cloudDataResetConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.cloud.isCloudDataResetConfirmationPresented },
            set: { store.send(.setCloudDataResetConfirmation($0)) }
        )
    }

    private var selectedDetailSection: SettingsMacSection {
        let fallback = selectedSection ?? .notifications
        if fallback == .git, !store.appearance.isGitFeaturesEnabled {
            return .appearance
        }
        return fallback
    }

    private var deletePlaceConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.places.isDeletePlaceConfirmationPresented },
            set: { store.send(.setDeletePlaceConfirmation($0)) }
        )
    }
}

struct SettingsMacSidebarRow: View {
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
            return store.notifications.overviewSubtitle

        case .places:
            return store.places.overviewSubtitle

        case .tags:
            return store.tags.overviewSubtitle

        case .appearance:
            return store.appearance.overviewSubtitle

        case .iCloud:
            return store.cloud.overviewSubtitle
        case .git:
            let ghConnected = store.github.connectedRepository != nil
            let glConnected = store.gitlab.isConnected
            if ghConnected && glConnected { return "GitHub & GitLab connected" }
            if glConnected { return store.gitlab.overviewSubtitle }
            return store.github.overviewSubtitle

        case .backup:
            return store.dataTransfer.overviewSubtitle

        case .support:
            return "Contact us by email"

        case .about:
            return store.diagnostics.aboutOverviewSubtitle
        }
    }

    private var value: String? {
        switch section {
        case .notifications:
            return store.notifications.notificationsEnabled ? "On" : "Off"
        case .iCloud:
            return store.cloud.cloudSyncAvailable ? nil : "Off"
        case .git:
            return (store.github.connectedRepository != nil || store.gitlab.isConnected) ? "Live" : nil
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

struct SettingsMacDetailView: View {
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
        case .git:
            SettingsMacGitDetailView(store: store)
        case .backup:
            SettingsMacBackupDetailView(store: store)
        case .support:
            SettingsMacSupportDetailView(store: store)
        case .about:
            SettingsMacAboutDetailView(store: store)
        }
    }
}

struct EmbeddedSettingsMacDetailView: View {
    let store: StoreOf<SettingsFeature>
    let section: SettingsMacSection
    @State private var isPlacePickerPresented = false

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailView(
                section: section == .git && !store.appearance.isGitFeaturesEnabled ? .appearance : section,
                store: store,
                isPlacePickerPresented: $isPlacePickerPresented
            )
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
                    .disabled(store.notifications.notificationsEnabled == false)

                    Text("Notifications include quick actions for Done and Snooze.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if store.notifications.systemSettingsNotificationsEnabled == false {
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
            get: { store.notifications.notificationsEnabled },
            set: { store.send(.toggleNotifications($0)) }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { store.notifications.notificationReminderTime },
            set: { store.send(.notificationReminderTimeChanged($0)) }
        )
    }
}

private struct SettingsMacGitDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "Git",
                subtitle: "Connect GitHub or GitLab to display contribution activity on your dashboard."
            ) {
                Text("GitHub")
                    .font(.title2.weight(.semibold))

                SettingsMacDetailCard(title: "Mode") {
                    Picker("Source", selection: scopeBinding) {
                        ForEach(GitHubStatsScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(store.github.scope.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if store.github.scope == .repository {
                    SettingsMacDetailCard(title: "Repository") {
                        TextField("Owner", text: repositoryOwnerBinding)
                            .textFieldStyle(.roundedBorder)

                        TextField("Repository", text: repositoryNameBinding)
                            .textFieldStyle(.roundedBorder)

                        Text(store.github.repositorySummaryText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let validationMessage = store.github.saveValidationMessage {
                            Text(validationMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    SettingsMacDetailCard(title: "Profile") {
                        Text(store.github.profileSummaryText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let validationMessage = store.github.saveValidationMessage {
                            Text(validationMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }

                SettingsMacDetailCard(title: "Access Token") {
                    SecureField("Personal access token", text: gitHubAccessTokenBinding)
                        .textFieldStyle(.roundedBorder)

                    Text(store.github.tokenStatusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Actions") {
                    HStack(spacing: 12) {
                        Button {
                            store.send(.saveGitHubConnectionTapped)
                        } label: {
                            if store.github.isOperationInProgress {
                                ProgressView()
                            } else {
                                Label(store.github.saveButtonTitle, systemImage: "link.badge.plus")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.github.isSaveDisabled)

                        Button(role: .destructive) {
                            store.send(.clearGitHubConnectionTapped)
                        } label: {
                            Label("Remove Connection", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.github.removeButtonDisabled)
                    }

                    Text(store.github.infoText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !store.github.statusMessage.isEmpty {
                    SettingsMacDetailCard(title: "Status") {
                        Text(store.github.statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("GitLab")
                    .font(.title2.weight(.semibold))
                    .padding(.top, 8)

                SettingsMacDetailCard(title: "Profile") {
                    Text(store.gitlab.profileSummaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let validationMessage = store.gitlab.saveValidationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                SettingsMacDetailCard(title: "Access Token") {
                    SecureField("Personal access token", text: gitLabAccessTokenBinding)
                        .textFieldStyle(.roundedBorder)

                    Text(store.gitlab.tokenStatusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Actions") {
                    HStack(spacing: 12) {
                        Button {
                            store.send(.saveGitLabConnectionTapped)
                        } label: {
                            if store.gitlab.isOperationInProgress {
                                ProgressView()
                            } else {
                                Label(store.gitlab.saveButtonTitle, systemImage: "link.badge.plus")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.gitlab.isSaveDisabled)

                        Button(role: .destructive) {
                            store.send(.clearGitLabConnectionTapped)
                        } label: {
                            Label("Remove Connection", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.gitlab.removeButtonDisabled)
                    }

                    Text(store.gitlab.infoText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !store.gitlab.statusMessage.isEmpty {
                    SettingsMacDetailCard(title: "Status") {
                        Text(store.gitlab.statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var scopeBinding: Binding<GitHubStatsScope> {
        Binding(
            get: { store.github.scope },
            set: { store.send(.gitHubScopeChanged($0)) }
        )
    }

    private var repositoryOwnerBinding: Binding<String> {
        Binding(
            get: { store.github.repositoryOwner },
            set: { store.send(.gitHubOwnerChanged($0)) }
        )
    }

    private var repositoryNameBinding: Binding<String> {
        Binding(
            get: { store.github.repositoryName },
            set: { store.send(.gitHubRepositoryChanged($0)) }
        )
    }

    private var gitHubAccessTokenBinding: Binding<String> {
        Binding(
            get: { store.github.accessTokenDraft },
            set: { store.send(.gitHubTokenChanged($0)) }
        )
    }

    private var gitLabAccessTokenBinding: Binding<String> {
        Binding(
            get: { store.gitlab.accessTokenDraft },
            set: { store.send(.gitLabTokenChanged($0)) }
        )
    }
}

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

struct SettingsMacTagsDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "Tags",
                subtitle: "Review every tag in Routina and rename or remove them globally."
            ) {
                SettingsMacDetailCard(title: "All Tags") {
                    if store.tags.savedTags.isEmpty {
                        Text("No tags yet. Tags you add to routines will appear here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.tags.savedTags.enumerated()), id: \.element.id) { index, tag in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(tag.name)
                                        Text(tag.settingsSubtitle)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                        HStack(spacing: 8) {
                                            TextField("Related tags", text: relatedTagDraftBinding(for: tag.name))
                                                .textFieldStyle(.roundedBorder)
                                                .disabled(store.tags.isTagOperationInProgress)

                                            Button {
                                                store.send(.saveRelatedTagsTapped(tag.name))
                                            } label: {
                                                Label("Save related tags", systemImage: "checkmark.circle")
                                            }
                                            .labelStyle(.iconOnly)
                                            .buttonStyle(.borderless)
                                            .disabled(store.tags.isTagOperationInProgress)
                                            .help("Save related tags")
                                        }
                                    }

                                    Spacer()

                                    Button {
                                        store.send(.renameTagTapped(tag.name))
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(store.tags.isTagOperationInProgress)

                                    Button(role: .destructive) {
                                        store.send(.deleteTagTapped(tag.name))
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(store.tags.isTagOperationInProgress)
                                }
                                .padding(.vertical, 12)

                                if index < store.tags.savedTags.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                if !store.tags.tagStatusMessage.isEmpty {
                    SettingsMacDetailCard(title: "Status") {
                        Text(store.tags.tagStatusMessage)
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
                Text(store.tags.deleteConfirmationMessage)
            }
            .sheet(isPresented: renameTagSheetBinding) {
                SettingsTagRenameSheet(store: store)
            }
        }
    }

    private var deleteTagConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.tags.isDeleteTagConfirmationPresented },
            set: { store.send(.setDeleteTagConfirmation($0)) }
        )
    }

    private var renameTagSheetBinding: Binding<Bool> {
        Binding(
            get: { store.tags.isTagRenameSheetPresented },
            set: { store.send(.setTagRenameSheet($0)) }
        )
    }

    private func relatedTagDraftBinding(for tagName: String) -> Binding<String> {
        Binding(
            get: {
                guard let key = RoutineTag.normalized(tagName) else { return "" }
                return store.tags.relatedTagDrafts[key] ?? ""
            },
            set: { store.send(.relatedTagDraftChanged(tagName: tagName, draft: $0)) }
        )
    }
}

private struct SettingsMacAppearanceDetailView: View {
    let store: StoreOf<SettingsFeature>

    @AppStorage("macTodoBoardCompactCards", store: SharedDefaults.app)
    private var isMacTodoBoardCompactCards = false

    private let columns = [
        GridItem(.adaptive(minimum: 124), spacing: 12)
    ]

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "Appearance",
                subtitle: "Pick the app icon you want to see in the Dock and app switcher, and choose how the home list is grouped."
            ) {
                SettingsMacDetailCard(title: "Routine List") {
                    Picker("Grouping", selection: routineListSectioningModeBinding) {
                        ForEach(RoutineListSectioningMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(store.appearance.routineListSectioningSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Todo Board") {
                    Toggle("Compact cards", isOn: $isMacTodoBoardCompactCards)
                        .toggleStyle(.switch)

                    Text(
                        isMacTodoBoardCompactCards
                            ? "Shows a denser board for longer columns."
                            : "Shows fuller cards with a little more breathing room."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Tag Counters") {
                    Picker("Display", selection: tagCounterDisplayModeBinding) {
                        ForEach(TagCounterDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(store.appearance.tagCounterDisplayMode.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "App Lock") {
                    Toggle("Require unlock when opening Routina", isOn: appLockBinding)
                        .toggleStyle(.switch)
                        .disabled(store.appearance.isAppLockToggleInProgress)

                    if store.appearance.isAppLockToggleInProgress {
                        ProgressView("Verifying device authentication…")
                            .controlSize(.small)
                    }

                    Text(store.appearance.appLockDetailText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Advanced") {
                    Toggle("Enable Git features", isOn: gitFeaturesBinding)
                        .toggleStyle(.switch)

                    Text("Shows GitHub and GitLab connection settings and contribution activity in Stats.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Temporary View State") {
                    Button {
                        guard store.appearance.hasTemporaryViewStateToReset else { return }
                        store.send(.resetTemporaryViewStateTapped)
                    } label: {
                        Label(resetButtonTitle, systemImage: resetButtonSystemImage)
                    }
                    .buttonStyle(.bordered)
                    .tint(store.appearance.hasTemporaryViewStateToReset ? .red : .gray)
                    .disabled(!store.appearance.hasTemporaryViewStateToReset)

                    Text(resetButtonDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "App Icon") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppIconOption.allCases) { option in
                            SettingsMacAppIconButton(
                                option: option,
                                isSelected: store.appearance.selectedAppIcon == option
                            ) {
                                store.send(.appIconSelected(option))
                            }
                        }
                    }

                    Text("Changes the Dock and app switcher icon immediately. Finder keeps the bundled app icon.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !store.appearance.appIconStatusMessage.isEmpty {
                    SettingsMacDetailCard(title: "Status") {
                        Text(store.appearance.appIconStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !store.appearance.appLockStatusMessage.isEmpty {
                    SettingsMacDetailCard(title: "Status") {
                        Text(store.appearance.appLockStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !store.appearance.temporaryViewStateStatusMessage.isEmpty {
                    SettingsMacDetailCard(title: "Status") {
                        Text(store.appearance.temporaryViewStateStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var routineListSectioningModeBinding: Binding<RoutineListSectioningMode> {
        Binding(
            get: { store.appearance.routineListSectioningMode },
            set: { store.send(.routineListSectioningModeChanged($0)) }
        )
    }

    private var appLockBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.isAppLockEnabled },
            set: { store.send(.appLockToggled($0)) }
        )
    }

    private var gitFeaturesBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.isGitFeaturesEnabled },
            set: { store.send(.gitFeaturesToggled($0)) }
        )
    }

    private var resetButtonTitle: String {
        store.appearance.hasTemporaryViewStateToReset
            ? "Reset Filters and Selections"
            : "Filters and Selections Are Clear"
    }

    private var tagCounterDisplayModeBinding: Binding<TagCounterDisplayMode> {
        Binding(
            get: { store.appearance.tagCounterDisplayMode },
            set: { store.send(.tagCounterDisplayModeChanged($0)) }
        )
    }

    private var resetButtonSystemImage: String {
        store.appearance.hasTemporaryViewStateToReset
            ? "arrow.counterclockwise"
            : "checkmark.circle"
    }

    private var resetButtonDescription: String {
        store.appearance.hasTemporaryViewStateToReset
            ? "Clears saved filters, list mode choices, and other temporary view selections so the app opens with defaults again."
            : "Everything is already using the default filters and temporary selections."
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

                        if store.cloud.isCloudSyncInProgress || store.cloud.isCloudDataResetInProgress {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }

                SettingsMacDetailCard(title: "Status") {
                    Text(store.cloud.syncStatusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Estimated Usage") {
                    settingsInfoRow(title: "Estimated iCloud Data", value: store.cloud.usageTotalText)
                    settingsInfoRow(title: "Tasks", value: "\(store.cloud.cloudUsageEstimate.taskCount) • \(store.cloud.usageTaskPayloadText)")
                    settingsInfoRow(title: "Logs", value: "\(store.cloud.cloudUsageEstimate.logCount) • \(store.cloud.usageLogPayloadText)")
                    settingsInfoRow(title: "Places", value: "\(store.cloud.cloudUsageEstimate.placeCount) • \(store.cloud.usagePlacePayloadText)")
                    settingsInfoRow(title: "Images", value: "\(store.cloud.cloudUsageEstimate.imageCount) • \(store.cloud.usageImagePayloadText)")

                    Text(store.cloud.usageSummaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(store.cloud.usageFootnoteText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var actionsDisabled: Bool {
        store.cloud.isCloudSyncInProgress ||
        store.cloud.isCloudDataResetInProgress ||
        !store.cloud.cloudSyncAvailable
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
                        .disabled(store.dataTransfer.isDataTransferInProgress)

                        Button {
                            store.send(.importRoutineDataTapped)
                        } label: {
                            Label("Load JSON", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.dataTransfer.isDataTransferInProgress)

                        if store.dataTransfer.isDataTransferInProgress {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    Text(store.dataTransfer.statusText)
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
                    settingsInfoRow(title: "Version", value: store.diagnostics.appVersion)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 5) {
                            store.send(.aboutSectionLongPressed)
                        }
                }

                if store.diagnostics.isDebugSectionVisible {
                    SettingsMacDetailCard(title: "Diagnostics") {
                        settingsInfoRow(title: "Data Mode", value: store.diagnostics.dataModeDescription)
                        settingsInfoRow(title: "iCloud Container", value: store.diagnostics.iCloudContainerDescription)

                        Text("Last CloudKit Event: \(store.diagnostics.cloudDiagnosticsTimestamp)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(store.diagnostics.cloudDiagnosticsSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(store.diagnostics.pushDiagnosticsStatus)
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

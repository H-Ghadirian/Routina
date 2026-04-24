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
                            subtitle: store.notifications.overviewSubtitle,
                            value: store.notifications.notificationsEnabled ? "On" : "Off"
                        )
                    }

                    NavigationLink {
                        SettingsPlacesDetailView(store: store)
                    } label: {
                        SettingsNavigationRow(
                            icon: "mappin.and.ellipse",
                            tint: .blue,
                            title: "Places",
                            subtitle: store.places.overviewSubtitle
                        )
                    }

                    NavigationLink {
                        SettingsTagsDetailView(store: store)
                    } label: {
                        SettingsNavigationRow(
                            icon: "tag.fill",
                            tint: .pink,
                            title: "Tags",
                            subtitle: store.tags.overviewSubtitle
                        )
                    }

                    NavigationLink {
                        SettingsAppearanceDetailView(store: store)
                    } label: {
                        SettingsNavigationRow(
                            icon: "app.badge.fill",
                            tint: .orange,
                            title: "Appearance",
                            subtitle: store.appearance.overviewSubtitle
                        )
                    }

                    NavigationLink {
                        SettingsCloudDetailView(store: store)
                    } label: {
                        SettingsNavigationRow(
                            icon: "icloud.fill",
                            tint: .cyan,
                            title: "iCloud",
                            subtitle: store.cloud.overviewSubtitle,
                            value: store.cloud.cloudSyncAvailable ? nil : "Off"
                        )
                    }

                    NavigationLink {
                        SettingsGitDetailView(store: store)
                    } label: {
                        SettingsNavigationRow(
                            icon: "arrow.triangle.branch",
                            tint: .indigo,
                            title: "Git",
                            subtitle: {
                                let ghConnected = store.github.connectedRepository != nil
                                let glConnected = store.gitlab.isConnected
                                if ghConnected && glConnected { return "GitHub & GitLab connected" }
                                if glConnected { return store.gitlab.overviewSubtitle }
                                return store.github.overviewSubtitle
                            }(),
                            value: (store.github.connectedRepository != nil || store.gitlab.isConnected) ? "Live" : nil
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
                            subtitle: store.diagnostics.aboutOverviewSubtitle
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SettingsGitDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("GitHub – Mode") {
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
                    Section("GitHub – Repository") {
                        TextField("Owner", text: repositoryOwnerBinding)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        TextField("Repository", text: repositoryNameBinding)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

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
                    Section("GitHub – Profile") {
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

                Section("GitHub – Access Token") {
                    SecureField("Personal access token", text: gitHubAccessTokenBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text(store.github.tokenStatusText)
                        .foregroundStyle(.secondary)
                }

                Section("GitHub – Actions") {
                    Button {
                        store.send(.saveGitHubConnectionTapped)
                    } label: {
                        HStack {
                            if store.github.isOperationInProgress {
                                ProgressView()
                            } else {
                                Label(store.github.saveButtonTitle, systemImage: "link.badge.plus")
                            }
                        }
                    }
                    .disabled(store.github.isSaveDisabled)

                    Button(role: .destructive) {
                        store.send(.clearGitHubConnectionTapped)
                    } label: {
                        Label("Remove Connection", systemImage: "trash")
                    }
                    .disabled(store.github.removeButtonDisabled)
                }

                Section("GitHub – Info") {
                    Text(store.github.infoText)
                        .foregroundStyle(.secondary)
                }

                if !store.github.statusMessage.isEmpty {
                    Section("GitHub – Status") {
                        Text(store.github.statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("GitLab – Profile") {
                    Text(store.gitlab.profileSummaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let validationMessage = store.gitlab.saveValidationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("GitLab – Access Token") {
                    SecureField("Personal access token", text: gitLabAccessTokenBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text(store.gitlab.tokenStatusText)
                        .foregroundStyle(.secondary)
                }

                Section("GitLab – Actions") {
                    Button {
                        store.send(.saveGitLabConnectionTapped)
                    } label: {
                        HStack {
                            if store.gitlab.isOperationInProgress {
                                ProgressView()
                            } else {
                                Label(store.gitlab.saveButtonTitle, systemImage: "link.badge.plus")
                            }
                        }
                    }
                    .disabled(store.gitlab.isSaveDisabled)

                    Button(role: .destructive) {
                        store.send(.clearGitLabConnectionTapped)
                    } label: {
                        Label("Remove Connection", systemImage: "trash")
                    }
                    .disabled(store.gitlab.removeButtonDisabled)
                }

                Section("GitLab – Info") {
                    Text(store.gitlab.infoText)
                        .foregroundStyle(.secondary)
                }

                if !store.gitlab.statusMessage.isEmpty {
                    Section("GitLab – Status") {
                        Text(store.gitlab.statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Git")
            .navigationBarTitleDisplayMode(.inline)
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
                    .disabled(store.notifications.notificationsEnabled == false)
                }

                Section("Info") {
                    Text("Notifications include quick actions for Done and Snooze.")
                        .foregroundStyle(.secondary)
                }

                if store.notifications.systemSettingsNotificationsEnabled == false {
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

struct SettingsPlacesDetailView: View {
    let store: StoreOf<SettingsFeature>
    @State private var isPlacePickerPresented = false

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("Add Place") {
                    TextField("Place name", text: placeDraftNameBinding)

                    if let validationMessage = store.places.saveValidationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button {
                        isPlacePickerPresented = true
                    } label: {
                        Label(store.places.selectionButtonTitle, systemImage: "map")
                    }

                    Text(store.places.draftSelectionSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        store.send(.savePlaceTapped)
                    } label: {
                        HStack {
                            if store.places.isPlaceOperationInProgress {
                                ProgressView()
                            } else {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(.blue)
                            }
                            Text("Save Place")
                        }
                    }
                    .disabled(store.places.isSaveDisabled)
                }

                Section("Location") {
                    Text(store.places.locationHelpText)
                        .foregroundStyle(.secondary)

                    if store.places.locationAuthorizationStatus.needsSettingsChange {
                        Button("Open System Settings") {
                            store.send(.openAppSettingsTapped)
                        }
                    }
                }

                if !store.places.placeStatusMessage.isEmpty {
                    Section("Status") {
                        Text(store.places.placeStatusMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Saved Places") {
                    if store.places.savedPlaces.isEmpty {
                        Text("No places saved yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.places.savedPlaces) { place in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.name)
                                Text(place.settingsSubtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    store.send(.deletePlaceTapped(place.id))
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .disabled(store.places.isPlaceOperationInProgress)
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

    private var placeDraftNameBinding: Binding<String> {
        Binding(
            get: { store.places.placeDraftName },
            set: { store.send(.placeDraftNameChanged($0)) }
        )
    }

    private var deletePlaceConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.places.isDeletePlaceConfirmationPresented },
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
                    if store.tags.savedTags.isEmpty {
                        Text("No tags yet. Tags you add to routines will appear here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.tags.savedTags) { tag in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(tag.name)
                                        Text(tag.settingsSubtitle)
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
                                    .disabled(store.tags.isTagOperationInProgress)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    TextField("Related tags", text: relatedTagDraftBinding(for: tag.name))
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .disabled(store.tags.isTagOperationInProgress)

                                    Button {
                                        store.send(.saveRelatedTagsTapped(tag.name))
                                    } label: {
                                        Label("Save related tags", systemImage: "checkmark.circle")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(store.tags.isTagOperationInProgress)

                                    Text("Separate related tags with commas.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
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

                if !store.tags.tagStatusMessage.isEmpty {
                    Section("Status") {
                        Text(store.tags.tagStatusMessage)
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
                Text(store.tags.deleteConfirmationMessage)
            }
            .sheet(isPresented: renameTagSheetBinding) {
                SettingsTagRenameSheet(store: store)
                    .presentationDetents([.height(240)])
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

private struct SettingsAppearanceDetailView: View {
    let store: StoreOf<SettingsFeature>
    @State private var resetFeedbackTrigger = false

    private let columns = [
        GridItem(.adaptive(minimum: 108), spacing: 12)
    ]

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("Routine List") {
                    Picker("Grouping", selection: routineListSectioningModeBinding) {
                        ForEach(RoutineListSectioningMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(store.appearance.routineListSectioningSubtitle)
                        .foregroundStyle(.secondary)
                }

                Section("Tag Counters") {
                    Picker("Display", selection: tagCounterDisplayModeBinding) {
                        ForEach(TagCounterDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(store.appearance.tagCounterDisplayMode.subtitle)
                        .foregroundStyle(.secondary)
                }

                Section("App Lock") {
                    Toggle("Require unlock when opening Routina", isOn: appLockBinding)
                        .disabled(store.appearance.isAppLockToggleInProgress)

                    if store.appearance.isAppLockToggleInProgress {
                        ProgressView("Verifying device authentication…")
                    }

                    Text(store.appearance.appLockDetailText)
                        .foregroundStyle(.secondary)
                }

                Section("Temporary View State") {
                    Button {
                        guard store.appearance.hasTemporaryViewStateToReset else { return }
                        resetFeedbackTrigger.toggle()
                        store.send(.resetTemporaryViewStateTapped)
                    } label: {
                        Label(resetButtonTitle, systemImage: resetButtonSystemImage)
                            .foregroundStyle(resetButtonForegroundStyle)
                    }
                    .disabled(!store.appearance.hasTemporaryViewStateToReset)

                    Text(resetButtonDescription)
                        .foregroundStyle(.secondary)
                }

                Section("App Icon") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppIconOption.allCases) { option in
                            SettingsAppIconButton(
                                option: option,
                                isSelected: store.appearance.selectedAppIcon == option
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

                if !store.appearance.appIconStatusMessage.isEmpty {
                    Section("Status") {
                        Text(store.appearance.appIconStatusMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                if !store.appearance.appLockStatusMessage.isEmpty {
                    Section("Status") {
                        Text(store.appearance.appLockStatusMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                if !store.appearance.temporaryViewStateStatusMessage.isEmpty {
                    Section("Status") {
                        Text(store.appearance.temporaryViewStateStatusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.success, trigger: resetFeedbackTrigger)
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

    private var resetButtonForegroundStyle: AnyShapeStyle {
        store.appearance.hasTemporaryViewStateToReset
            ? AnyShapeStyle(Color.red)
            : AnyShapeStyle(Color.secondary)
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
                    if store.cloud.isCloudSyncInProgress || store.cloud.isCloudDataResetInProgress {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(store.cloud.syncStatusText)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(store.cloud.syncStatusText)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Estimated Usage") {
                    infoRow(title: "Estimated iCloud Data", value: store.cloud.usageTotalText)
                    infoRow(title: "Tasks", value: "\(store.cloud.cloudUsageEstimate.taskCount) • \(store.cloud.usageTaskPayloadText)")
                    infoRow(title: "Logs", value: "\(store.cloud.cloudUsageEstimate.logCount) • \(store.cloud.usageLogPayloadText)")
                    infoRow(title: "Places", value: "\(store.cloud.cloudUsageEstimate.placeCount) • \(store.cloud.usagePlacePayloadText)")
                    infoRow(title: "Images", value: "\(store.cloud.cloudUsageEstimate.imageCount) • \(store.cloud.usageImagePayloadText)")

                    Text(store.cloud.usageSummaryText)
                        .foregroundStyle(.secondary)
                    Text(store.cloud.usageFootnoteText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        store.cloud.isCloudSyncInProgress ||
        store.cloud.isCloudDataResetInProgress ||
        !store.cloud.cloudSyncAvailable
    }

    private var cloudDataResetConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.cloud.isCloudDataResetConfirmationPresented },
            set: { store.send(.setCloudDataResetConfirmation($0)) }
        )
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
                        Text(store.diagnostics.appVersion)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 5) {
                        store.send(.aboutSectionLongPressed)
                    }
                }

                if store.diagnostics.isDebugSectionVisible {
                    Section("Diagnostics") {
                        infoRow(title: "Data Mode", value: store.diagnostics.dataModeDescription)
                        infoRow(title: "iCloud Container", value: store.diagnostics.iCloudContainerDescription)

                        Text("Last CloudKit Event: \(store.diagnostics.cloudDiagnosticsTimestamp)")
                            .foregroundStyle(.secondary)
                        Text(store.diagnostics.cloudDiagnosticsSummary)
                            .foregroundStyle(.secondary)
                        Text(store.diagnostics.pushDiagnosticsStatus)
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

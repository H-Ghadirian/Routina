import ComposableArchitecture
import SwiftData
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

struct SettingsMacDetailView: View {
    let section: SettingsMacSection
    let store: StoreOf<SettingsFeature>
    @Binding var isPlacePickerPresented: Bool

    var body: some View {
        switch section {
        case .notifications:
            SettingsMacNotificationsDetailView(store: store)
        case .calendar:
            SettingsMacCalendarDetailView(store: store)
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

private struct SettingsMacCalendarDetailView: View {
    let store: StoreOf<SettingsFeature>
    @Query private var existingTasks: [RoutineTask]
    @State private var isCalendarTaskImportPresented = false

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "Calendar",
                subtitle: "Review calendar events before adding tasks and choose how dates are displayed."
            ) {
                SettingsMacDetailCard(title: "Calendar Tasks") {
                    Button {
                        isCalendarTaskImportPresented = true
                    } label: {
                        Label("Review Calendar Tasks", systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Text("Review Apple Calendar or Outlook events one by one before adding them as tasks.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Date Display") {
                    Toggle("Show Persian date beside dates", isOn: showPersianDatesBinding)
                        .toggleStyle(.switch)

                    if store.appearance.showPersianDates {
                        Text(persianDatePreviewText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("Keeps the app schedule unchanged and adds a Persian calendar date next to visible Gregorian dates.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $isCalendarTaskImportPresented) {
                CalendarTaskImportSheet(existingTasks: existingTasks) {}
            }
        }
    }

    private var showPersianDatesBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.showPersianDates },
            set: { store.send(.showPersianDatesToggled($0)) }
        )
    }

    private var persianDatePreviewText: String {
        let today = Date()
        let dateText = today.formatted(date: .abbreviated, time: .omitted)
        return "Today: " + PersianDateDisplay.appendingSupplementaryDate(
            to: dateText,
            for: today,
            enabled: true
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
                subtitle: "Choose the app theme, pick the Dock icon, and decide how the home list is grouped."
            ) {
                SettingsMacDetailCard(title: "App Theme") {
                    Picker("Theme", selection: appColorSchemeBinding) {
                        ForEach(AppColorScheme.allCases) { scheme in
                            Text(scheme.title).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(store.appearance.appColorScheme.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

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

    private var appColorSchemeBinding: Binding<AppColorScheme> {
        Binding(
            get: { store.appearance.appColorScheme },
            set: { store.send(.appColorSchemeChanged($0)) }
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

import ComposableArchitecture
import SwiftData
import SwiftUI
import UIKit

struct SettingsPlatformRootView: View {
    let store: StoreOf<SettingsFeature>
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if usesSidebarLayout {
            SettingsIPadSplitView(store: store)
        } else {
            NavigationStack {
                SettingsIOSRootView(store: store)
            }
        }
    }

    private var usesSidebarLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }
}

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
                        SettingsCalendarDetailView(store: store)
                    } label: {
                        SettingsNavigationRow(
                            icon: "calendar.badge.plus",
                            tint: .purple,
                            title: "Calendar",
                            subtitle: store.appearance.showPersianDates
                                ? "Review tasks and show Persian dates"
                                : "Review tasks and date display",
                            value: store.appearance.showPersianDates ? "Persian" : nil
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

                    if store.appearance.isGitFeaturesEnabled {
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
                }

                Section {
                    NavigationLink {
                        SettingsDataBackupDetailView(store: store)
                    } label: {
                        SettingsNavigationRow(
                            icon: "externaldrive.fill",
                            tint: .indigo,
                            title: "Data Backup",
                            subtitle: store.dataTransfer.overviewSubtitle
                        )
                    }

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

private struct SettingsIPadSplitView: View {
    let store: StoreOf<SettingsFeature>
    @State private var selectedSection: SettingsIOSSection? = .notifications

    var body: some View {
        WithPerceptionTracking {
            NavigationSplitView {
                List(selection: $selectedSection) {
                    ForEach(SettingsIOSSection.visibleSections(isGitFeaturesEnabled: store.appearance.isGitFeaturesEnabled)) { section in
                        SettingsIPadSidebarRow(
                            section: section,
                            store: store
                        )
                        .tag(section)
                    }
                }
                .listStyle(.sidebar)
                .navigationTitle("Settings")
                .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 400)
            } detail: {
                settingsDetail(for: selectedDetailSection)
            }
            .navigationSplitViewStyle(.balanced)
            .onChange(of: store.appearance.isGitFeaturesEnabled) { _, isEnabled in
                if !isEnabled, selectedSection == .git {
                    selectedSection = .appearance
                }
            }
        }
    }

    private var selectedDetailSection: SettingsIOSSection {
        let fallback = selectedSection ?? .notifications
        if fallback == .git, !store.appearance.isGitFeaturesEnabled {
            return .appearance
        }
        return fallback
    }

    @ViewBuilder
    private func settingsDetail(for section: SettingsIOSSection) -> some View {
        switch section {
        case .notifications:
            SettingsNotificationsDetailView(store: store)
        case .calendar:
            SettingsCalendarDetailView(store: store)
        case .places:
            SettingsPlacesDetailView(store: store)
        case .tags:
            SettingsTagsDetailView(store: store)
        case .appearance:
            SettingsAppearanceDetailView(store: store)
        case .iCloud:
            SettingsCloudDetailView(store: store)
        case .git:
            SettingsGitDetailView(store: store)
        case .backup:
            SettingsDataBackupDetailView(store: store)
        case .shortcuts:
            SettingsIOSShortcutsDetailView()
        case .support:
            SettingsSupportDetailView(store: store)
        case .about:
            SettingsAboutDetailView(store: store)
        }
    }
}

private typealias SettingsIOSSection = SettingsSectionID

private extension SettingsIOSSection {
    var tint: Color {
        switch self {
        case .notifications:
            return .red
        case .calendar:
            return .purple
        case .places:
            return .blue
        case .tags:
            return .pink
        case .appearance:
            return .orange
        case .iCloud:
            return .cyan
        case .git, .backup:
            return .indigo
        case .shortcuts:
            return .teal
        case .support:
            return .green
        case .about:
            return .gray
        }
    }
}

private struct SettingsIOSShortcutsDetailView: View {
    var body: some View {
        List {
            Section("Apple Shortcuts & Siri") {
                SettingsNavigationRow(
                    icon: "text.badge.plus",
                    tint: .teal,
                    title: "Quick Add",
                    subtitle: "Quick add in Routina"
                )
                SettingsNavigationRow(
                    icon: "checkmark.circle",
                    tint: .green,
                    title: "Mark Done",
                    subtitle: "Mark task done in Routina"
                )
                SettingsNavigationRow(
                    icon: "timer",
                    tint: .orange,
                    title: "Start Focus",
                    subtitle: "Start focus in Routina"
                )
                SettingsNavigationRow(
                    icon: "calendar",
                    tint: .blue,
                    title: "Today",
                    subtitle: "Today in Routina"
                )
            }
        }
        .navigationTitle("Shortcuts")
    }
}

private struct SettingsIPadSidebarRow: View {
    let section: SettingsIOSSection
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsNavigationRow(
                icon: section.icon,
                tint: section.tint,
                title: section.title,
                subtitle: presentation.subtitle,
                value: presentation.value
            )
        }
    }

    private var presentation: SettingsSectionRowPresentation {
        section.rowPresentation(in: store.state)
    }
}

private struct SettingsCalendarDetailView: View {
    let store: StoreOf<SettingsFeature>
    @Query private var existingTasks: [RoutineTask]
    @State private var isCalendarTaskImportPresented = false

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("Calendar Tasks") {
                    Button {
                        isCalendarTaskImportPresented = true
                    } label: {
                        Label("Review Calendar Tasks", systemImage: "calendar.badge.plus")
                    }

                    Text("Review Apple Calendar or Outlook events one by one before adding them as tasks.")
                        .foregroundStyle(.secondary)
                }

                Section("Date Display") {
                    Toggle("Show Persian date beside dates", isOn: showPersianDatesBinding)

                    if store.appearance.showPersianDates {
                        Text(persianDatePreviewText)
                            .foregroundStyle(.secondary)
                    }

                    Text("Keeps the app schedule unchanged and adds a Persian calendar date next to visible Gregorian dates.")
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
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

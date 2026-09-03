import ComposableArchitecture
import SwiftData
import SwiftUI

struct SettingsPlatformRootView: View {
    let store: StoreOf<SettingsFeature>
    let ownsCompactNavigationStack: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        if usesSidebarLayout {
            SettingsIPadSplitView(store: store)
        } else if ownsCompactNavigationStack {
            NavigationStack {
                SettingsIOSRootView(store: store)
            }
        } else {
            SettingsIOSRootView(store: store)
        }
    }

    private var usesSidebarLayout: Bool {
        horizontalSizeClass == .regular && verticalSizeClass != .compact
    }
}

struct SettingsIOSRootView: View {
    let store: StoreOf<SettingsFeature>
    @State private var settingsSearchQuery = ""
    @AppStorage(
        UserDefaultBoolValueKey.appSettingSettingsDevicesSectionEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isDevicesSectionEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false

    var body: some View {
List {
    if filteredSectionGroups.isEmpty {
        ContentUnavailableView("No Matching Settings", systemImage: "magnifyingglass")
    } else {
        ForEach(filteredSectionGroups, id: \.self) { sections in
            Section {
                ForEach(sections) { section in
                    NavigationLink {
                        SettingsIOSDetailView(section: section, store: store)
                    } label: {
                        SettingsIOSSectionRow(
                            section: section,
                            store: store,
                            searchQuery: settingsSearchQuery
                        )
                    }
                }
            }
        }
    }
}
.listStyle(.insetGrouped)
.contentMargins(.top, 0, for: .scrollContent)
.searchable(
    text: $settingsSearchQuery,
    placement: .navigationBarDrawer(displayMode: .always),
    prompt: "Search Settings"
)
.navigationTitle("Settings")
.navigationBarTitleDisplayMode(.inline)
    }

    private var filteredSectionGroups: [[SettingsIOSSection]] {
        SettingsIOSSection.filteredSectionGroups(
            SettingsIOSSection.compactSectionGroups(
                isGitFeaturesEnabled: store.appearance.isGitFeaturesEnabled,
                isDevicesSectionEnabled: isDevicesSectionEnabled,
                isPlacesEnabled: isPlacesEnabled
            ),
            matching: settingsSearchQuery
        )
    }
}

private struct SettingsIPadSplitView: View {
    let store: StoreOf<SettingsFeature>
    @State private var selectedSection: SettingsIOSSection? = .notifications
    @State private var settingsSearchQuery = ""
    @AppStorage(
        UserDefaultBoolValueKey.appSettingSettingsDevicesSectionEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isDevicesSectionEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false

    var body: some View {
NavigationSplitView {
    List(selection: $selectedSection) {
        if filteredVisibleSections.isEmpty {
            ContentUnavailableView("No Matching Settings", systemImage: "magnifyingglass")
        } else {
            ForEach(filteredVisibleSections) { section in
                SettingsIOSSectionRow(
                    section: section,
                    store: store,
                    searchQuery: settingsSearchQuery
                )
                .tag(section)
            }
        }
    }
    .listStyle(.sidebar)
    .searchable(
        text: $settingsSearchQuery,
        placement: .sidebar,
        prompt: "Search Settings"
    )
    .navigationTitle("Settings")
    .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 400)
} detail: {
    SettingsIOSDetailView(section: selectedDetailSection, store: store)
}
.navigationSplitViewStyle(.balanced)
    }

    private var selectedDetailSection: SettingsIOSSection {
        let candidate = selectedSection ?? .notifications
        let resolvedSection = candidate.resolvedNavigationSection
        guard visibleSections.contains(resolvedSection) else { return .general }
        return resolvedSection
    }

    private var visibleSections: [SettingsIOSSection] {
        SettingsIOSSection.visibleSections(
            isGitFeaturesEnabled: store.appearance.isGitFeaturesEnabled,
            isDevicesSectionEnabled: isDevicesSectionEnabled,
            isPlacesEnabled: isPlacesEnabled
        )
    }

    private var filteredVisibleSections: [SettingsIOSSection] {
        SettingsIOSSection.filteredSections(visibleSections, matching: settingsSearchQuery)
    }
}

typealias SettingsIOSSection = SettingsSectionID

struct SettingsIOSDetailView: View {
    let section: SettingsIOSSection
    let store: StoreOf<SettingsFeature>

    var body: some View {
        switch section {
        case .general:
            SettingsGeneralDetailView(store: store)
        case .devices:
            SettingsDevicesDetailView(store: store)
        case .notifications:
            SettingsNotificationsDetailView(store: store)
        case .blocking:
            #if ROUTINA_IOS_FAMILY_CONTROLS
            SettingsBlockingDetailView()
            #else
            EmptyView()
            #endif
        case .calendar:
            SettingsCalendarDetailView(store: store)
        case .places:
            SettingsPlacesDetailView(store: store)
        case .tags:
            SettingsTagsDetailView(store: store)
        case .flags:
            SettingsFlagsDetailView(store: store)
        case .sections:
            SettingsTaskSectionsUnavailableView()
        case .appearance:
            SettingsAppearanceDetailView(store: store)
        case .iCloud, .backup:
            SettingsCloudDetailView(store: store)
        case .git:
            SettingsGitDetailView(store: store)
        case .quickAdd:
            SettingsQuickAddDetailView()
        case .shortcuts:
            SettingsIOSShortcutsDetailView()
        case .aiConnections:
            SettingsAIConnectionsUnavailableView()
        case .support, .about:
            SettingsAboutDetailView(store: store)
        }
    }
}

private struct SettingsTaskSectionsUnavailableView: View {
    var body: some View {
        List {
            Section("Sections") {
                Text("Task list sections are managed on Mac.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Sections")
    }
}

private struct SettingsAIConnectionsUnavailableView: View {
    var body: some View {
        List {
            Section("AI Connections") {
                Text("Local AI connections are available in Routina for Mac.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("AI Connections")
    }
}

private struct SettingsIOSShortcutsDetailView: View {
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShakeToStartSleepEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isShakeToStartSleepEnabled = true
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingStatsSleepTabEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isSleepEnabled = false
    @AppStorage(
        IOSFirstTaskExperience.completionDefaultsKey,
        store: SharedDefaults.app
    ) private var hasCompletedFirstTaskExperience = true

    var body: some View {
        List {
            if showsSleepShortcuts {
                Section("Sleep Shortcut") {
                    Toggle("Shake to start sleep mode", isOn: $isShakeToStartSleepEnabled)

                    Text("Shake always asks for confirmation before sleep mode starts.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Apple Shortcuts & Siri") {
                SettingsNavigationRow(
                    icon: "text.badge.plus",
                    tint: .teal,
                    title: "Quick Add",
                    subtitle: "Quick add in Routina"
                )
                if hasCompletedFirstTaskExperience {
                    SettingsNavigationRow(
                        icon: "checkmark.circle",
                        tint: .green,
                        title: "Mark Done",
                        subtitle: "Mark task done in Routina"
                    )
                }
                SettingsNavigationRow(
                    icon: "timer",
                    tint: .orange,
                    title: "Start Focus",
                    subtitle: "Start focus in Routina"
                )
                if showsSleepShortcuts {
                    SettingsNavigationRow(
                        icon: "bed.double.fill",
                        tint: .indigo,
                        title: "Sleep",
                        subtitle: "I am going to sleep in Routina"
                    )
                    SettingsNavigationRow(
                        icon: "alarm.fill",
                        tint: .orange,
                        title: "Wake Up",
                        subtitle: "I woke up in Routina"
                    )
                }
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

    private var showsSleepShortcuts: Bool {
        isAwayEnabled && isSleepEnabled
    }
}

private struct SettingsQuickAddDetailView: View {
    @AppStorage(UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue, store: SharedDefaults.app)
    private var isPlacesEnabled = false
    @State private var settingsSearchQuery = ""

    var body: some View {
        List {
            Section("Examples") {
                ForEach(SettingsQuickAddSyntaxGuide.visibleExamples(includingPlaces: isPlacesEnabled)) { example in
                    SettingsQuickAddExampleBlock(example: example)
                }
            }

            ForEach(SettingsQuickAddSyntaxGuide.visibleSyntaxGroups(includingPlaces: isPlacesEnabled)) { group in
                Section(group.title) {
                    ForEach(group.rows) { row in
                        SettingsQuickAddSyntaxBlock(row: row)
                    }
                }
            }

            Section("Tips") {
                ForEach(SettingsQuickAddSyntaxGuide.visibleNotes(includingPlaces: isPlacesEnabled), id: \.self) { note in
                    SettingsQuickAddNoteBlock(note: note)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Quick Add")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsIOSSectionRow: View {
    let section: SettingsIOSSection
    let store: StoreOf<SettingsFeature>
    let searchQuery: String

    var body: some View {
SettingsNavigationRow(
    icon: section.icon,
    tint: section.tint,
    title: section.title,
    subtitle: section.searchResultSubtitle(for: searchQuery) ?? presentation.subtitle,
    value: presentation.value
)
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
List {
    Section("Calendar Tasks") {
        Button {
            isCalendarTaskImportPresented = true
        } label: {
            Label("Review Calendar Tasks", systemImage: "calendar.badge.plus")
        }

        Text("Review calendar events one by one before adding them as tasks.")
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

private struct SettingsNotificationsDetailView: View {
    let store: StoreOf<SettingsFeature>
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areEventEmotionActionsEnabled = false

    var body: some View {
List {
    Section("Reminders") {
        Toggle("Enable notifications", isOn: notificationsBinding)

        DatePicker(
            "Default time for untimed repeating tasks",
            selection: reminderTimeBinding,
            displayedComponents: .hourAndMinute
        )
        .disabled(store.notifications.notificationsEnabled == false)
    }

    Section("Info") {
        Text("Timed repeating tasks alert at their scheduled time. Notifications include quick actions for Done and Snooze.")
            .foregroundStyle(.secondary)
    }

    Section {
        if store.notifications.hasLoadedScheduledNotifications == false {
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading scheduled notifications…")
                    .foregroundStyle(.secondary)
            }
        } else if visibleScheduledNotifications.isEmpty {
            Text(scheduledNotificationsEmptyText)
                .foregroundStyle(.secondary)
        } else {
            ForEach(visibleScheduledNotificationGroups) { group in
                SettingsIOSScheduledNotificationGroup(
                    group: group,
                    store: store
                )
            }
        }
    } header: {
        Text(scheduledNotificationsTitle)
    } footer: {
        Text(scheduledNotificationsFooterText)
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

    private var scheduledNotificationsTitle: String {
        let count = visibleScheduledNotifications.count
        return count == 0 ? "Scheduled Notifications" : "Scheduled Notifications (\(count))"
    }

    private var visibleScheduledNotifications: [ScheduledNotificationSummary] {
        store.notifications.scheduledNotifications.filter {
            areEventEmotionActionsEnabled || $0.sourceKind != .event
        }
    }

    private var visibleScheduledNotificationGroups: [ScheduledNotificationGroup] {
        ScheduledNotificationGroup.groups(from: visibleScheduledNotifications)
    }

    private var scheduledNotificationsFooterText: String {
        let sources = areEventEmotionActionsEnabled ? "task or event" : "task"
        return "Notifications are grouped by \(sources). Expand a group to review its queued alerts, postpone one, or remove only that occurrence from this device."
    }

    private var scheduledNotificationsEmptyText: String {
        if store.notifications.notificationsEnabled == false {
            return "Turn on notifications to schedule reminders."
        }
        if store.notifications.systemSettingsNotificationsEnabled == false {
            return "Notifications are disabled in system settings, so nothing is scheduled."
        }
        return "No notifications are currently scheduled."
    }
}

private struct SettingsIOSScheduledNotificationGroup: View {
    let group: ScheduledNotificationGroup
    let store: StoreOf<SettingsFeature>

    var body: some View {
        DisclosureGroup {
            ForEach(group.notifications) { notification in
                SettingsIOSScheduledNotificationRow(
                    notification: notification,
                    store: store
                )
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: group.sourceKind == .event ? "calendar" : "bell")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(.body.weight(.medium))
                    Text(group.queueSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

}

private struct SettingsIOSScheduledNotificationRow: View {
    let notification: ScheduledNotificationSummary
    let store: StoreOf<SettingsFeature>
    @State private var isCustomPausePresented = false
    @State private var customPauseDate = Date()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Label(scheduledTimeText, systemImage: notification.isPaused ? "clock.badge" : "clock")
                    .font(.subheadline.weight(.medium))

                Text(notification.title.isEmpty ? "Routina notification" : notification.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if notification.isPaused, let originalScheduledAt = notification.originalScheduledAt {
                    Text("Originally \(originalScheduledAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !notification.detailText.isEmpty {
                    Text(notification.detailText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            notificationActionsMenu
        }
        .sheet(isPresented: $isCustomPausePresented) {
            SettingsIOSCustomNotificationPauseSheet(
                pauseDate: $customPauseDate,
                minimumDate: customPauseMinimumDate,
                sourceKind: notification.sourceKind,
                onCancel: { isCustomPausePresented = false },
                onPause: {
                    pause(until: customPauseDate)
                    isCustomPausePresented = false
                }
            )
            .presentationDetents([.medium])
        }
    }

    private var scheduledTimeText: String {
        notification.scheduledAt?.formatted(date: .abbreviated, time: .shortened)
            ?? "Scheduled time unavailable"
    }

    private var notificationActionsMenu: some View {
        Menu {
            Menu("Snooze") {
                Button("15 Minutes") {
                    pause(by: 15 * 60)
                }
                Button("1 Hour") {
                    pause(by: 60 * 60)
                }
                Button("Tomorrow") {
                    pauseUntilTomorrow()
                }
                Button("Choose Date & Time…") {
                    customPauseDate = pauseBaseDate.addingTimeInterval(60 * 60)
                    isCustomPausePresented = true
                }
            }

            Divider()

            Button("Remove This Alert", role: .destructive) {
                store.send(.removeScheduledNotificationTapped(notification))
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Actions for scheduled notification")
    }

    private func pause(by interval: TimeInterval) {
        pause(until: pauseBaseDate.addingTimeInterval(interval))
    }

    private func pauseUntilTomorrow() {
        pause(
            until: Calendar.current.date(byAdding: .day, value: 1, to: pauseBaseDate)
                ?? pauseBaseDate.addingTimeInterval(24 * 60 * 60)
        )
    }

    private func pause(until date: Date) {
        store.send(
            .pauseScheduledNotificationTapped(
                notification,
                until: date
            )
        )
    }

    private var pauseBaseDate: Date {
        max(notification.scheduledAt ?? Date(), Date())
    }

    private var customPauseMinimumDate: Date {
        pauseBaseDate.addingTimeInterval(60)
    }
}

private struct SettingsIOSCustomNotificationPauseSheet: View {
    @Binding var pauseDate: Date
    let minimumDate: Date
    let sourceKind: ScheduledNotificationSourceKind
    let onCancel: () -> Void
    let onPause: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Snooze until",
                        selection: $pauseDate,
                        in: minimumDate...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } footer: {
                    Text("This changes only the selected notification occurrence, not the \(sourceName) schedule.")
                }
            }
            .navigationTitle("Snooze Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Snooze", action: onPause)
                }
            }
        }
    }

    private var sourceName: String {
        sourceKind == .event ? "event" : "task"
    }
}

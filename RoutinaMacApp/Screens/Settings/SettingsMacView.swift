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
            SettingsMacSidebarRow(
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
    )
    .toolbar {
        RoutinaMacFocusTimerToolbarItem()
    }
}
.navigationSplitViewStyle(.balanced)
.settingsMacPresentations(
    store: store
)
    }

    private var selectedDetailSection: SettingsMacSection {
        let candidate = selectedSection ?? .notifications
        let resolvedSection = candidate.resolvedNavigationSection
        guard visibleSections.contains(resolvedSection) else { return .general }
        return resolvedSection
    }

    private var visibleSections: [SettingsMacSection] {
        SettingsMacSection.visibleSections(
            isGitFeaturesEnabled: store.appearance.isGitFeaturesEnabled,
            isDevicesSectionEnabled: isDevicesSectionEnabled,
            isPlacesEnabled: isPlacesEnabled
        )
    }

    private var filteredVisibleSections: [SettingsMacSection] {
        SettingsMacSection.filteredSections(visibleSections, matching: settingsSearchQuery)
    }
}

struct SettingsMacDetailView: View {
    let section: SettingsMacSection
    let store: StoreOf<SettingsFeature>

    var body: some View {
        switch section {
        case .general:
            SettingsMacGeneralDetailView(store: store)
        case .devices:
            SettingsMacDevicesDetailView(store: store)
        case .notifications:
            SettingsMacNotificationsDetailView(store: store)
        case .blocking:
            SettingsMacBlockingDetailView()
        case .calendar:
            SettingsMacCalendarDetailView(store: store)
        case .places:
            SettingsMacPlacesDetailView(
                store: store
            )
        case .tags:
            SettingsMacTagsDetailView(store: store)
        case .flags:
            SettingsMacFlagsDetailView(store: store)
        case .sections:
            SettingsMacTaskSectionsDetailView(
                availableTagSummaries: store.tags.savedTags
            )
        case .appearance:
            SettingsMacAppearanceDetailView(store: store)
        case .iCloud, .backup:
            SettingsMacCloudDetailView(store: store)
        case .git:
            SettingsMacGitDetailView(store: store)
        case .quickAdd:
            SettingsMacQuickAddDetailView()
        case .shortcuts:
            SettingsMacShortcutsDetailView()
        case .aiConnections:
            SettingsMacAIConnectionsDetailView()
        case .support, .about:
            SettingsMacAboutDetailView(store: store)
        }
    }
}

struct EmbeddedSettingsMacDetailView: View {
    let store: StoreOf<SettingsFeature>
    let section: SettingsMacSection

    var body: some View {
SettingsMacDetailView(
    section: section,
    store: store,
)
.settingsMacPresentations(
    store: store
)
    }
}

private struct SettingsMacNotificationsDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
SettingsMacDetailShell(
    title: "Notifications",
    subtitle: "Choose when Routina should remind you and review every notification currently scheduled on this Mac."
) {
    SettingsMacDetailCard(title: "Repeating-task Reminders") {
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

    SettingsMacDetailCard(title: scheduledNotificationsTitle) {
        if store.notifications.hasLoadedScheduledNotifications == false {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading scheduled notifications…")
                    .foregroundStyle(.secondary)
            }
        } else if store.notifications.scheduledNotifications.isEmpty {
            Text(scheduledNotificationsEmptyText)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(store.notifications.scheduledNotificationGroups) { group in
                    SettingsMacScheduledNotificationGroup(
                        group: group,
                        store: store
                    )

                    if group.id != store.notifications.scheduledNotificationGroups.last?.id {
                        Divider()
                    }
                }
            }
        }

        Text("Notifications are grouped by task or event. Expand a group to review its queued alerts, postpone one, or remove only that occurrence from this Mac.")
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
        let count = store.notifications.scheduledNotifications.count
        return count == 0 ? "Scheduled Notifications" : "Scheduled Notifications (\(count))"
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

private struct SettingsMacScheduledNotificationGroup: View {
    let group: ScheduledNotificationGroup
    let store: StoreOf<SettingsFeature>

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(group.notifications) { notification in
                    SettingsMacScheduledNotificationRow(
                        notification: notification,
                        store: store
                    )

                    if notification.id != group.notifications.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.top, 8)
            .padding(.leading, 4)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: group.sourceKind == .event ? "calendar" : "checkmark.circle")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(.body.weight(.medium))
                    Text(notificationCountText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    private var notificationCountText: String {
        let count = group.notifications.count
        return count == 1 ? "1 scheduled notification" : "\(count) scheduled notifications"
    }
}

private struct SettingsMacScheduledNotificationRow: View {
    let notification: ScheduledNotificationSummary
    let store: StoreOf<SettingsFeature>
    @State private var isCustomPausePresented = false
    @State private var customPauseDate = Date()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $isCustomPausePresented) {
            SettingsMacCustomNotificationPauseSheet(
                pauseDate: $customPauseDate,
                minimumDate: customPauseMinimumDate,
                onCancel: { isCustomPausePresented = false },
                onPause: {
                    pause(until: customPauseDate)
                    isCustomPausePresented = false
                }
            )
        }
    }

    private var scheduledTimeText: String {
        notification.scheduledAt?.formatted(date: .abbreviated, time: .shortened)
            ?? "Scheduled time unavailable"
    }

    private var notificationActionsMenu: some View {
        Menu {
            Menu("Pause") {
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

            Button("Remove", role: .destructive) {
                store.send(.removeScheduledNotificationTapped(notification))
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
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

private struct SettingsMacCustomNotificationPauseSheet: View {
    @Binding var pauseDate: Date
    let minimumDate: Date
    let onCancel: () -> Void
    let onPause: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Pause Notification")
                .font(.title2.weight(.semibold))

            Text("Choose a later time for this occurrence. The task or event schedule will not change.")
                .foregroundStyle(.secondary)

            DatePicker(
                "Pause until",
                selection: $pauseDate,
                in: minimumDate...,
                displayedComponents: [.date, .hourAndMinute]
            )

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Pause", action: onPause)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

private struct SettingsMacCalendarDetailView: View {
    let store: StoreOf<SettingsFeature>
    @Query private var existingTasks: [RoutineTask]
    @State private var isCalendarTaskImportPresented = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingDayPlanCalendarListAssumedDoneCollapsedByDefault.rawValue,
        store: SharedDefaults.app
    ) private var areCalendarListTaskSectionsCollapsedByDefault = true

    var body: some View {
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

        Text("Review calendar events one by one before adding them as tasks.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    SettingsMacDetailCard(title: "Planner Calendar") {
        Toggle("Show timeline tasks automatically in planner", isOn: showTimelineTasksInDayPlannerBinding)
            .toggleStyle(.switch)

        Text("When off, planner dates show a timeline badge that opens the activity list instead.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    SettingsMacDetailCard(title: "Calendar List") {
        Picker("Task sections default", selection: $areCalendarListTaskSectionsCollapsedByDefault) {
            Text("Collapsed").tag(true)
            Text("Expanded").tag(false)
        }
        .pickerStyle(.segmented)

        Text("Newly shown Planned tasks, Assumed done, Confirmed assumed done, and Done sections use this state. You can still open or collapse each section for a day directly in Calendar List.")
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

    private var showPersianDatesBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.showPersianDates },
            set: { store.send(.showPersianDatesToggled($0)) }
        )
    }

    private var showTimelineTasksInDayPlannerBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.showsTimelineTasksInDayPlanner },
            set: { store.send(.showTimelineTasksInDayPlannerToggled($0)) }
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

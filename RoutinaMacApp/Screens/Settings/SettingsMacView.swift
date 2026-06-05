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
NavigationSplitView {
    List(selection: $selectedSection) {
        ForEach(visibleSections) { section in
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
    .toolbar {
        RoutinaMacFocusTimerToolbarItem()
    }
}
.navigationSplitViewStyle(.balanced)
.settingsMacPresentations(
    store: store,
    isPlacePickerPresented: $isPlacePickerPresented
)
    }

    private var selectedDetailSection: SettingsMacSection {
        let candidate = selectedSection ?? .notifications
        if candidate == .support { return .about }
        guard visibleSections.contains(candidate) else { return .general }
        return candidate
    }

    private var visibleSections: [SettingsMacSection] {
        SettingsMacSection.visibleSections(
            isGitFeaturesEnabled: store.appearance.isGitFeaturesEnabled
        )
    }
}

struct SettingsMacDetailView: View {
    let section: SettingsMacSection
    let store: StoreOf<SettingsFeature>
    @Binding var isPlacePickerPresented: Bool

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
        case .quickAdd:
            SettingsMacQuickAddDetailView()
        case .shortcuts:
            SettingsMacShortcutsDetailView()
        case .support, .about:
            SettingsMacAboutDetailView(store: store)
        }
    }
}

struct EmbeddedSettingsMacDetailView: View {
    let store: StoreOf<SettingsFeature>
    let section: SettingsMacSection
    @State private var isPlacePickerPresented = false

    var body: some View {
SettingsMacDetailView(
    section: section,
    store: store,
    isPlacePickerPresented: $isPlacePickerPresented
)
.settingsMacPresentations(
    store: store,
    isPlacePickerPresented: $isPlacePickerPresented
)
    }
}

private struct SettingsMacNotificationsDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
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

    SettingsMacDetailCard(title: "Planner Calendar") {
        Toggle("Show timeline tasks automatically in planner", isOn: showTimelineTasksInDayPlannerBinding)
            .toggleStyle(.switch)

        Text("When off, planner dates show a timeline badge that opens the activity list instead.")
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

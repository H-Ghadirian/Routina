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
                ForEach(
                    SettingsIOSSection.compactSectionGroups(
                        isGitFeaturesEnabled: store.appearance.isGitFeaturesEnabled
                    ),
                    id: \.self
                ) { sections in
                    Section {
                        ForEach(sections) { section in
                            NavigationLink {
                                SettingsIOSDetailView(section: section, store: store)
                            } label: {
                                SettingsIOSSectionRow(section: section, store: store)
                            }
                        }
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
                        SettingsIOSSectionRow(
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
                SettingsIOSDetailView(section: selectedDetailSection, store: store)
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
}

private typealias SettingsIOSSection = SettingsSectionID

private struct SettingsIOSDetailView: View {
    let section: SettingsIOSSection
    let store: StoreOf<SettingsFeature>

    var body: some View {
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
        case .quickAdd:
            SettingsQuickAddDetailView()
        case .shortcuts:
            SettingsIOSShortcutsDetailView()
        case .support:
            SettingsSupportDetailView(store: store)
        case .about:
            SettingsAboutDetailView(store: store)
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

private struct SettingsQuickAddDetailView: View {
    var body: some View {
        List {
            Section("Examples") {
                ForEach(SettingsQuickAddSyntaxGuide.examples) { example in
                    SettingsQuickAddExampleBlock(example: example)
                }
            }

            ForEach(SettingsQuickAddSyntaxGuide.syntaxGroups) { group in
                Section(group.title) {
                    ForEach(group.rows) { row in
                        SettingsQuickAddSyntaxBlock(row: row)
                    }
                }
            }

            Section("Notes") {
                ForEach(SettingsQuickAddSyntaxGuide.notes, id: \.self) { note in
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

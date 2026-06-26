import SwiftUI
import ComposableArchitecture

struct SettingsAboutDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
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
        SettingsBetaExperimentsSection(store: store)

        Section("Diagnostics") {
            SettingsInfoRow(title: "Data Mode", value: store.diagnostics.dataModeDescription)
            SettingsInfoRow(title: "iCloud Container", value: store.diagnostics.iCloudContainerDescription)

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
.navigationTitle("Support & About")
.navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsBetaExperimentsSection: View {
    let store: StoreOf<SettingsFeature>

    @AppStorage(
        UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isGoalsTabEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAdventureMapEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAdventureMapEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingStatsWinsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isStatsWinsEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingStatsSleepTabEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isStatsSleepTabEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingStatsAchievementsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isStatsAchievementsEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingRelatedTagRulesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isRelatedTagRulesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingSettingsDevicesSectionEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isSettingsDevicesSectionEnabled = false

    var body: some View {
        Section("Beta Experiments") {
            Toggle("Enable Git features", isOn: gitFeaturesBinding)

            Text("Shows GitHub and GitLab contribution activity in Stats.")
                .foregroundStyle(.secondary)

            Toggle("Enable task sharing", isOn: taskSharingBinding)

            Text("Show task sharing in task details.")
                .foregroundStyle(.secondary)

            Toggle("Show linked task visualizer", isOn: taskRelationshipVisualizerBinding)

            Text("Show the Visualize button for linked tasks in task details.")
                .foregroundStyle(.secondary)

            Toggle("Show Places", isOn: placesBinding)

            Text("Show place management, check-ins, filters, task fields, and place stats.")
                .foregroundStyle(.secondary)

            Toggle("Show Notes", isOn: notesBinding)

            Text("Show note creation, note fields, note timeline items, and note stats.")
                .foregroundStyle(.secondary)

            Toggle("Show Away", isOn: awayBinding)

            Text("Show Away mode controls, Away planner blocks, Away timeline items, Away stats, and Sleep stats/blocking surfaces.")
                .foregroundStyle(.secondary)

            Toggle("Show filter query sections", isOn: filterQuerySectionsBinding)

            Text("Show advanced query controls in Home and Stats filters.")
                .foregroundStyle(.secondary)

            Toggle("Show Goals tab", isOn: $isGoalsTabEnabled)

            Text("Show Goal navigation, controls, and Stats reports.")
                .foregroundStyle(.secondary)

            Toggle("Show Adventure map", isOn: $isAdventureMapEnabled)

            Text("Show the Adventure map in Home.")
                .foregroundStyle(.secondary)

            Toggle("Show Stats wins", isOn: $isStatsWinsEnabled)

            Text("Show Recent Wins in Stats.")
                .foregroundStyle(.secondary)

            if store.appearance.isAwayEnabled {
                Toggle("Show Sleep tab", isOn: $isStatsSleepTabEnabled)

                Text("Show the Sleep tab for Sleep-specific dashboard scope in Stats.")
                    .foregroundStyle(.secondary)
            }

            Toggle("Show Achievements", isOn: $isStatsAchievementsEnabled)

            Text("Show achievement badges and progress in Stats.")
                .foregroundStyle(.secondary)

            Toggle("Show related tags options", isOn: $isRelatedTagRulesEnabled)

            Text("Show tag-related rules controls in Settings > Tags.")
                .foregroundStyle(.secondary)

            Toggle("Show Devices section", isOn: $isSettingsDevicesSectionEnabled)
        }
    }

    private var gitFeaturesBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.isGitFeaturesEnabled },
            set: { store.send(.gitFeaturesToggled($0)) }
        )
    }

    private var taskSharingBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.isTaskSharingEnabled },
            set: { store.send(.taskSharingToggled($0)) }
        )
    }

    private var taskRelationshipVisualizerBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.isTaskRelationshipVisualizerEnabled },
            set: { store.send(.taskRelationshipVisualizerToggled($0)) }
        )
    }

    private var placesBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.isPlacesEnabled },
            set: { store.send(.placesToggled($0)) }
        )
    }

    private var notesBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.isNotesEnabled },
            set: { store.send(.notesToggled($0)) }
        )
    }

    private var awayBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.isAwayEnabled },
            set: { store.send(.awayToggled($0)) }
        )
    }

    private var filterQuerySectionsBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.showsFilterQuerySections },
            set: { store.send(.filterQuerySectionsToggled($0)) }
        )
    }
}

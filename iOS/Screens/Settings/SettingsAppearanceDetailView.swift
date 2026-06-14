import SwiftUI
import ComposableArchitecture

struct SettingsAppearanceDetailView: View {
    let store: StoreOf<SettingsFeature>
    @State private var resetFeedbackTrigger = false

    private let columns = [
        GridItem(.adaptive(minimum: 108), spacing: 12)
    ]

    var body: some View {
List {
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

    Section("App Theme") {
        Picker("Theme", selection: appColorSchemeBinding) {
            ForEach(AppColorScheme.allCases) { scheme in
                Text(scheme.title).tag(scheme)
            }
        }
        .pickerStyle(.segmented)

        Text(store.appearance.appColorScheme.subtitle)
            .foregroundStyle(.secondary)
    }

    Section("Task Row") {
        SettingsTaskRowPreviewView(
            visibility: store.appearance.taskRowVisibility,
            showsTaskTypeBadge: true
        )
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

        ForEach(HomeTaskRowField.allCases) { field in
            Toggle(isOn: taskRowFieldVisibilityBinding(field)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.title)
                    Text(field.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Text("Shown: \(store.appearance.taskRowVisibility.summaryText)")
            .foregroundStyle(.secondary)
    }

    Section("Timeline Row") {
        SettingsTimelineRowPreviewView(visibility: store.appearance.timelineRowVisibility)

        ForEach(HomeTimelineRowField.allCases) { field in
            Toggle(isOn: timelineRowFieldVisibilityBinding(field)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.title)
                    Text(field.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Text("Shown: \(store.appearance.timelineRowVisibility.summaryText)")
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

    if !store.appearance.appIconStatusMessage.isEmpty {
        Section("Status") {
            Text(store.appearance.appIconStatusMessage)
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

    private var appColorSchemeBinding: Binding<AppColorScheme> {
        Binding(
            get: { store.appearance.appColorScheme },
            set: { store.send(.appColorSchemeChanged($0)) }
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

    private func taskRowFieldVisibilityBinding(_ field: HomeTaskRowField) -> Binding<Bool> {
        Binding(
            get: { store.appearance.taskRowVisibility.shows(field) },
            set: { store.send(.taskRowFieldVisibilityChanged(field, $0)) }
        )
    }

    private func timelineRowFieldVisibilityBinding(_ field: HomeTimelineRowField) -> Binding<Bool> {
        Binding(
            get: { store.appearance.timelineRowVisibility.shows(field) },
            set: { store.send(.timelineRowFieldVisibilityChanged(field, $0)) }
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

struct SettingsGeneralDetailView: View {
    let store: StoreOf<SettingsFeature>

    @AppStorage(
        BatteryRoutinePreferences.monitoringEnabledDefaultsKey,
        store: SharedDefaults.app
    ) private var batteryRoutineMonitoringEnabled = BatteryRoutinePreferences.defaultMonitoringEnabled
    @AppStorage(
        BatteryRoutinePreferences.thresholdPercentDefaultsKey,
        store: SharedDefaults.app
    ) private var batteryRoutineThresholdPercent = BatteryRoutinePreferences.defaultThresholdPercent
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
        UserDefaultBoolValueKey.appSettingHomeTaskListModeTabsVisible.rawValue,
        store: SharedDefaults.app
    ) private var isHomeTaskListModeTabsVisible = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingRelatedTagRulesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isRelatedTagRulesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingSettingsDevicesSectionEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isSettingsDevicesSectionEnabled = false

    var body: some View {
List {
    Section("App Lock") {
        Toggle("Require unlock when opening Routina", isOn: appLockBinding)
            .disabled(store.appearance.isAppLockToggleInProgress)

        if store.appearance.isAppLockToggleInProgress {
            ProgressView("Verifying device authentication…")
        }

        Text(store.appearance.appLockDetailText)
            .foregroundStyle(.secondary)
    }

    Section("Battery Routines") {
        Toggle("Create charge routines", isOn: batteryRoutineMonitoringBinding)

        Stepper(value: batteryRoutineThresholdBinding, in: 5...95, step: 5) {
            Text("Low battery threshold \(batteryRoutineThresholdPercent)%")
        }
        .disabled(!batteryRoutineMonitoringEnabled)

        Text("When enabled, Routina creates one charge routine for this device and turns it red, urgent, and pinned when the battery is below the threshold.")
            .foregroundStyle(.secondary)
    }

    Section("Beta Experiments") {
        Toggle("Enable Git features", isOn: gitFeaturesBinding)

        Text("Shows GitHub and GitLab contribution activity in Stats.")
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

        Toggle("Show Sleep tab", isOn: $isStatsSleepTabEnabled)

        Text("Show the Sleep tab for Sleep-specific dashboard scope in Stats.")
            .foregroundStyle(.secondary)

        Toggle("Show Achievements", isOn: $isStatsAchievementsEnabled)

        Text("Show achievement badges and progress in Stats.")
            .foregroundStyle(.secondary)

        Toggle("Show related tags options", isOn: $isRelatedTagRulesEnabled)

        Text("Show tag-related rules controls in Settings > Tags.")
            .foregroundStyle(.secondary)

        Toggle("Show Devices section", isOn: $isSettingsDevicesSectionEnabled)
    }

    Section("Navigation") {
        Toggle("Show Home task-type tabs", isOn: $isHomeTaskListModeTabsVisible)

        Text("Show All / Routines / Todos tabs in the Home toolbar. Turn off to switch task type from Filters instead.")
            .foregroundStyle(.secondary)
    }

    Section("Reset Settings") {
        Button(role: .destructive) {
            store.send(.resetAllSettingsToDefaultsTapped)
        } label: {
            Label("Reset Settings to Defaults", systemImage: "arrow.counterclockwise")
                .foregroundStyle(settingsResetButtonForegroundStyle)
        }
        .disabled(isSettingsResetButtonDisabled)

        if store.appearance.isSettingsResetAuthenticationInProgress {
            ProgressView("Verifying device authentication…")
        }

        Text(settingsResetDescription)
            .foregroundStyle(.secondary)

        if !store.appearance.settingsResetStatusMessage.isEmpty {
            Text(store.appearance.settingsResetStatusMessage)
                .foregroundStyle(.secondary)
        }
    }

}
.listStyle(.insetGrouped)
.navigationTitle("General")
.navigationBarTitleDisplayMode(.inline)
    }

    private var appLockBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.isAppLockEnabled },
            set: { store.send(.appLockToggled($0)) }
        )
    }

    private var batteryRoutineMonitoringBinding: Binding<Bool> {
        Binding(
            get: { batteryRoutineMonitoringEnabled },
            set: {
                batteryRoutineMonitoringEnabled = $0
                BatteryRoutinePreferences.notifyChanged()
            }
        )
    }

    private var batteryRoutineThresholdBinding: Binding<Int> {
        Binding(
            get: { batteryRoutineThresholdPercent },
            set: {
                batteryRoutineThresholdPercent = BatteryRoutinePreferences.clampedThresholdPercent($0)
                BatteryRoutinePreferences.notifyChanged()
            }
        )
    }

    private var gitFeaturesBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.isGitFeaturesEnabled },
            set: { store.send(.gitFeaturesToggled($0)) }
        )
    }

    private var isSettingsResetButtonDisabled: Bool {
        !store.appearance.isAppLockEnabled ||
            store.appearance.isAppLockToggleInProgress ||
            store.appearance.isSettingsResetAuthenticationInProgress
    }

    private var settingsResetButtonForegroundStyle: AnyShapeStyle {
        isSettingsResetButtonDisabled
            ? AnyShapeStyle(Color.secondary)
            : AnyShapeStyle(Color.red)
    }

    private var settingsResetDescription: String {
        if store.appearance.isAppLockEnabled {
            return "Restores settings preferences to their defaults after confirming App Lock."
        }
        return "Turn on App Lock before resetting settings to their defaults."
    }
}

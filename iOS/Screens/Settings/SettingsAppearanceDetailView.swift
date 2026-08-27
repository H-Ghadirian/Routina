import SwiftUI
import ComposableArchitecture

struct SettingsAppearanceDetailView: View {
    let store: StoreOf<SettingsFeature>
    @State private var resetFeedbackTrigger = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isGoalsTabEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false

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
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Theme",
            options: AppColorScheme.allCases,
            selection: appColorSchemeBinding,
            fillsAvailableWidth: true
        ) { scheme in
            Text(scheme.title)
        }

        Text(store.appearance.appColorScheme.subtitle)
            .foregroundStyle(.secondary)
    }

    Section("Task Row") {
        SettingsTaskRowPreviewView(
            visibility: store.appearance.taskRowVisibility,
            showsTaskTypeBadge: true,
            showsGoals: isGoalsTabEnabled,
            showsPlaces: isPlacesEnabled
        )
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

        ForEach(availableTaskRowFields) { field in
            Toggle(isOn: taskRowFieldVisibilityBinding(field)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.title)
                    if let subtitle = field.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        Text("Shown: \(taskRowSummaryText)")
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

    private func taskRowFieldVisibilityBinding(_ field: HomeTaskRowField) -> Binding<Bool> {
        Binding(
            get: { store.appearance.taskRowVisibility.shows(field) },
            set: { store.send(.taskRowFieldVisibilityChanged(field, $0)) }
        )
    }

    private var availableTaskRowFields: [HomeTaskRowField] {
        HomeTaskRowField.availableAppearanceFields(
            showsTaskTypeBadge: true,
            showsGoals: isGoalsTabEnabled,
            showsPlaces: isPlacesEnabled,
            showsFlags: false
        )
    }

    private var taskRowSummaryText: String {
        let hiddenCount = availableTaskRowFields.filter {
            !store.appearance.taskRowVisibility.shows($0)
        }.count
        guard hiddenCount > 0 else { return "All fields" }
        return "\(availableTaskRowFields.count - hiddenCount) of \(availableTaskRowFields.count) fields"
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
        UserDefaultBoolValueKey.appSettingHomeTaskListModeTabsVisible.rawValue,
        store: SharedDefaults.app
    ) private var isHomeTaskListModeTabsVisible = false

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

    Section("Battery Repeating Tasks") {
        Toggle("Create charge repeating tasks", isOn: batteryRoutineMonitoringBinding)

        Stepper(value: batteryRoutineThresholdBinding, in: 5...95, step: 5) {
            Text("Low battery threshold \(batteryRoutineThresholdPercent)%")
        }
        .disabled(!batteryRoutineMonitoringEnabled)

        Text("When enabled, Routina creates one charge repeating task for this device and turns it red, urgent, and pinned when the battery is below the threshold.")
            .foregroundStyle(.secondary)
    }

    Section("Navigation") {
        Toggle("Show Home task-type tabs", isOn: $isHomeTaskListModeTabsVisible)

        Text("Show All / Repeating / One-time tabs in the Home toolbar. Turn off to switch task type from Filters instead.")
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

import SwiftUI
import ComposableArchitecture

struct SettingsMacAppearanceDetailView: View {
    let store: StoreOf<SettingsFeature>

    @AppStorage("macTodoBoardCompactCards", store: SharedDefaults.app)
    private var isMacTodoBoardCompactCards = false

    private let columns = [
        GridItem(.adaptive(minimum: 124), spacing: 12)
    ]

    var body: some View {
SettingsMacDetailShell(
    title: "Appearance",
    subtitle: "Pick the Dock icon, then choose the app theme."
) {
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

    SettingsMacDetailCard(title: "Task Row") {
        SettingsTaskRowPreviewView(
            visibility: store.appearance.taskRowVisibility,
            showsTaskTypeBadge: false
        )

        ForEach(macTaskRowFields) { field in
            Toggle(isOn: taskRowFieldVisibilityBinding(field)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.title)
                    Text(field.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
        }

        Text("Shown: \(macTaskRowSummaryText)")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    SettingsMacDetailCard(title: "Timeline Row") {
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
            .toggleStyle(.switch)
        }

        Text("Shown: \(macTimelineRowSummaryText)")
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

    if !store.appearance.appIconStatusMessage.isEmpty {
        SettingsMacDetailCard(title: "Status") {
            Text(store.appearance.appIconStatusMessage)
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

    private var macTaskRowFields: [HomeTaskRowField] {
        HomeTaskRowField.allCases.filter { $0 != .taskTypeBadge }
    }

    private var macTaskRowSummaryText: String {
        let hiddenCount = macTaskRowFields.filter {
            !store.appearance.taskRowVisibility.shows($0)
        }.count
        guard hiddenCount > 0 else { return "All fields" }
        return "\(macTaskRowFields.count - hiddenCount) of \(macTaskRowFields.count) fields"
    }

    private var macTimelineRowSummaryText: String {
        let hiddenCount = HomeTimelineRowField.allCases.filter {
            !store.appearance.timelineRowVisibility.shows($0)
        }.count
        guard hiddenCount > 0 else { return "All fields" }
        return "\(HomeTimelineRowField.allCases.count - hiddenCount) of \(HomeTimelineRowField.allCases.count) fields"
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

struct SettingsMacGeneralDetailView: View {
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
        UserDefaultBoolValueKey.appSettingBoardScreenEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isBoardScreenEnabled = false
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
    ) private var areHomeTaskListModeTabsVisible = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingRelatedTagRulesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isRelatedTagRulesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacTimelineQuickFiltersVisible.rawValue,
        store: SharedDefaults.app
    ) private var areMacTimelineQuickFiltersVisible = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacStatusComposerEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isMacStatusComposerEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingSettingsDevicesSectionEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isSettingsDevicesSectionEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areMacEventEmotionActionsEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacWebsiteBlockingEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isMacWebsiteBlockingEnabled = false

    var body: some View {
SettingsMacDetailShell(
    title: "General",
    subtitle: "Configure app-wide behavior and device-aware routines."
) {
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

    SettingsMacDetailCard(title: "Reset Settings") {
        Button(role: .destructive) {
            store.send(.resetAllSettingsToDefaultsTapped)
        } label: {
            Label("Reset Settings to Defaults", systemImage: "arrow.counterclockwise")
                .foregroundStyle(settingsResetButtonForegroundStyle)
        }
        .buttonStyle(.bordered)
        .tint(isSettingsResetButtonDisabled ? .gray : .red)
        .disabled(isSettingsResetButtonDisabled)

        if store.appearance.isSettingsResetAuthenticationInProgress {
            ProgressView("Verifying device authentication…")
                .controlSize(.small)
        }

        Text(settingsResetDescription)
            .font(.footnote)
            .foregroundStyle(.secondary)

        if !store.appearance.settingsResetStatusMessage.isEmpty {
            Text(store.appearance.settingsResetStatusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    SettingsMacDetailCard(title: "Battery Routines") {
        Toggle("Create charge routines", isOn: batteryRoutineMonitoringBinding)
            .toggleStyle(.switch)

        Stepper(value: batteryRoutineThresholdBinding, in: 5...95, step: 5) {
            Text("Low battery threshold \(batteryRoutineThresholdPercent)%")
        }
        .disabled(!batteryRoutineMonitoringEnabled)

        Text("When enabled, Routina creates one charge routine for this Mac and turns it red, urgent, and pinned when the battery is below the threshold.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    SettingsMacDetailCard(title: "Beta Experiments") {
        Toggle("Enable Git features", isOn: gitFeaturesBinding)
            .toggleStyle(.switch)

        Text("Shows GitHub and GitLab contribution activity in Stats.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        Toggle("Show Goals tab", isOn: $isGoalsTabEnabled)
            .toggleStyle(.switch)

        Text("Show Goal navigation, controls, and Stats reports.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        Toggle("Show Adventure map", isOn: $isAdventureMapEnabled)
            .toggleStyle(.switch)

        Text("Show the Adventure map in Home.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        Toggle("Show Board screen", isOn: $isBoardScreenEnabled)
            .toggleStyle(.switch)

        Text("Show the Board screen in Home.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        Toggle("Show Stats wins", isOn: $isStatsWinsEnabled)
            .toggleStyle(.switch)

        Text("Show Recent Wins in Stats.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        Toggle("Show Sleep tab", isOn: $isStatsSleepTabEnabled)
            .toggleStyle(.switch)

        Text("Show the Sleep tab for Sleep-specific dashboard scope in Stats.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        Toggle("Show Achievements", isOn: $isStatsAchievementsEnabled)
            .toggleStyle(.switch)

        Text("Show achievement badges and progress in Stats.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        Toggle("Show related tags options", isOn: $isRelatedTagRulesEnabled)
            .toggleStyle(.switch)

        Text("Show tag-related rules controls in Settings > Tags.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        Toggle("Show Devices section", isOn: $isSettingsDevicesSectionEnabled)
            .toggleStyle(.switch)

        Toggle("Show Home task type tabs", isOn: $areHomeTaskListModeTabsVisible)
            .toggleStyle(.switch)

        Text("Show All, Todos, and Routines tabs in the Home sidebar.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        Toggle("Show Timeline quick filters", isOn: $areMacTimelineQuickFiltersVisible)
            .toggleStyle(.switch)

        Text("Show the All, Routines, Todos, Notes, and other quick filters in Timeline.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        Toggle("Show Status note section", isOn: $isMacStatusComposerEnabled)
            .toggleStyle(.switch)

        Text("Show the bottom sidebar composer for adding Status notes from Home.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        Toggle("Show Event and Emotion actions", isOn: $areMacEventEmotionActionsEnabled)
            .toggleStyle(.switch)

        Text("Show Event and Emotion in the Mac Add menu, Timeline type filters, and Stats reports.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        Toggle("Show Mac website blocking", isOn: $isMacWebsiteBlockingEnabled)
            .toggleStyle(.switch)

        Text("Show the website blocking controls in Blocking settings.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

}
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

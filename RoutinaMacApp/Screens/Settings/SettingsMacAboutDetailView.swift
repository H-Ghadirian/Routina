import SwiftUI
import ComposableArchitecture

struct SettingsMacAboutDetailView: View {
    let store: StoreOf<SettingsFeature>
    @State private var didCopyDiagnostics = false
    @State private var didMarkPerformanceReproduction = false

    var body: some View {
        SettingsMacDetailShell(
            title: "Support & About",
            subtitle: "Contact support, check version details, and view diagnostics when unlocked."
        ) {
            SettingsMacDetailCard(title: "Contact") {
                Button {
                    store.send(.contactUsTapped)
                } label: {
                    Label("Email Support", systemImage: "envelope")
                }
                .buttonStyle(.borderedProminent)

                Text("h.qadirian@gmail.com")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsMacDetailCard(title: "Legal") {
                Link(destination: RoutinaPublicLinks.privacyPolicy) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }

                Link(destination: RoutinaPublicLinks.termsOfUse) {
                    Label("Terms of Use", systemImage: "doc.text")
                }
            }

            SettingsMacDetailCard(title: "App") {
                settingsInfoRow(title: "Version", value: store.diagnostics.appVersion)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 5) {
                        store.send(.aboutSectionLongPressed)
                    }
                settingsInfoRow(title: "Build Number", value: store.diagnostics.buildNumber)
            }

            if store.diagnostics.isDebugSectionVisible {
                if AppEnvironment.isDevelopmentAppVariant {
                    SettingsMacBetaExperimentsCard(store: store)
                }

                SettingsMacDetailCard(title: "Diagnostics") {
                    settingsInfoRow(title: "Operating System", value: store.diagnostics.operatingSystemDescription)
                    settingsInfoRow(title: "Data Mode", value: store.diagnostics.dataModeDescription)
                    settingsInfoRow(title: "iCloud Container", value: store.diagnostics.iCloudContainerDescription)
                    settingsInfoRow(
                        title: "Signed CloudKit Environment",
                        value: store.diagnostics.signedCloudKitEnvironmentDescription
                    )

                    Text("Last CloudKit Event: \(store.diagnostics.cloudDiagnosticsTimestamp)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(store.diagnostics.cloudDiagnosticsSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(store.diagnostics.pushDiagnosticsStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        SettingsDiagnosticsClipboard.copy(
                            SettingsDiagnosticsReport.text(for: store.diagnostics)
                        )
                        didCopyDiagnostics = true
                    } label: {
                        Label(
                            didCopyDiagnostics ? "Diagnostics Copied" : "Copy Diagnostics",
                            systemImage: didCopyDiagnostics ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Copies the complete diagnostic report for sharing with support")
                }

                let latestProfileURL = RoutinaPerformanceProfiler.shared.latestProfileURL
                if RoutinaPerformanceProfiler.isEnabled, let profileURL = latestProfileURL {
                    SettingsMacDetailCard(title: "Performance Profile") {
                        Text(
                            """
                            This Debug run is recording CPU, memory, lifecycle events, interaction categories, and main-thread stalls. \
                            It never includes task names, search text, or account data.
                            """
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Button {
                                RoutinaPerformanceProfiler.shared.addMarker(.reproductionEnded)
                                didMarkPerformanceReproduction = true
                            } label: {
                                Label(
                                    didMarkPerformanceReproduction ? "Reproduction Marked" : "Mark End of Reproduction",
                                    systemImage: didMarkPerformanceReproduction ? "checkmark" : "flag"
                                )
                            }
                            .buttonStyle(.bordered)

                            ShareLink(item: profileURL) {
                                Label("Share Performance Profile", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                        }

                        if let previousRunProfileURL = RoutinaPerformanceProfiler.shared.previousRunProfileURL {
                            ShareLink(item: previousRunProfileURL) {
                                Label("Share Previous Run Profile", systemImage: "clock.arrow.circlepath")
                            }
                            .buttonStyle(.bordered)

                            Text(
                                """
                                Use the previous run after reopening the app following a crash or force-quit. \
                                It contains the most recently saved data from that run.
                                """
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

}

private struct SettingsMacBetaExperimentsCard: View {
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
        UserDefaultBoolValueKey.appSettingMacStatsDashboardControlsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areMacStatsDashboardControlsEnabled = false
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
        UserDefaultBoolValueKey.appSettingMacHomeSectionFocusTimersEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areMacHomeSectionFocusTimersEnabled = false
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
        SettingsMacDetailCard(title: "Beta Experiments") {
            Toggle("Enable Git features", isOn: gitFeaturesBinding)
                .toggleStyle(.switch)

            Text("Shows GitHub and GitLab contribution activity in Stats.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Enable task sharing", isOn: taskSharingBinding)
                .toggleStyle(.switch)

            Text("Show task sharing in task details.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Show linked task visualizer", isOn: taskRelationshipVisualizerBinding)
                .toggleStyle(.switch)

            Text("Show the Visualize button for linked tasks in task details.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Show Places", isOn: placesBinding)
                .toggleStyle(.switch)

            Text("Show place management, check-ins, filters, task fields, and place stats.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Show Notes", isOn: notesBinding)
                .toggleStyle(.switch)

            Text("Show note creation, note fields, note timeline items, and note stats.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Show Away", isOn: awayBinding)
                .toggleStyle(.switch)

            Text("Show Away mode controls, Away planner blocks, Away timeline items, Away stats, and Sleep stats/blocking surfaces.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Show filter query sections", isOn: filterQuerySectionsBinding)
                .toggleStyle(.switch)

            Text("Show advanced query controls in Home and Stats filters.")
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

            if store.appearance.isAwayEnabled {
                Toggle("Show Sleep tab", isOn: $isStatsSleepTabEnabled)
                    .toggleStyle(.switch)

                Text("Show the Sleep tab for Sleep-specific dashboard scope in Stats.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Toggle("Show Achievements", isOn: $isStatsAchievementsEnabled)
                .toggleStyle(.switch)

            Text("Show achievement badges and progress in Stats.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Show Stats dashboard controls", isOn: $areMacStatsDashboardControlsEnabled)
                .toggleStyle(.switch)

            Text("Show Summary view and Edit controls in the Mac Stats toolbar.")
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

            Text("Show All, One-time, and Repeating tabs in the Home sidebar.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Show Home section focus timers", isOn: $areMacHomeSectionFocusTimersEnabled)
                .toggleStyle(.switch)

            Text("Show Focus Timer actions on Home sidebar section and group titles.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Show Timeline quick filters", isOn: $areMacTimelineQuickFiltersVisible)
                .toggleStyle(.switch)

            Text(
                store.appearance.isNotesEnabled
                    ? "Show the All, Repeating, One-time, Notes, and other quick filters in Timeline."
                    : "Show the All, Repeating, One-time, and other quick filters in Timeline."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            if store.appearance.isNotesEnabled {
                Toggle("Show Status note section", isOn: $isMacStatusComposerEnabled)
                    .toggleStyle(.switch)

                Text("Show the bottom sidebar composer for adding Status notes from Home.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Toggle("Show Event and Emotion actions", isOn: $areMacEventEmotionActionsEnabled)
                .toggleStyle(.switch)

            Text(
                """
                Show Event and Emotion in the Mac Add menu, Task Details event actions, Timeline type filters, \
                Planner calendar filters, and Stats reports.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            Toggle("Show Mac website blocking", isOn: $isMacWebsiteBlockingEnabled)
                .toggleStyle(.switch)

            Text("Show the website blocking controls in Blocking settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onChange(of: isGoalsTabEnabled) { _, _ in
            store.send(.onAppear)
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

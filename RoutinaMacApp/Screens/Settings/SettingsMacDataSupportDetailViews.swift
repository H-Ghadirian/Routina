import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers

struct SettingsMacCloudDetailView: View {
    let store: StoreOf<SettingsFeature>
    @State private var isBackupExporterPresented = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isNotesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false

    var body: some View {
SettingsMacDetailShell(
    title: "iCloud & Backup",
    subtitle: "Sync routines across devices, save backup packages, and manage the cloud copy when needed."
) {
    SettingsMacDetailCard(title: "iCloud") {
        HStack(spacing: 10) {
            Button {
                store.send(.syncNowTapped)
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath.icloud")
            }
            .buttonStyle(.bordered)
            .disabled(actionsDisabled)

            Button(role: .destructive) {
                store.send(.setCloudDataResetConfirmation(true))
            } label: {
                Label("Delete App & iCloud Data", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(actionsDisabled)

            if store.cloud.isCloudSyncInProgress ||
                store.cloud.isCloudDataResetAuthenticationInProgress ||
                store.cloud.isCloudDataResetInProgress {
                ProgressView()
                    .controlSize(.small)
            }
        }

        Text(store.cloud.syncStatusText)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    SettingsMacDetailCard(title: "Data Backup") {
        HStack(spacing: 10) {
            Button {
                isBackupExporterPresented = true
            } label: {
                Label("Save Backup", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .disabled(store.dataTransfer.isDataTransferInProgress)

            Button {
                store.send(.importRoutineDataTapped)
            } label: {
                Label("Load Backup", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .disabled(store.dataTransfer.isDataTransferInProgress)

            if store.dataTransfer.isDataTransferInProgress {
                ProgressView()
                    .controlSize(.small)
            }
        }

        Text(store.dataTransfer.statusText)
            .font(.footnote)
            .foregroundStyle(.secondary)

        Text(store.dataTransfer.backupFreshnessText())
            .font(.footnote)
            .foregroundStyle(
                store.dataTransfer.hasRecentSuccessfulBackup() ? Color.secondary : Color.red
            )
    }

    SettingsMacDetailCard(title: "Estimated Usage") {
        settingsInfoRow(title: "Estimated iCloud Data", value: store.cloud.usageTotalText)
        settingsInfoRow(title: "Tasks", value: "\(store.cloud.cloudUsageEstimate.taskCount) • \(store.cloud.usageTaskPayloadText)")
        settingsInfoRow(title: "Logs", value: "\(store.cloud.cloudUsageEstimate.logCount) • \(store.cloud.usageLogPayloadText)")
        if isPlacesEnabled {
            settingsInfoRow(title: "Places", value: "\(store.cloud.cloudUsageEstimate.placeCount) • \(store.cloud.usagePlacePayloadText)")
        }
        settingsInfoRow(title: "Goals", value: "\(store.cloud.cloudUsageEstimate.goalCount) • \(store.cloud.usageGoalPayloadText)")
        settingsInfoRow(title: "Emotions", value: "\(store.cloud.cloudUsageEstimate.emotionLogCount) • \(store.cloud.usageEmotionPayloadText)")
        if isNotesEnabled {
            settingsInfoRow(title: "Notes", value: "\(store.cloud.cloudUsageEstimate.noteCount) • \(store.cloud.usageNotePayloadText)")
        }
        settingsInfoRow(title: "Events", value: "\(store.cloud.cloudUsageEstimate.eventCount) • \(store.cloud.usageEventPayloadText)")
        settingsInfoRow(title: "Images", value: "\(store.cloud.cloudUsageEstimate.imageCount) • \(store.cloud.usageImagePayloadText)")
        if isNotesEnabled {
            settingsInfoRow(title: "Voice Notes", value: "\(store.cloud.cloudUsageEstimate.voiceNoteCount) • \(store.cloud.usageVoiceNotePayloadText)")
        }

        Text(store.cloud.usageSummaryText)
            .font(.footnote)
            .foregroundStyle(.secondary)
        Text(store.cloud.usageFootnoteText)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
    .fileExporter(
        isPresented: $isBackupExporterPresented,
        document: RoutineBackupExportPlaceholderDocument(),
        contentType: .routinaBackupPackage,
        defaultFilename: SettingsRoutineDataPersistence.defaultBackupFileName()
    ) { result in
        switch result {
        case let .success(destinationURL):
            store.send(.exportRoutineDataDestinationSelected(destinationURL))

        case let .failure(error):
            store.send(.routineDataTransferFinished(
                success: false,
                message: "Save failed: \(error.localizedDescription)"
            ))
        }
    }
    }

    private var actionsDisabled: Bool {
        store.cloud.isCloudSyncInProgress ||
        store.cloud.isCloudDataResetAuthenticationInProgress ||
        store.cloud.isCloudDataResetInProgress ||
        !store.cloud.cloudSyncAvailable
    }
}

private struct RoutineBackupExportPlaceholderDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.routinaBackupPackage] }
    static var writableContentTypes: [UTType] { [.routinaBackupPackage] }

    init() {}

    init(configuration: ReadConfiguration) throws {}

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(directoryWithFileWrappers: [:])
    }
}

private extension UTType {
    static var routinaBackupPackage: UTType {
        UTType(filenameExtension: SettingsRoutineDataPersistence.backupPackageExtension) ?? .package
    }
}

struct SettingsMacShortcutsDetailView: View {
    @AppStorage(
        UserDefaultStringValueKey.macQuickAddShortcut.rawValue,
        store: SharedDefaults.app
    ) private var quickAddShortcutRawValue = MacQuickAddShortcut.defaultValue.rawValue
    @AppStorage(
        UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isGoalsTabEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areMacEventEmotionActionsEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isNotesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false

    private let appShortcuts: [SettingsMacShortcutRowModel] = [
        SettingsMacShortcutRowModel(title: "Quick Add", detail: "“Quick add in Routina” or “Add a task in Routina”"),
        SettingsMacShortcutRowModel(title: "Mark Done", detail: "“Mark task done in Routina” or “Complete a task in Routina”"),
        SettingsMacShortcutRowModel(title: "Start Focus", detail: "“Start focus in Routina” or “Focus with Routina”"),
        SettingsMacShortcutRowModel(title: "Sleep", detail: "“I am going to sleep in Routina” or “Start sleep mode in Routina”"),
        SettingsMacShortcutRowModel(title: "Wake Up", detail: "“I woke up in Routina” or “I am awake in Routina”"),
        SettingsMacShortcutRowModel(title: "Today", detail: "“What's due in Routina” or “Today in Routina”")
    ]

    var body: some View {
        SettingsMacDetailShell(
            title: "Shortcuts",
            subtitle: "Review keyboard shortcuts and Apple Shortcuts that Routina exposes."
        ) {
            SettingsMacDetailCard(title: "Quick Add") {
                Picker("Shortcut", selection: quickAddShortcutBinding) {
                    ForEach(MacQuickAddShortcut.allCases) { shortcut in
                        Text("\(shortcut.title) · \(shortcut.detail)")
                            .tag(shortcut.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Text("Opens the Spotlight-style Quick Add overlay.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsMacDetailCard(title: "Keyboard") {
                ForEach(keyboardShortcuts) { shortcut in
                    SettingsMacShortcutRow(shortcut: shortcut)
                }
            }

            SettingsMacDetailCard(title: "Add Menu") {
                ForEach(addMenuShortcuts) { shortcut in
                    SettingsMacShortcutRow(
                        shortcut: SettingsMacShortcutRowModel(
                            title: shortcut.commandTitle,
                            detail: shortcut.detail,
                            shortcut: shortcut.shortcutTitle
                        )
                    )
                }
            }

            SettingsMacDetailCard(title: "Apple Shortcuts & Siri") {
                ForEach(appShortcuts) { shortcut in
                    SettingsMacShortcutRow(shortcut: shortcut)
                }
            }
        }
    }

    private var quickAddShortcut: MacQuickAddShortcut {
        MacQuickAddShortcut(rawValue: quickAddShortcutRawValue) ?? .defaultValue
    }

    private var quickAddShortcutBinding: Binding<String> {
        Binding(
            get: { quickAddShortcutRawValue },
            set: { rawValue in
                quickAddShortcutRawValue = rawValue
                RoutinaMacGlobalHotKeyManager.shared.registerQuickAddHotKey()
            }
        )
    }

    private var keyboardShortcuts: [SettingsMacShortcutRowModel] {
        [
            SettingsMacShortcutRowModel(title: "Quick Add", detail: "Open quick task creation.", shortcut: quickAddShortcut.title),
            SettingsMacShortcutRowModel(title: "Back", detail: "Return to the previous Home view.", shortcut: "⌘←"),
            SettingsMacShortcutRowModel(title: "Forward", detail: "Move forward after going back.", shortcut: "⌘→"),
            SettingsMacShortcutRowModel(title: "Routines", detail: "Switch the sidebar back to routines.", shortcut: "⌥⌘1"),
            SettingsMacShortcutRowModel(title: "Stats", detail: "Open stats from anywhere in the app.", shortcut: "⌥⌘2"),
            SettingsMacShortcutRowModel(title: "Timeline", detail: "Open the done timeline.", shortcut: "⌥⌘3"),
            SettingsMacShortcutRowModel(title: "Save", detail: "Confirm supported edit sheets and dialogs.", shortcut: "Return"),
            SettingsMacShortcutRowModel(title: "Cancel", detail: "Dismiss supported edit sheets and dialogs.", shortcut: "Esc"),
            SettingsMacShortcutRowModel(title: "Quit", detail: "Quit Routina from the menu bar extra or app menu.", shortcut: "⌘Q")
        ]
    }

    private var addMenuShortcuts: [MacAddMenuShortcut] {
        MacAddMenuShortcut.visibleActions(
            eventEmotionEnabled: areMacEventEmotionActionsEnabled,
            notesEnabled: isNotesEnabled,
            goalsEnabled: isGoalsTabEnabled,
            placesEnabled: isPlacesEnabled,
            awayEnabled: isAwayEnabled
        )
    }
}

struct SettingsMacQuickAddDetailView: View {
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false

    var body: some View {
        SettingsMacDetailShell(
            title: "Quick Add",
            subtitle: quickAddSubtitle
        ) {
            SettingsMacDetailCard(title: "Examples") {
                ForEach(SettingsQuickAddSyntaxGuide.visibleExamples(includingPlaces: isPlacesEnabled)) { example in
                    SettingsQuickAddExampleBlock(example: example)
                }
            }

            ForEach(SettingsQuickAddSyntaxGuide.visibleSyntaxGroups(includingPlaces: isPlacesEnabled)) { group in
                SettingsMacDetailCard(title: group.title) {
                    ForEach(group.rows) { row in
                        SettingsQuickAddSyntaxBlock(row: row, style: .badge)
                    }
                }
            }

            SettingsMacDetailCard(title: "Tips") {
                ForEach(SettingsQuickAddSyntaxGuide.visibleNotes(includingPlaces: isPlacesEnabled), id: \.self) { note in
                    SettingsQuickAddNoteBlock(note: note, style: .labeled)
                }
            }
        }
    }

    private var quickAddSubtitle: String {
        if isPlacesEnabled {
            return "Use compact phrases to create todos, routines, deadlines, tags, places, priority, and focus estimates."
        }
        return "Use compact phrases to create todos, routines, deadlines, tags, priority, and focus estimates."
    }
}

private struct SettingsMacShortcutRowModel: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    var shortcut: String?
}

private struct SettingsMacShortcutRow: View {
    let shortcut: SettingsMacShortcutRowModel

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(shortcut.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(shortcut.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            if let shortcut = shortcut.shortcut {
                Spacer(minLength: 12)

                SettingsMacShortcutKeyCluster(shortcut: shortcut)
                    .frame(minWidth: 120, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

private struct SettingsMacShortcutKeyCluster: View {
    let shortcut: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tokens.indices, id: \.self) { index in
                Text(tokens[index])
                    .font(.callout.weight(.bold).monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, horizontalPadding(for: tokens[index]))
                    .frame(minWidth: minimumWidth(for: tokens[index]), minHeight: 30)
                    .routinaGlassCard(cornerRadius: 7, tint: .accentColor, tintOpacity: 0.16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.42), lineWidth: 1)
                    )
            }
        }
        .accessibilityLabel(shortcut)
    }

    private var tokens: [String] {
        switch shortcut {
        case "Return", "Esc":
            return [shortcut]
        default:
            return shortcut.map(String.init)
        }
    }

    private func minimumWidth(for token: String) -> CGFloat {
        token.count == 1 ? 30 : 74
    }

    private func horizontalPadding(for token: String) -> CGFloat {
        token.count == 1 ? 0 : 10
    }
}

struct SettingsMacAboutDetailView: View {
    let store: StoreOf<SettingsFeature>

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

    SettingsMacDetailCard(title: "App") {
        settingsInfoRow(title: "Version", value: store.diagnostics.appVersion)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 5) {
                store.send(.aboutSectionLongPressed)
            }
    }

    if store.diagnostics.isDebugSectionVisible {
        SettingsMacBetaExperimentsCard(store: store)

        SettingsMacDetailCard(title: "Diagnostics") {
            settingsInfoRow(title: "Data Mode", value: store.diagnostics.dataModeDescription)
            settingsInfoRow(title: "iCloud Container", value: store.diagnostics.iCloudContainerDescription)

            Text("Last CloudKit Event: \(store.diagnostics.cloudDiagnosticsTimestamp)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(store.diagnostics.cloudDiagnosticsSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(store.diagnostics.pushDiagnosticsStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
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

            Toggle("Show Home section focus timers", isOn: $areMacHomeSectionFocusTimersEnabled)
                .toggleStyle(.switch)

            Text("Show Focus Timer actions on Home sidebar section and group titles.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Show Timeline quick filters", isOn: $areMacTimelineQuickFiltersVisible)
                .toggleStyle(.switch)

            Text(store.appearance.isNotesEnabled
                ? "Show the All, Routines, Todos, Notes, and other quick filters in Timeline."
                : "Show the All, Routines, Todos, and other quick filters in Timeline.")
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

            Text("Show Event and Emotion in the Mac Add menu, Timeline type filters, Planner calendar filters, and Stats reports.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Show Mac website blocking", isOn: $isMacWebsiteBlockingEnabled)
                .toggleStyle(.switch)

            Text("Show the website blocking controls in Blocking settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
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

import SwiftData
import SwiftUI

extension View {
    func awayModeGate() -> some View {
        modifier(AwayModeRootModifier())
    }

    func awaySessionEditorSheet(session: Binding<AwaySession?>) -> some View {
        modifier(AwaySessionEditorSheetModifier(editingSession: session))
    }
}

private struct AwaySessionEditorSheetModifier: ViewModifier {
    @Binding var editingSession: AwaySession?
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false

    func body(content: Content) -> some View {
        content.sheet(isPresented: isPresented) {
            if isAwayEnabled, let editingSession {
                AwaySessionEditSheet(session: editingSession)
                    .id(editingSession.id)
            }
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { isAwayEnabled && editingSession != nil },
            set: { isPresented in
                if !isPresented {
                    editingSession = nil
                }
            }
        )
    }
}

private struct AwayModeRootModifier: ViewModifier {
    @Query private var activeAwaySessions: [AwaySession]
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false

    init() {
        _activeAwaySessions = Query(
            filter: #Predicate<AwaySession> { session in
                session.completedAt == nil && session.endedEarlyAt == nil
            },
            sort: \.startedAt,
            order: .reverse
        )
    }

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(visibleActiveAwaySession != nil)

            if let activeAwaySession = visibleActiveAwaySession {
                AwayModeFullScreenView(session: activeAwaySession)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: visibleActiveAwaySession?.id)
        #if os(macOS)
        .toolbarVisibility(visibleActiveAwaySession == nil ? .automatic : .hidden, for: .windowToolbar)
        #endif
    }

    private var visibleActiveAwaySession: AwaySession? {
        guard isAwayEnabled else { return nil }
        return activeAwaySession
    }

    private var activeAwaySession: AwaySession? {
        activeAwaySessions.first
    }
}

private enum AwaySessionTimerMode: String, CaseIterable, Identifiable {
    case fixedDuration
    case countUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixedDuration:
            return "Duration"
        case .countUp:
            return "Count Up"
        }
    }
}

private enum AwayStartPresetOption: Hashable, Identifiable {
    case away(AwaySessionPreset)
    case sleep

    static func options(includesSleep: Bool) -> [AwayStartPresetOption] {
        var options = AwaySessionPreset.allCases.map(AwayStartPresetOption.away)
        if includesSleep {
            options.append(.sleep)
        }
        return options
    }

    var id: String {
        switch self {
        case let .away(preset):
            return preset.rawValue
        case .sleep:
            return "sleep"
        }
    }

    var awayPreset: AwaySessionPreset? {
        guard case let .away(preset) = self else { return nil }
        return preset
    }

    var isSleep: Bool {
        self == .sleep
    }
}

enum AwaySessionStartPresentation {
    case sheet
    case inline
}

struct AwaySessionStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [RoutineTask]
    @State private var selectedOption: AwayStartPresetOption = .away(.wake)
    @State private var linkedTaskID: UUID?
    @State private var timerMode: AwaySessionTimerMode = .fixedDuration
    @State private var durationMinutes = AwaySessionPreset.wake.defaultDurationMinutes
    @State private var hasCustomizedDuration = false
    @State private var errorText: String?
    var presentation: AwaySessionStartPresentation = .sheet
    var onCancel: () -> Void = {}
    var onStarted: () -> Void = {}
    var onStartSleep: (() -> Void)?
    var dismissOnCompletion = true

    var body: some View {
        NavigationStack {
            startContent
            .navigationTitle(startTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        startSelectedOption()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private var startContent: some View {
        switch presentation {
        case .sheet:
            sheetContent
        case .inline:
            inlineContent
        }
    }

    private var sheetContent: some View {
        Form {
            Section("Preset") {
                Picker("Preset", selection: selectedOptionBinding) {
                    ForEach(startPresetOptions) { option in
                        Label(option.title, systemImage: option.systemImage)
                            .tag(option)
                    }
                }
                .pickerStyle(.inline)
            }

            if !selectedOption.isSleep {
                Section("Timer") {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Timer",
                        options: AwaySessionTimerMode.allCases,
                        selection: $timerMode,
                        fillsAvailableWidth: true
                    ) { mode in
                        Text(mode.title)
                    }

                    if timerMode == .fixedDuration {
                        Stepper(
                            "Duration: \(durationMinutes)m",
                            value: durationMinutesBinding,
                            in: 1...720,
                            step: 5
                        )
                    } else {
                        LabeledContent("Duration") {
                            Text("Open-ended")
                        }
                    }
                }

                AwayTaskLinkFormSection(
                    linkedTaskID: $linkedTaskID,
                    tasks: sortedTasks
                )
            }

            if let errorText {
                Section {
                    Text(errorText)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var inlineContent: some View {
        ZStack {
            LinearGradient(
                colors: [
                    selectedOption.tint.opacity(0.18),
                    Color.secondary.opacity(0.04),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AwayStartHeroCard(
                        option: selectedOption,
                        timerMode: timerMode,
                        durationMinutes: durationMinutes
                    )

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            AwayStartPresetPickerPanel(
                                selectedOption: selectedOptionBinding,
                                options: startPresetOptions,
                                selectedTint: selectedOption.tint
                            )
                            .frame(maxWidth: .infinity, alignment: .top)

                            VStack(spacing: 16) {
                                if !selectedOption.isSleep {
                                    AwayTimerSetupPanel(
                                        timerMode: $timerMode,
                                        durationMinutes: durationMinutesBinding,
                                        tint: selectedOption.tint
                                    )

                                    AwayTaskLinkPanel(
                                        linkedTaskID: $linkedTaskID,
                                        tasks: sortedTasks,
                                        tint: selectedOption.tint
                                    )
                                }

                                AwayStartSummaryPanel(
                                    option: selectedOption,
                                    timerMode: timerMode,
                                    durationMinutes: durationMinutes,
                                    errorText: errorText,
                                    onStart: startSelectedOption
                                )
                            }
                            .frame(width: 330)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            AwayStartPresetPickerPanel(
                                selectedOption: selectedOptionBinding,
                                options: startPresetOptions,
                                selectedTint: selectedOption.tint
                            )

                            if !selectedOption.isSleep {
                                AwayTimerSetupPanel(
                                    timerMode: $timerMode,
                                    durationMinutes: durationMinutesBinding,
                                    tint: selectedOption.tint
                                )

                                AwayTaskLinkPanel(
                                    linkedTaskID: $linkedTaskID,
                                    tasks: sortedTasks,
                                    tint: selectedOption.tint
                                )
                            }

                            AwayStartSummaryPanel(
                                option: selectedOption,
                                timerMode: timerMode,
                                durationMinutes: durationMinutes,
                                errorText: errorText,
                                onStart: startSelectedOption
                            )
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 1020, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private var startPresetOptions: [AwayStartPresetOption] {
        AwayStartPresetOption.options(includesSleep: onStartSleep != nil)
    }

    private var sortedTasks: [RoutineTask] {
        AwayTaskLinkPresentation.sortedTasks(tasks)
    }

    private var startTitle: String {
        selectedOption.isSleep ? "Start Sleep" : "Start Away"
    }

    private var selectedOptionBinding: Binding<AwayStartPresetOption> {
        Binding(
            get: { selectedOption },
            set: { option in
                selectedOption = option
                if !hasCustomizedDuration, let preset = option.awayPreset {
                    durationMinutes = preset.defaultDurationMinutes
                }
            }
        )
    }

    private var durationMinutesBinding: Binding<Int> {
        Binding(
            get: { durationMinutes },
            set: { value in
                durationMinutes = value
                hasCustomizedDuration = true
            }
        )
    }

    @MainActor
    private func cancel() {
        onCancel()
        if dismissOnCompletion {
            dismiss()
        }
    }

    @MainActor
    private func startSelectedOption() {
        switch selectedOption {
        case .away:
            startAway()
        case .sleep:
            startSleep()
        }
    }

    @MainActor
    private func startAway() {
        guard let selectedPreset = selectedOption.awayPreset else {
            startSleep()
            return
        }
        do {
            _ = try AwaySessionSupport.startAway(
                preset: selectedPreset,
                durationMinutes: timerMode == .fixedDuration ? durationMinutes : nil,
                countsUp: timerMode == .countUp,
                linkedTaskID: linkedTaskID,
                context: modelContext
            )
            errorText = nil
            onStarted()
            if dismissOnCompletion {
                dismiss()
            }
        } catch {
            errorText = error.localizedDescription
            NSLog("Failed to start away session: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func startSleep() {
        guard let onStartSleep else {
            errorText = "Sleep is unavailable from here."
            return
        }
        errorText = nil
        onStartSleep()
        if dismissOnCompletion {
            dismiss()
        }
    }
}

struct AwaySessionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [RoutineTask]
    let session: AwaySession
    @State private var selectedPreset: AwaySessionPreset
    @State private var title: String
    @State private var linkedTaskID: UUID?
    @State private var timerMode: AwaySessionTimerMode
    @State private var durationMinutes: Int
    @State private var startedAt: Date
    @State private var finishedAt: Date
    @State private var errorText: String?

    init(session: AwaySession) {
        self.session = session
        _selectedPreset = State(initialValue: session.preset)
        _title = State(initialValue: session.displayTitle)
        _linkedTaskID = State(initialValue: session.linkedTaskID)
        _timerMode = State(initialValue: session.isCountUp ? .countUp : .fixedDuration)
        _durationMinutes = State(initialValue: max(1, Int((session.plannedDurationSeconds / 60).rounded())))
        _startedAt = State(initialValue: session.startedAt ?? Date())
        _finishedAt = State(initialValue: session.finishedAt ?? session.plannedEndAt ?? Date())
    }

    var body: some View {
        NavigationStack {
            editContent
            .navigationTitle(session.isActive ? "Edit Away" : "Edit Away Session")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var editContent: some View {
        ZStack {
            LinearGradient(
                colors: [
                    selectedPreset.tint.opacity(0.18),
                    Color.secondary.opacity(0.04),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AwayStartHeroCard(
                        option: .away(selectedPreset),
                        timerMode: timerMode,
                        durationMinutes: durationMinutes,
                        titleOverride: displayTitle,
                        subtitleOverride: session.isActive ? "Adjust this running away session." : "Adjust this protected away window."
                    )

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 16) {
                                AwayEditDetailsPanel(
                                    title: $title,
                                    startedAt: $startedAt,
                                    finishedAt: $finishedAt,
                                    isActive: session.isActive,
                                    tint: selectedPreset.tint
                                )

                                AwayPresetPickerPanel(
                                    selectedPreset: $selectedPreset,
                                    selectedTint: selectedPreset.tint
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .top)

                            VStack(spacing: 16) {
                                AwayTimerSetupPanel(
                                    timerMode: $timerMode,
                                    durationMinutes: $durationMinutes,
                                    tint: selectedPreset.tint
                                )

                                AwayTaskLinkPanel(
                                    linkedTaskID: $linkedTaskID,
                                    tasks: sortedTasks,
                                    tint: selectedPreset.tint
                                )

                                AwayEditSummaryPanel(
                                    preset: selectedPreset,
                                    timerMode: timerMode,
                                    durationMinutes: durationMinutes,
                                    startedAt: startedAt,
                                    finishedAt: session.isActive ? nil : finishedAt,
                                    errorText: errorText,
                                    onSave: save
                                )
                            }
                            .frame(width: 330)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            AwayEditDetailsPanel(
                                title: $title,
                                startedAt: $startedAt,
                                finishedAt: $finishedAt,
                                isActive: session.isActive,
                                tint: selectedPreset.tint
                            )

                            AwayPresetPickerPanel(
                                selectedPreset: $selectedPreset,
                                selectedTint: selectedPreset.tint
                            )

                            AwayTimerSetupPanel(
                                timerMode: $timerMode,
                                durationMinutes: $durationMinutes,
                                tint: selectedPreset.tint
                            )

                            AwayTaskLinkPanel(
                                linkedTaskID: $linkedTaskID,
                                tasks: sortedTasks,
                                tint: selectedPreset.tint
                            )

                            AwayEditSummaryPanel(
                                preset: selectedPreset,
                                timerMode: timerMode,
                                durationMinutes: durationMinutes,
                                startedAt: startedAt,
                                finishedAt: session.isActive ? nil : finishedAt,
                                errorText: errorText,
                                onSave: save
                            )
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 1020, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private var sortedTasks: [RoutineTask] {
        AwayTaskLinkPresentation.sortedTasks(tasks)
    }

    private var displayTitle: String {
        AwaySession.cleanedDisplayTitle(title, fallback: selectedPreset.title)
    }

    @MainActor
    private func save() {
        do {
            _ = try AwaySessionSupport.update(
                session,
                preset: selectedPreset,
                title: title,
                linkedTaskID: linkedTaskID,
                startedAt: startedAt,
                plannedDurationSeconds: timerMode == .fixedDuration ? TimeInterval(durationMinutes * 60) : 0,
                finishedAt: session.isActive ? nil : finishedAt,
                in: modelContext
            )
            errorText = nil
            dismiss()
        } catch {
            errorText = error.localizedDescription
            NSLog("Failed to edit away session: \(error.localizedDescription)")
        }
    }
}

private enum AwayTaskLinkPresentation {
    static func sortedTasks(_ tasks: [RoutineTask]) -> [RoutineTask] {
        tasks.sorted { lhs, rhs in
            displayName(for: lhs).localizedCaseInsensitiveCompare(displayName(for: rhs)) == .orderedAscending
        }
    }

    static func displayName(for task: RoutineTask) -> String {
        let trimmedName = task.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? "Untitled Task" : trimmedName
    }
}

private struct AwayTaskLinkFormSection: View {
    @Binding var linkedTaskID: UUID?
    let tasks: [RoutineTask]

    var body: some View {
        Section("Task") {
            Picker("Linked task", selection: $linkedTaskID) {
                Text("No linked task")
                    .tag(Optional<UUID>.none)
                ForEach(tasks) { task in
                    Text(AwayTaskLinkPresentation.displayName(for: task))
                        .tag(Optional(task.id))
                }
            }
        }
    }
}

private struct AwayTaskLinkPanel: View {
    @Binding var linkedTaskID: UUID?
    let tasks: [RoutineTask]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Task", systemImage: "checklist")
                .font(.headline)

            Picker("Linked task", selection: $linkedTaskID) {
                Text("No linked task")
                    .tag(Optional<UUID>.none)
                ForEach(tasks) { task in
                    Text(AwayTaskLinkPresentation.displayName(for: task))
                        .tag(Optional(task.id))
                }
            }
            .pickerStyle(.menu)

            if let linkedTask = tasks.first(where: { $0.id == linkedTaskID }) {
                AwayStartSummaryRow(
                    title: "Linked",
                    value: AwayTaskLinkPresentation.displayName(for: linkedTask),
                    systemImage: "link",
                    tint: tint
                )
            }
        }
        .padding(16)
        .routinaGlassPanel(cornerRadius: 16, tint: tint, tintOpacity: 0.06)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct AwayEditDetailsPanel: View {
    @Binding var title: String
    @Binding var startedAt: Date
    @Binding var finishedAt: Date
    let isActive: Bool
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Details", systemImage: "slider.horizontal.3")
                .font(.headline)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            VStack(spacing: 10) {
                DatePicker("Started", selection: $startedAt)

                if !isActive {
                    DatePicker("Ended", selection: $finishedAt)
                }
            }
            .font(.subheadline)
        }
        .padding(16)
        .routinaGlassPanel(cornerRadius: 16, tint: tint, tintOpacity: 0.06)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct AwayEditSummaryPanel: View {
    let preset: AwaySessionPreset
    let timerMode: AwaySessionTimerMode
    let durationMinutes: Int
    let startedAt: Date
    let finishedAt: Date?
    let errorText: String?
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Ready", systemImage: "checkmark.circle.fill")
                .font(.headline)

            VStack(spacing: 10) {
                AwayStartSummaryRow(
                    title: "Preset",
                    value: preset.title,
                    systemImage: preset.systemImage,
                    tint: preset.tint
                )
                AwayStartSummaryRow(
                    title: "Timer",
                    value: timerText,
                    systemImage: timerMode == .fixedDuration ? "timer" : "infinity",
                    tint: preset.tint
                )
                AwayStartSummaryRow(
                    title: "Started",
                    value: timeText(startedAt),
                    systemImage: "play.fill",
                    tint: preset.tint
                )

                if let finishedAt {
                    AwayStartSummaryRow(
                        title: "Ended",
                        value: timeText(finishedAt),
                        systemImage: "flag.checkered",
                        tint: preset.tint
                    )
                }
            }

            Button {
                onSave()
            } label: {
                Label("Save Away", systemImage: "checkmark.circle.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(preset.actionForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(preset.actionTint, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .contentShape(Capsule())
            .keyboardShortcut(.defaultAction)

            if let errorText {
                Text(errorText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .routinaGlassPanel(cornerRadius: 16, tint: preset.tint, tintOpacity: 0.08)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(preset.tint.opacity(0.18), lineWidth: 1)
        }
    }

    private var timerText: String {
        timerMode == .fixedDuration ? "\(durationMinutes)m duration" : "Count up"
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct AwayStartHeroCard: View {
    let option: AwayStartPresetOption
    let timerMode: AwaySessionTimerMode
    let durationMinutes: Int
    var titleOverride: String?
    var subtitleOverride: String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                heroIcon
                titleBlock
                Spacer(minLength: 16)
                heroMetric
            }

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    heroIcon
                    titleBlock
                }
                heroMetric
            }
        }
        .padding(20)
        .routinaGlassPanel(cornerRadius: 18, tint: option.tint, tintOpacity: 0.10)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(option.tint.opacity(0.22), lineWidth: 1)
        }
    }

    private var heroIcon: some View {
        Image(systemName: option.systemImage)
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(.white)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 62, height: 62)
            .background(
                LinearGradient(
                    colors: [
                        option.tint,
                        option.tint.opacity(0.58)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(option.modeEyebrow)
                .font(.caption.weight(.bold))
                .foregroundStyle(option.tint)
                .textCase(.uppercase)

            Text(titleOverride ?? option.title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(subtitleOverride ?? option.startLine)
                .font(.headline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroMetric: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(option.timerSummary(timerMode: timerMode, durationMinutes: durationMinutes))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(option.timerCaption(timerMode: timerMode))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .routinaGlassCard(cornerRadius: 14, tint: option.tint, tintOpacity: 0.08)
    }
}

private struct AwayStartPresetPickerPanel: View {
    @Binding var selectedOption: AwayStartPresetOption
    let options: [AwayStartPresetOption]
    let selectedTint: Color

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Preset", systemImage: "square.grid.2x2.fill")
                .font(.headline)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(options) { option in
                    AwayPresetCard(
                        title: option.title,
                        systemImage: option.systemImage,
                        defaultDurationText: option.defaultDurationText,
                        presetTint: option.tint,
                        isSelected: selectedOption == option,
                        selectedTint: selectedTint
                    ) {
                        selectedOption = option
                    }
                }
            }
        }
        .padding(16)
        .routinaGlassPanel(cornerRadius: 16, tint: selectedTint, tintOpacity: 0.06)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct AwayPresetPickerPanel: View {
    @Binding var selectedPreset: AwaySessionPreset
    let selectedTint: Color

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Preset", systemImage: "square.grid.2x2.fill")
                .font(.headline)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(AwaySessionPreset.allCases) { preset in
                    AwayPresetCard(
                        title: preset.title,
                        systemImage: preset.systemImage,
                        defaultDurationText: preset.defaultDurationText,
                        presetTint: preset.tint,
                        isSelected: selectedPreset == preset,
                        selectedTint: selectedTint
                    ) {
                        selectedPreset = preset
                    }
                }
            }
        }
        .padding(16)
        .routinaGlassPanel(cornerRadius: 16, tint: selectedTint, tintOpacity: 0.06)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct AwayPresetCard: View {
    let title: String
    let systemImage: String
    let defaultDurationText: String
    let presetTint: Color
    let isSelected: Bool
    let selectedTint: Color
    let action: () -> Void

    private var tint: Color {
        isSelected ? selectedTint : presetTint
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : tint)
                        .frame(width: 34, height: 34)
                        .background(
                            isSelected ? tint : tint.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )

                    Spacer(minLength: 8)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? tint : .secondary.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(defaultDurationText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(isSelected ? 0.16 : 0.06))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(isSelected ? 0.55 : 0.14), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AwayTimerSetupPanel: View {
    @Binding var timerMode: AwaySessionTimerMode
    @Binding var durationMinutes: Int
    let tint: Color

    private let quickDurations = [10, 15, 20, 30, 45, 60, 90]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Timer", systemImage: "timer")
                .font(.headline)

            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Timer",
                options: AwaySessionTimerMode.allCases,
                selection: $timerMode,
                fillsAvailableWidth: true
            ) { mode in
                Text(mode.title)
            }

            if timerMode == .fixedDuration {
                fixedDurationControls
            } else {
                countUpContent
            }
        }
        .padding(16)
        .routinaGlassPanel(cornerRadius: 16, tint: tint, tintOpacity: 0.06)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var fixedDurationControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(durationMinutes)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("min")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Slider(value: durationSliderBinding, in: 1...180, step: 5)
                .tint(tint)

            HomeFilterFlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
                ForEach(quickDurations, id: \.self) { minutes in
                    Button {
                        durationMinutes = minutes
                    } label: {
                        Text("\(minutes)m")
                            .font(.caption.weight(.semibold))
                            .frame(minWidth: 42)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(durationMinutes == minutes ? .white : tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        durationMinutes == minutes ? tint : tint.opacity(0.12),
                        in: Capsule()
                    )
                }
            }

            Stepper(
                "Fine tune: \(durationMinutes)m",
                value: $durationMinutes,
                in: 1...720,
                step: 5
            )
            .font(.subheadline)
        }
    }

    private var countUpContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open-ended")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("Start now and stop it when you return.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var durationSliderBinding: Binding<Double> {
        Binding(
            get: { Double(min(durationMinutes, 180)) },
            set: { durationMinutes = max(1, Int($0.rounded())) }
        )
    }
}

private struct AwayStartSummaryPanel: View {
    let option: AwayStartPresetOption
    let timerMode: AwaySessionTimerMode
    let durationMinutes: Int
    let errorText: String?
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Ready", systemImage: "play.circle.fill")
                .font(.headline)

            VStack(spacing: 10) {
                AwayStartSummaryRow(
                    title: "Preset",
                    value: option.title,
                    systemImage: option.systemImage,
                    tint: option.tint
                )
                AwayStartSummaryRow(
                    title: "Timer",
                    value: option.timerText(timerMode: timerMode, durationMinutes: durationMinutes),
                    systemImage: option.timerSystemImage(timerMode: timerMode),
                    tint: option.tint
                )
                AwayStartSummaryRow(
                    title: "Starts",
                    value: "Now",
                    systemImage: "paperplane.fill",
                    tint: option.tint
                )
            }

            Button {
                onStart()
            } label: {
                Label(option.startActionTitle, systemImage: option.startActionSystemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(option.actionForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(option.actionTint, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .contentShape(Capsule())
            .keyboardShortcut(.defaultAction)

            if let errorText {
                Text(errorText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .routinaGlassPanel(cornerRadius: 16, tint: option.tint, tintOpacity: 0.08)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(option.tint.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct AwayStartSummaryRow: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 10)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }
}

private extension AwaySessionPreset {
    var tint: Color {
        switch self {
        case .wake:
            return .orange
        case .reset:
            return .teal
        case .outside:
            return .green
        case .windDown:
            return .indigo
        case .meal:
            return .pink
        case .custom:
            return .cyan
        }
    }

    var actionTint: Color {
        switch self {
        case .wake:
            return Color(red: 0.96, green: 0.57, blue: 0.16)
        default:
            return tint
        }
    }

    var actionForeground: Color {
        switch self {
        case .windDown:
            return .white
        default:
            return Color.black.opacity(0.84)
        }
    }

    var defaultDurationText: String {
        "\(defaultDurationMinutes)m default"
    }

    var startLine: String {
        switch self {
        case .wake:
            return "A clean first pocket away from the screen."
        case .reset:
            return "A short reset before the next thing."
        case .outside:
            return "A protected walk or errand."
        case .windDown:
            return "A softer landing before rest."
        case .meal:
            return "A meal without the app pulling you back."
        case .custom:
            return "A flexible away session."
        }
    }
}

private struct AwayModeFullScreenView: View {
    @Environment(\.modelContext) private var modelContext
    let session: AwaySession
    @State private var errorText: String?
    @State private var isEditing = false

    var body: some View {
        ZStack {
            awayBackground

            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { timeline in
                AwayModeContent(
                    session: session,
                    now: timeline.date,
                    errorText: errorText,
                    onEdit: { isEditing = true },
                    onExtend: extendAway,
                    onEnd: endAway
                )
                .task(id: session.isExpired(at: timeline.date)) {
                    guard session.isExpired(at: timeline.date) else { return }
                    completeExpired(referenceDate: timeline.date)
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $isEditing) {
            AwaySessionEditSheet(session: session)
                .id(session.id)
        }
        .accessibilityElement(children: .contain)
    }

    private var awayBackground: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.04, green: 0.12, blue: 0.12),
                Color(red: 0.09, green: 0.10, blue: 0.15)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @MainActor
    private func completeExpired(referenceDate: Date) {
        do {
            _ = try AwaySessionSupport.completeExpiredSessions(
                in: modelContext,
                referenceDate: referenceDate
            )
            errorText = nil
        } catch {
            errorText = "Could not save away time."
            NSLog("Failed to complete expired away session: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func extendAway() {
        do {
            _ = try AwaySessionSupport.extendActiveAway(
                byMinutes: 5,
                in: modelContext
            )
            errorText = nil
        } catch {
            errorText = "Could not extend away time."
            NSLog("Failed to extend away session: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func endAway() {
        do {
            if session.isCountUp {
                _ = try AwaySessionSupport.completeActiveAway(in: modelContext)
            } else {
                _ = try AwaySessionSupport.endActiveAwayEarly(in: modelContext)
            }
            errorText = nil
        } catch {
            errorText = "Could not end away time."
            NSLog("Failed to end away session: \(error.localizedDescription)")
        }
    }
}

private struct AwayModeContent: View {
    let session: AwaySession
    let now: Date
    let errorText: String?
    let onEdit: () -> Void
    let onExtend: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 32)

            VStack(spacing: 10) {
                Image(systemName: session.preset.systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)

                Text(session.displayTitle)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Routina is holding this window for you.")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.76))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: session.completionProgress(referenceDate: now))
                        .stroke(.teal, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 5) {
                        Text(AwaySessionFormatting.timerText(seconds: timerSeconds))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()

                        Text(timerLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }
                .frame(width: 190, height: 190)

                VStack(spacing: 12) {
                    AwayMetricRow(
                        title: "Started",
                        value: timeText(session.startedAt),
                        systemImage: "play.fill"
                    )
                    AwayMetricRow(
                        title: "Ends",
                        value: session.isCountUp ? "Open-ended" : timeText(session.plannedEndAt),
                        systemImage: "flag.checkered"
                    )
                    AwayMetricRow(
                        title: "Protected",
                        value: AwaySessionFormatting.durationText(
                            seconds: session.durationSeconds(referenceDate: now)
                        ),
                        systemImage: "lock.shield.fill"
                    )
                }
                .padding(18)
                .routinaGlassPanel(cornerRadius: 18, tint: .white, tintOpacity: 0.14)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
            }

            Spacer(minLength: 16)

            VStack(spacing: 10) {
                Button {
                    onEdit()
                } label: {
                    Label("Edit away", systemImage: "slider.horizontal.3")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.white)

                if !session.isCountUp {
                    Button {
                        onExtend()
                    } label: {
                        Label("Extend 5 min", systemImage: "plus.circle.fill")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.teal)
                }

                if session.isCountUp {
                    Button {
                        onEnd()
                    } label: {
                        Label("End away", systemImage: "checkmark.circle.fill")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.teal)
                } else {
                    Button(role: .destructive) {
                        onEnd()
                    } label: {
                        Text("End early")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .buttonStyle(.plain)
                }

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.95))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var timerSeconds: TimeInterval {
        session.isCountUp
            ? session.durationSeconds(referenceDate: now)
            : session.remainingSeconds(referenceDate: now)
    }

    private var timerLabel: String {
        session.isCountUp ? "elapsed" : "remaining"
    }

    private func timeText(_ date: Date?) -> String {
        guard let date else { return "Unknown" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct AwayMetricRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 28, height: 28)
                .routinaGlassPill(tint: .white, tintOpacity: 0.14)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.70))

            Spacer(minLength: 12)

            Text(value)
                .font(.headline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

extension AwaySessionPreset: Identifiable {
    var id: String { rawValue }
}

private extension AwayStartPresetOption {
    var title: String {
        switch self {
        case let .away(preset):
            return preset.title
        case .sleep:
            return "Sleep"
        }
    }

    var systemImage: String {
        switch self {
        case let .away(preset):
            return preset.systemImage
        case .sleep:
            return "bed.double.fill"
        }
    }

    var tint: Color {
        switch self {
        case let .away(preset):
            return preset.tint
        case .sleep:
            return .orange
        }
    }

    var actionTint: Color {
        switch self {
        case let .away(preset):
            return preset.actionTint
        case .sleep:
            return Color(red: 0.96, green: 0.57, blue: 0.16)
        }
    }

    var actionForeground: Color {
        switch self {
        case let .away(preset):
            return preset.actionForeground
        case .sleep:
            return Color.black.opacity(0.84)
        }
    }

    var defaultDurationText: String {
        switch self {
        case let .away(preset):
            return preset.defaultDurationText
        case .sleep:
            return "\(sleepDurationText) target"
        }
    }

    var modeEyebrow: String {
        isSleep ? "Sleep mode" : "Away mode"
    }

    var startLine: String {
        switch self {
        case let .away(preset):
            return preset.startLine
        case .sleep:
            return "A protected wind-down for real rest."
        }
    }

    var startActionTitle: String {
        isSleep ? "Start Sleep" : "Start Away"
    }

    var startActionSystemImage: String {
        isSleep ? "bed.double.fill" : "lock.shield.fill"
    }

    func timerSummary(timerMode: AwaySessionTimerMode, durationMinutes: Int) -> String {
        guard !isSleep else { return sleepDurationText }
        return timerMode == .fixedDuration ? "\(durationMinutes)m" : "Count up"
    }

    func timerCaption(timerMode: AwaySessionTimerMode) -> String {
        guard !isSleep else { return "sleep target" }
        return timerMode == .fixedDuration ? "protected timer" : "open timer"
    }

    func timerText(timerMode: AwaySessionTimerMode, durationMinutes: Int) -> String {
        guard !isSleep else { return "\(sleepDurationText) target" }
        return timerMode == .fixedDuration ? "\(durationMinutes)m duration" : "Count up"
    }

    func timerSystemImage(timerMode: AwaySessionTimerMode) -> String {
        guard !isSleep else { return "alarm.fill" }
        return timerMode == .fixedDuration ? "timer" : "infinity"
    }

    private var sleepDurationText: String {
        SleepSessionFormatting.durationText(seconds: 8 * 60 * 60)
    }
}

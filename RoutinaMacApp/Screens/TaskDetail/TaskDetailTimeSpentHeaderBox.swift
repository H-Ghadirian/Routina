import SwiftData
import SwiftUI

struct TaskDetailTimeSpentHeaderBox: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Query(
        filter: #Predicate<SleepSession> { session in
            session.endedAt == nil
        },
        sort: \.startedAt,
        order: .reverse
    ) private var activeSleepSessions: [SleepSession]
    @Query(
        filter: #Predicate<AwaySession> { session in
            session.completedAt == nil && session.endedEarlyAt == nil
        },
        sort: \.startedAt,
        order: .reverse
    ) private var activeAwaySessions: [AwaySession]
    @AppStorage(
        "macTaskDetailLastActualTimeEntryMinutes",
        store: SharedDefaults.app
    ) private var savedActualTimeEntryMinutes = 0
    @AppStorage(
        "macTaskDetailLastFocusCountdownMinutes",
        store: SharedDefaults.app
    ) private var savedFocusCountdownMinutes = TaskDetailTimeSpentPresentation.defaultFocusCountdownMinutes
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false

    let task: RoutineTask
    let focusSessions: [FocusSession]
    let allTasks: [RoutineTask]
    let resetToken: Int
    let blockingFocusTitle: String?
    @Binding var isExpanded: Bool
    @Binding var entryHours: Int
    @Binding var entryMinutes: Int
    let onApplyMinutes: (Int) -> Void
    let onEditTotal: () -> Void

    @State private var focusStartMode = TaskDetailFocusStartMode.countdown
    @State private var isActualTimeEditorPresented = false
    @State private var isFocusStartEditorPresented = false

    var body: some View {
        let isForcedExpanded = TaskDetailTimeSpentPresentation.shouldForceExpandSection(
            hasActiveFocus: hasActiveFocusForTask,
            showsFocusTimer: effectiveFocusEnabled
        )
        let isContentExpanded = isExpanded || isForcedExpanded

        VStack(alignment: .leading, spacing: 12) {
            if TaskDetailTimeSpentPresentation.showsDisclosureControl(
                hasActiveFocus: hasActiveFocusForTask
            ) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isExpanded.toggle()
                    }
                } label: {
                    effortHeader(
                        isContentExpanded: isContentExpanded,
                        showsDisclosureIndicator: true
                    )
                }
                .buttonStyle(.plain)
            } else {
                effortHeader(
                    isContentExpanded: isContentExpanded,
                    showsDisclosureIndicator: false
                )
            }

            if isContentExpanded {
                expandedContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .detailHeaderBoxStyle(tint: .cyan)
        .onAppear(perform: resetEntry)
        .onChange(of: task.id) { _, _ in
            resetEntry()
            isActualTimeEditorPresented = false
            isFocusStartEditorPresented = false
        }
        .onChange(of: task.actualDurationMinutes) { _, _ in resetEntry() }
        .onChange(of: resetToken) { _, _ in resetEntry() }
    }

    private func effortHeader(
        isContentExpanded: Bool,
        showsDisclosureIndicator: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(width: 32, height: 32)
                .routinaGlassPill(tint: .cyan, tintOpacity: 0.16)

            effortSummary(isContentExpanded: isContentExpanded)

            Spacer(minLength: 8)

            if showsDisclosureIndicator {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isContentExpanded ? 180 : 0))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func effortSummary(isContentExpanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EFFORT")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            if !isContentExpanded {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 18) {
                        ForEach(effortMetrics) { metric in
                            effortMetricView(metric)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(effortMetrics) { metric in
                            effortMetricView(metric)
                        }
                    }
                }
            }
        }
    }

    private func effortMetricView(_ metric: TaskDetailEffortMetric) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if let systemImage = metric.systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(metric.tint)
                }

                Text(metric.value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(metric.isMuted ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .opacity(0.35)

            actualTimeContent

            if shouldShowFocusTimerSection {
                Divider()
                    .opacity(0.35)

                focusTimerContent
            }
        }
    }

    private var actualTimeContent: some View {
        compactEffortRow(
            title: "Actual time",
            value: actualTimeDisplayText,
            systemImage: task.actualDurationMinutes == nil ? "clock.badge" : "clock.fill",
            tint: .cyan,
            isValueMuted: task.actualDurationMinutes == nil
        ) {
            HStack(spacing: 8) {
                Button {
                    isActualTimeEditorPresented = true
                } label: {
                    Label(
                        task.actualDurationMinutes == nil ? "Log time" : "Add time",
                        systemImage: "plus.circle.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.cyan)
                .popover(isPresented: $isActualTimeEditorPresented, arrowEdge: .bottom) {
                    actualTimeEditor
                }

                if task.actualDurationMinutes != nil {
                    Button(action: onEditTotal) {
                        Label("Edit total", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.cyan)
                    .accessibilityLabel("Edit total time spent")
                }
            }
        }
    }

    private var focusTimerContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            compactEffortRow(
                title: "Focus",
                value: focusSummaryText,
                systemImage: hasActiveFocusForTask ? "timer.circle.fill" : "timer",
                tint: .teal,
                isValueMuted: !hasActiveFocusForTask && !hasCompletedFocusHistory
            ) {
                if canStartFocus {
                    Button {
                        isFocusStartEditorPresented = true
                    } label: {
                        Label("Start focus", systemImage: "timer")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.teal)
                    .popover(isPresented: $isFocusStartEditorPresented, arrowEdge: .bottom) {
                        focusStartEditor
                    }
                }
            }

            if !visibleActiveAwaySessions.isEmpty {
                awaySessionBlockingContent
            }

            if shouldShowFocusDetails {
                focusSessionContent
            }
        }
    }

    private func compactEffortRow<Actions: View>(
        title: String,
        value: String,
        systemImage: String,
        tint: Color,
        isValueMuted: Bool,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                compactEffortValue(
                    title: title,
                    value: value,
                    systemImage: systemImage,
                    tint: tint,
                    isValueMuted: isValueMuted
                )

                Spacer(minLength: 16)

                actions()
            }

            VStack(alignment: .leading, spacing: 10) {
                compactEffortValue(
                    title: title,
                    value: value,
                    systemImage: systemImage,
                    tint: tint,
                    isValueMuted: isValueMuted
                )
                actions()
            }
        }
        .frame(maxWidth: 720, alignment: .leading)
    }

    private func compactEffortValue(
        title: String,
        value: String,
        systemImage: String,
        tint: Color,
        isValueMuted: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(value)
                    .font(.caption)
                    .foregroundStyle(isValueMuted ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private var actualTimeEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.actualDurationMinutes == nil ? "Log actual time" : "Add actual time")
                    .font(.headline)
                Text(
                    task.actualDurationMinutes == nil
                        ? "Record time without changing Focus history."
                        : "Add this duration to the recorded total."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Stepper(
                value: actualTimeEntryBinding,
                in: TaskDetailTimeSpentPresentation.minimumMinutes...TaskDetailTimeSpentPresentation.maximumMinutes,
                step: 5
            ) {
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(RoutineTimeSpentFormatting.compactMinutesText(entryTotalMinutes))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }

            if task.actualDurationMinutes != nil {
                Text(
                    TaskDetailTimeSpentPresentation.previewText(
                        currentMinutes: task.actualDurationMinutes,
                        entryMinutes: entryTotalMinutes
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()

                Button(task.actualDurationMinutes == nil ? "Log time" : "Add time") {
                    applyEntry()
                    isActualTimeEditorPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(!canApplyEntry)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 340)
        .padding(18)
    }

    private var focusStartEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Start focus")
                    .font(.headline)
                Text("Focus time stays separate from Actual time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Timer", selection: $focusStartMode) {
                ForEach(TaskDetailFocusStartMode.allCases) { mode in
                    Text(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if focusStartMode == .countdown {
                Stepper(
                    value: focusCountdownMinutesBinding,
                    in: TaskDetailTimeSpentPresentation.minimumMinutes...TaskDetailTimeSpentPresentation.maximumMinutes,
                    step: 5
                ) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(RoutineTimeSpentFormatting.compactMinutesText(focusCountdownMinutes))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                }
            }

            HStack {
                Spacer()

                Button("Start focus") {
                    let durationSeconds = focusStartMode == .countdown
                        ? TimeInterval(focusCountdownMinutes * 60)
                        : 0
                    startFocus(durationSeconds: durationSeconds)
                    isFocusStartEditorPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 340)
        .padding(18)
    }

    private var awaySessionBlockingContent: some View {
        Label("Away time is active — end it before starting Focus.", systemImage: "figure.walk")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: 720, alignment: .leading)
    }

    private var focusSessionContent: some View {
        FocusSessionCard(
            task: task,
            sessions: focusSessions,
            allTasks: allTasks,
            isEmbedded: true,
            showsEmbeddedHeader: false,
            showsEmbeddedStartControls: false,
            blockingFocusTitle: blockingFocusTitle
        )
    }

    private var actualTimeDisplayText: String {
        task.actualDurationMinutes.map(TaskDetailHeaderBadgePresentation.durationText(for:)) ?? "Not logged"
    }

    private var focusSnapshot: FocusSessionCardSnapshot {
        FocusSessionCardSnapshot(taskID: task.id, sessions: focusSessions)
    }

    private var focusSummaryText: String {
        if hasActiveFocusForTask {
            return "Running"
        }

        let count = focusSnapshot.completedSessionsForTask.count
        if count > 0 {
            let duration = FocusSessionFormatting.compactDurationText(
                seconds: focusSnapshot.totalCompletedSeconds
            )
            let sessions = count == 1 ? "1 session" : "\(count) sessions"
            return "\(duration) · \(sessions)"
        }

        return "Ready to start"
    }

    private var effortMetrics: [TaskDetailEffortMetric] {
        var metrics: [TaskDetailEffortMetric] = []

        if let estimatedDurationMinutes = task.estimatedDurationMinutes {
            metrics.append(
                TaskDetailEffortMetric(
                    title: "ESTIMATE",
                    value: TaskDetailHeaderBadgePresentation.durationText(for: estimatedDurationMinutes),
                    systemImage: "hourglass",
                    tint: .teal
                )
            )
        }

        if let actualDurationMinutes = task.actualDurationMinutes {
            metrics.append(
                TaskDetailEffortMetric(
                    title: "ACTUAL",
                    value: TaskDetailHeaderBadgePresentation.durationText(for: actualDurationMinutes),
                    systemImage: "clock.fill",
                    tint: .cyan
                )
            )
        }

        if shouldShowFocusTimerSection {
            metrics.append(
                TaskDetailEffortMetric(
                    title: "FOCUS",
                    value: focusSummaryText,
                    systemImage: hasActiveFocusForTask ? "timer.circle.fill" : "timer",
                    tint: .teal,
                    isMuted: !hasActiveFocusForTask && !hasCompletedFocusHistory
                )
            )
        }

        if let storyPoints = task.storyPoints {
            metrics.append(
                TaskDetailEffortMetric(
                    title: "POINTS",
                    value: TaskDetailHeaderBadgePresentation.storyPointsText(for: storyPoints),
                    systemImage: "number",
                    tint: .purple
                )
            )
        }

        if metrics.isEmpty {
            metrics.append(
                TaskDetailEffortMetric(
                    title: "ACTUAL",
                    value: "Not logged",
                    systemImage: "clock.badge",
                    tint: .cyan,
                    isMuted: true
                )
            )
        }

        return metrics
    }

    private var entryTotalMinutes: Int {
        TaskDetailTimeSpentPresentation.entryTotalMinutes(
            hours: entryHours,
            minutes: entryMinutes
        )
    }

    private var actualTimeEntryBinding: Binding<Int> {
        Binding(
            get: { entryTotalMinutes },
            set: { setEntryTotal($0) }
        )
    }

    private var focusCountdownMinutes: Int {
        TaskDetailTimeSpentPresentation.resolvedFocusCountdownMinutes(
            savedMinutes: savedFocusCountdownMinutes
        )
    }

    private var focusCountdownMinutesBinding: Binding<Int> {
        Binding(
            get: { focusCountdownMinutes },
            set: { setFocusCountdownMinutes($0) }
        )
    }

    private var previewMinutes: Int {
        TaskDetailTimeSpentPresentation.previewTotalMinutes(
            currentMinutes: task.actualDurationMinutes,
            entryMinutes: entryTotalMinutes
        )
    }

    private var shouldShowFocusTimerSection: Bool {
        effectiveFocusEnabled || hasActiveFocusForTask || hasCompletedFocusHistory
    }

    private var shouldShowFocusDetails: Bool {
        shouldShowFocusTimerSection
            && (
                !activeSleepSessions.isEmpty
                    || !focusSnapshot.completedSessionsForTask.isEmpty
                    || focusSessions.contains { $0.state == .active }
                    || blockingFocusTitle != nil
            )
    }

    private var effectiveFocusEnabled: Bool {
        task.focusModeEnabled || hasCompletedFocusHistory
    }

    private var canStartFocus: Bool {
        effectiveFocusEnabled
            && activeSleepSessions.isEmpty
            && visibleActiveAwaySessions.isEmpty
            && blockingFocusTitle == nil
            && !focusSessions.contains { $0.state == .active }
    }

    private var visibleActiveAwaySessions: [AwaySession] {
        isAwayEnabled ? activeAwaySessions : []
    }

    private var canApplyEntry: Bool {
        TaskDetailTimeSpentPresentation.canApplyEntry(
            currentMinutes: task.actualDurationMinutes,
            entryMinutes: entryTotalMinutes
        )
    }

    private var hasCompletedFocusHistory: Bool {
        !focusSnapshot.completedSessionsForTask.isEmpty
    }

    private var hasActiveFocusForTask: Bool {
        focusSnapshot.activeSessionForTask != nil
    }

    private func setEntryTotal(_ minutes: Int, persist: Bool = true) {
        let clampedMinutes = TaskDetailTimeSpentPresentation.clampedMinutes(minutes)
        entryHours = clampedMinutes / 60
        entryMinutes = clampedMinutes % 60
        if persist {
            savedActualTimeEntryMinutes = clampedMinutes
        }
    }

    private func setFocusCountdownMinutes(_ minutes: Int) {
        savedFocusCountdownMinutes = TaskDetailTimeSpentPresentation.clampedMinutes(minutes)
    }

    private func resetEntry() {
        let storedMinutes = TaskDetailTimeSpentPresentation.clampedMinutes(savedActualTimeEntryMinutes)
        let defaultMinutes = savedActualTimeEntryMinutes > 0
            ? storedMinutes
            : TaskDetailTimeSpentPresentation.defaultAdditionalEntryMinutes(
                currentMinutes: task.actualDurationMinutes,
                estimatedMinutes: task.estimatedDurationMinutes
            )
        setEntryTotal(defaultMinutes, persist: false)
    }

    private func applyEntry() {
        guard canApplyEntry else { return }
        savedActualTimeEntryMinutes = entryTotalMinutes
        onApplyMinutes(previewMinutes)
    }

    private func startFocus(durationSeconds: TimeInterval) {
        guard canStartFocus else { return }
        do {
            _ = try FocusSessionSupport.startTaskFocus(
                task: task,
                plannedDurationSeconds: durationSeconds,
                context: modelContext,
                calendar: calendar
            )
        } catch {
            NSLog("Failed to start task focus from Effort: \(error.localizedDescription)")
        }
    }
}

private struct TaskDetailEffortMetric: Identifiable {
    let title: String
    let value: String
    let systemImage: String?
    let tint: Color
    var isMuted = false

    var id: String { title }
}

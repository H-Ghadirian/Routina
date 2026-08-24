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

    private let actualTimeQuickEntryMinutes = [15, 30, 60]
    private let focusCountdownQuickEntryMinutes = [25, 45, 60]
    private let stepMinutes = 5

    var body: some View {
        let isForcedExpanded = TaskDetailTimeSpentPresentation.shouldForceExpandSection(
            hasActiveFocus: hasActiveFocusForTask,
            showsFocusTimer: task.focusModeEnabled
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
        .frame(maxWidth: .infinity, minHeight: isContentExpanded ? 120 : nil, alignment: .topLeading)
        .detailHeaderBoxStyle(tint: .cyan)
        .onAppear(perform: resetEntry)
        .onChange(of: task.id) { _, _ in resetEntry() }
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

            effortSummary

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

    private var effortSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EFFORT")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

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
        VStack(alignment: .leading, spacing: 10) {
            effortControlHeader(
                title: "ACTUAL TIME",
                detail: "Recorded duration"
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 14) {
                    actualTimeDurationStepper
                    actualTimeQuickDurations
                    actualTimeActions
                }

                VStack(alignment: .leading, spacing: 10) {
                    actualTimeDurationStepper
                    actualTimeQuickDurations
                    actualTimeActions
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Log actual time")
        }
    }

    private var focusTimerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            effortControlHeader(
                title: "FOCUS TIMER",
                detail: "Attention-session tracking"
            )

            if canStartFocus {
                focusStartControls
            } else if !visibleActiveAwaySessions.isEmpty {
                awaySessionBlockingContent
            }

            if shouldShowFocusDetails && visibleActiveAwaySessions.isEmpty {
                focusSessionContent
            }
        }
    }

    private func effortControlHeader(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var focusStartControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Focus mode", selection: $focusStartMode) {
                ForEach(TaskDetailFocusStartMode.allCases) { mode in
                    Text(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            switch focusStartMode {
            case .countdown:
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 14) {
                        focusCountdownDurationStepper
                        focusCountdownQuickDurations
                        startCountdownButton
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        focusCountdownDurationStepper
                        focusCountdownQuickDurations
                        startCountdownButton
                    }
                }
            case .countUp:
                startCountUpButton
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Start focus timer")
    }

    private var awaySessionBlockingContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Away time is active", systemImage: "figure.walk")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("End away time before starting a focus timer.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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

    private var actualTimeDurationStepper: some View {
        durationStepper(
            minutes: entryTotalMinutes,
            accessibilityContext: "actual time",
            onAdjust: { adjustEntry(by: $0) }
        )
    }

    private var focusCountdownDurationStepper: some View {
        durationStepper(
            minutes: focusCountdownMinutes,
            accessibilityContext: "focus countdown",
            onAdjust: { adjustFocusCountdown(by: $0) }
        )
    }

    private func durationStepper(
        minutes: Int,
        accessibilityContext: String,
        onAdjust: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            stepperButton(
                systemImage: "minus",
                accessibilityLabel: "Decrease \(accessibilityContext) by \(stepMinutes) minutes",
                isDisabled: minutes <= TaskDetailTimeSpentPresentation.minimumMinutes
            ) {
                onAdjust(-stepMinutes)
            }

            Text(RoutineTimeSpentFormatting.compactMinutesText(minutes))
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(minWidth: 58)
                .accessibilityLabel(TaskDetailHeaderBadgePresentation.durationText(for: minutes))

            stepperButton(
                systemImage: "plus",
                accessibilityLabel: "Increase \(accessibilityContext) by \(stepMinutes) minutes",
                isDisabled: minutes >= TaskDetailTimeSpentPresentation.maximumMinutes
            ) {
                onAdjust(stepMinutes)
            }
        }
    }

    private func stepperButton(
        systemImage: String,
        accessibilityLabel: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isDisabled ? Color.secondary.opacity(0.45) : Color.primary)
                .frame(width: 50, height: 34)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(isDisabled ? 0.07 : 0.12))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.secondary.opacity(isDisabled ? 0.08 : 0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .contentShape(Rectangle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var actualTimeQuickDurations: some View {
        quickDurationControls(
            options: actualTimeQuickEntryMinutes,
            selectedMinutes: entryTotalMinutes,
            tint: .cyan,
            accessibilityContext: "actual time",
            onSelect: { setEntryTotal($0) }
        )
    }

    private var focusCountdownQuickDurations: some View {
        quickDurationControls(
            options: focusCountdownQuickEntryMinutes,
            selectedMinutes: focusCountdownMinutes,
            tint: .teal,
            accessibilityContext: "focus countdown",
            onSelect: { setFocusCountdownMinutes($0) }
        )
    }

    private func quickDurationControls(
        options: [Int],
        selectedMinutes: Int,
        tint: Color,
        accessibilityContext: String,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { minutes in
                quickDurationButton(
                    minutes,
                    isSelected: selectedMinutes == minutes,
                    tint: tint,
                    accessibilityContext: accessibilityContext,
                    onSelect: onSelect
                )
            }
        }
    }

    private var actualTimeActions: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                applyEntry()
            } label: {
                Label(
                    task.actualDurationMinutes == nil ? "Log time" : "Add time",
                    systemImage: "plus.circle.fill"
                )
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.cyan)
            .disabled(!canApplyEntry)
            .accessibilityLabel(compactApplyTitle)

            if task.actualDurationMinutes != nil {
                Button(action: onEditTotal) {
                    Label("Edit total", systemImage: "pencil")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.cyan)
                .accessibilityLabel("Edit total time spent")
            }
        }
    }

    private var startCountdownButton: some View {
        Button {
            startFocus(durationSeconds: TimeInterval(focusCountdownMinutes * 60))
        } label: {
            Label("Start countdown", systemImage: "timer")
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .tint(.teal)
        .accessibilityLabel(
            "Start \(TaskDetailHeaderBadgePresentation.durationText(for: focusCountdownMinutes)) focus countdown"
        )
    }

    private var startCountUpButton: some View {
        Button {
            startFocus(durationSeconds: 0)
        } label: {
            Label("Start count up", systemImage: "stopwatch")
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .tint(.teal)
        .accessibilityLabel("Start count up focus")
    }

    private func quickDurationButton(
        _ minutes: Int,
        isSelected: Bool,
        tint: Color,
        accessibilityContext: String,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        Button {
            onSelect(minutes)
        } label: {
            Text(RoutineTimeSpentFormatting.compactMinutesText(minutes))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? tint : .secondary)
                .frame(minWidth: 44)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? tint.opacity(0.18) : Color.secondary.opacity(0.10))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? tint.opacity(0.30) : Color.secondary.opacity(0.16), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Set \(accessibilityContext) to \(TaskDetailHeaderBadgePresentation.durationText(for: minutes))"
        )
    }

    private var displayText: String {
        task.actualDurationMinutes.map(TaskDetailHeaderBadgePresentation.durationText(for:)) ?? "Not logged"
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

        metrics.append(
            TaskDetailEffortMetric(
                title: "ACTUAL TIME",
                value: displayText,
                systemImage: task.actualDurationMinutes == nil ? "clock.badge" : "clock.fill",
                tint: .cyan,
                isMuted: task.actualDurationMinutes == nil
            )
        )

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

        return metrics
    }

    private var entryTotalMinutes: Int {
        TaskDetailTimeSpentPresentation.entryTotalMinutes(
            hours: entryHours,
            minutes: entryMinutes
        )
    }

    private var focusCountdownMinutes: Int {
        TaskDetailTimeSpentPresentation.resolvedFocusCountdownMinutes(
            savedMinutes: savedFocusCountdownMinutes
        )
    }

    private var previewMinutes: Int {
        TaskDetailTimeSpentPresentation.previewTotalMinutes(
            currentMinutes: task.actualDurationMinutes,
            entryMinutes: entryTotalMinutes
        )
    }

    private var compactApplyTitle: String {
        let verb = task.actualDurationMinutes == nil ? "Log" : "Add"
        return "\(verb) \(RoutineTimeSpentFormatting.compactMinutesText(entryTotalMinutes))"
    }

    private var shouldShowFocusTimerSection: Bool {
        task.focusModeEnabled || hasActiveFocusForTask
    }

    private var shouldShowFocusDetails: Bool {
        shouldShowFocusTimerSection
            && (
                !activeSleepSessions.isEmpty
                    || !focusSessions.filter { $0.taskID == task.id && $0.state != .abandoned }.isEmpty
                    || focusSessions.contains { $0.state == .active }
                    || blockingFocusTitle != nil
            )
    }

    private var canStartFocus: Bool {
        task.focusModeEnabled
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

    private var hasActiveFocusForTask: Bool {
        focusSessions.contains { session in
            session.taskID == task.id && session.state == .active
        }
    }

    private func setEntryTotal(_ minutes: Int, persist: Bool = true) {
        let clampedMinutes = TaskDetailTimeSpentPresentation.clampedMinutes(minutes)
        entryHours = clampedMinutes / 60
        entryMinutes = clampedMinutes % 60
        if persist {
            savedActualTimeEntryMinutes = clampedMinutes
        }
    }

    private func adjustEntry(by minutes: Int) {
        setEntryTotal(entryTotalMinutes + minutes)
    }

    private func setFocusCountdownMinutes(_ minutes: Int) {
        savedFocusCountdownMinutes = TaskDetailTimeSpentPresentation.clampedMinutes(minutes)
    }

    private func adjustFocusCountdown(by minutes: Int) {
        setFocusCountdownMinutes(focusCountdownMinutes + minutes)
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

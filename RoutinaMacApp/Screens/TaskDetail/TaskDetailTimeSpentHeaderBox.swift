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
    @AppStorage("macTaskDetailLastTimeEntryMinutes", store: SharedDefaults.app) private var savedEntryMinutes = 0
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
    let onCompletedFocusDuration: (TimeInterval) -> Void

    private let quickEntryMinutes = [25, 45, 60]
    private let stepMinutes = 5

    var body: some View {
        let isForcedExpanded = TaskDetailTimeSpentPresentation.shouldForceExpandSection(
            hasActiveFocus: hasActiveFocusForTask,
            showsFocusTimer: task.focusModeEnabled
        )
        let isContentExpanded = isExpanded || isForcedExpanded

        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    if isForcedExpanded {
                        isExpanded = true
                    } else {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .frame(width: 32, height: 32)
                        .routinaGlassPill(tint: .cyan, tintOpacity: 0.16)

                    effortSummary

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isContentExpanded ? 180 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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

            manualEntryContent

            if shouldShowFocusDetails {
                focusContent
            }
        }
    }

    private var manualEntryContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                durationStepper
                quickDurationControls
                entryActions
            }

            VStack(alignment: .leading, spacing: 10) {
                durationStepper
                quickDurationControls
                entryActions
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Add time")
    }

    private var focusContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .opacity(0.35)

            focusSessionContent
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
            blockingFocusTitle: blockingFocusTitle,
            onCompletedDuration: onCompletedFocusDuration
        )
    }

    private var durationStepper: some View {
        HStack(spacing: 8) {
            stepperButton(
                systemImage: "minus",
                accessibilityLabel: "Decrease time by \(stepMinutes) minutes",
                isDisabled: entryTotalMinutes <= TaskDetailTimeSpentPresentation.minimumMinutes
            ) {
                adjustEntry(by: -stepMinutes)
            }

            Text(compactEntryText)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(minWidth: 58)
                .accessibilityLabel(TaskDetailHeaderBadgePresentation.durationText(for: entryTotalMinutes))

            stepperButton(
                systemImage: "plus",
                accessibilityLabel: "Increase time by \(stepMinutes) minutes",
                isDisabled: entryTotalMinutes >= TaskDetailTimeSpentPresentation.maximumMinutes
            ) {
                adjustEntry(by: stepMinutes)
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

    private var quickDurationControls: some View {
        HStack(spacing: 6) {
            ForEach(quickEntryMinutes, id: \.self) { minutes in
                quickDurationButton(minutes)
            }
        }
    }

    private var entryActions: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                applyEntry()
            } label: {
                Label("Log", systemImage: "plus.circle.fill")
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.cyan)
            .disabled(!canApplyEntry)
            .accessibilityLabel(compactApplyTitle)

            if task.focusModeEnabled {
                Button {
                    startTimedFocus()
                } label: {
                    Label("Count down", systemImage: "timer")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.teal)
                .disabled(!canStartTimedFocus)
                .accessibilityLabel("Start \(TaskDetailHeaderBadgePresentation.durationText(for: entryTotalMinutes)) countdown focus")
            }

            if task.focusModeEnabled {
                Button {
                    startCountUpFocus()
                } label: {
                    Label("Count up", systemImage: "stopwatch")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.teal)
                .disabled(!canStartFocus)
                .accessibilityLabel("Start count up focus")
            }
        }
    }

    private func quickDurationButton(_ minutes: Int) -> some View {
        let isSelected = entryTotalMinutes == minutes
        let tint = Color.cyan

        return Button {
            setEntryTotal(minutes)
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
        .accessibilityLabel("Set time entry to \(TaskDetailHeaderBadgePresentation.durationText(for: minutes))")
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
                title: "TIME",
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

    private var previewMinutes: Int {
        TaskDetailTimeSpentPresentation.previewTotalMinutes(
            currentMinutes: task.actualDurationMinutes,
            entryMinutes: entryTotalMinutes
        )
    }

    private var compactEntryText: String {
        RoutineTimeSpentFormatting.compactMinutesText(entryTotalMinutes)
    }

    private var compactApplyTitle: String {
        let verb = task.actualDurationMinutes == nil ? "Log" : "Add"
        return "\(verb) \(RoutineTimeSpentFormatting.compactMinutesText(entryTotalMinutes))"
    }

    private var shouldShowFocusDetails: Bool {
        task.focusModeEnabled
            && (
                !activeSleepSessions.isEmpty
                    || !focusSessions.filter { $0.taskID == task.id && $0.state != .abandoned }.isEmpty
                    || focusSessions.contains { $0.state == .active }
                    || blockingFocusTitle != nil
            )
    }

    private var canStartTimedFocus: Bool {
        canApplyEntry && canStartFocus
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
            savedEntryMinutes = clampedMinutes
        }
    }

    private func adjustEntry(by minutes: Int) {
        setEntryTotal(entryTotalMinutes + minutes)
    }

    private func resetEntry() {
        let storedMinutes = TaskDetailTimeSpentPresentation.clampedMinutes(savedEntryMinutes)
        let defaultMinutes = savedEntryMinutes > 0
            ? storedMinutes
            : TaskDetailTimeSpentPresentation.defaultAdditionalEntryMinutes(
                currentMinutes: task.actualDurationMinutes,
                estimatedMinutes: task.estimatedDurationMinutes
            )
        setEntryTotal(defaultMinutes, persist: false)
    }

    private func applyEntry() {
        guard canApplyEntry else { return }
        savedEntryMinutes = entryTotalMinutes
        onApplyMinutes(previewMinutes)
    }

    private func startTimedFocus() {
        guard canStartTimedFocus else { return }
        savedEntryMinutes = entryTotalMinutes
        startFocus(durationSeconds: TimeInterval(entryTotalMinutes * 60))
    }

    private func startCountUpFocus() {
        guard canStartFocus else { return }
        startFocus(durationSeconds: 0)
    }

    private func startFocus(durationSeconds: TimeInterval) {
        do {
            _ = try FocusSessionSupport.startTaskFocus(
                task: task,
                plannedDurationSeconds: durationSeconds,
                context: modelContext,
                calendar: calendar
            )
        } catch {
            NSLog("Failed to start task focus from time section: \(error.localizedDescription)")
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

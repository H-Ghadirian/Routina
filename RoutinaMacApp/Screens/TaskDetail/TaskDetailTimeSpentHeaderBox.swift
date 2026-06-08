import SwiftData
import SwiftUI

struct TaskDetailTimeSpentHeaderBox: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @AppStorage("macTaskDetailLastTimeEntryMinutes", store: SharedDefaults.app) private var savedEntryMinutes = 0

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
                    Image(systemName: task.actualDurationMinutes == nil ? "clock.badge" : "clock.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .frame(width: 32, height: 32)
                        .routinaGlassPill(tint: .cyan, tintOpacity: 0.16)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("TIME")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(displayText)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(task.actualDurationMinutes == nil ? .secondary : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

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

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .opacity(0.35)

            if task.focusModeEnabled {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        manualEntryContent
                            .frame(maxWidth: 720, alignment: .leading)

                        Divider()
                            .opacity(0.35)

                        focusSessionContent
                            .frame(maxWidth: 620, alignment: .leading)
                    }
                    .frame(maxWidth: 1_380, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        manualEntryContent
                        focusContent
                    }
                }
            } else {
                manualEntryContent
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
            blockingFocusTitle: blockingFocusTitle,
            onCompletedDuration: onCompletedFocusDuration
        )
    }

    private var durationStepper: some View {
        HStack(spacing: 8) {
            Button {
                adjustEntry(by: -stepMinutes)
            } label: {
                Label("Decrease time", systemImage: "minus")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(entryTotalMinutes <= TaskDetailTimeSpentPresentation.minimumMinutes)
            .accessibilityLabel("Decrease time by \(stepMinutes) minutes")

            Text(compactEntryText)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(minWidth: 58)
                .accessibilityLabel(TaskDetailHeaderBadgePresentation.durationText(for: entryTotalMinutes))

            Button {
                adjustEntry(by: stepMinutes)
            } label: {
                Label("Increase time", systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(entryTotalMinutes >= TaskDetailTimeSpentPresentation.maximumMinutes)
            .accessibilityLabel("Increase time by \(stepMinutes) minutes")
        }
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
                    Label("Focus", systemImage: "timer")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.teal)
                .disabled(!canStartTimedFocus)
                .accessibilityLabel("Start \(TaskDetailHeaderBadgePresentation.durationText(for: entryTotalMinutes)) focus")
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

    private var canStartTimedFocus: Bool {
        canApplyEntry
            && blockingFocusTitle == nil
            && !focusSessions.contains { $0.state == .active }
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
        do {
            _ = try FocusSessionSupport.startTaskFocus(
                task: task,
                plannedDurationSeconds: TimeInterval(entryTotalMinutes * 60),
                context: modelContext,
                calendar: calendar
            )
        } catch {
            NSLog("Failed to start task focus from time section: \(error.localizedDescription)")
        }
    }
}

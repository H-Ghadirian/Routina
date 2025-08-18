import SwiftUI

struct TaskDetailTimeSpentHeaderBox: View {
    let task: RoutineTask
    let focusSessions: [FocusSession]
    let allTasks: [RoutineTask]
    let resetToken: Int
    @Binding var isExpanded: Bool
    @Binding var entryHours: Int
    @Binding var entryMinutes: Int
    let onApplyMinutes: (Int) -> Void
    let onCompletedFocusDuration: (TimeInterval) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TIME")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(displayText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(task.actualDurationMinutes == nil ? .secondary : .primary)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent
            }
        }
        .frame(maxWidth: .infinity, minHeight: isExpanded ? 120 : nil, alignment: .topLeading)
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

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 10) {
                    entryControls
                    entryActions
                }

                VStack(alignment: .leading, spacing: 10) {
                    entryControls
                    entryActions
                }
            }

            if task.focusModeEnabled {
                Divider()
                    .opacity(0.35)

                FocusSessionCard(
                    task: task,
                    sessions: focusSessions,
                    allTasks: allTasks,
                    isEmbedded: true,
                    onCompletedDuration: onCompletedFocusDuration
                )
            }
        }
    }

    private var entryControls: some View {
        HStack(alignment: .bottom, spacing: 8) {
            timeSpentNumberField("Hours", value: $entryHours, range: 0...24)
            timeSpentNumberField("Minutes", value: $entryMinutes, range: 0...59)

            HStack(spacing: 6) {
                ForEach([15, 30, 60], id: \.self) { minutes in
                    Button("+\(RoutineTimeSpentFormatting.compactMinutesText(minutes))") {
                        setEntryTotal(minutes)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var entryActions: some View {
        HStack(alignment: .center, spacing: 10) {
            Label(previewText, systemImage: "equal.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button {
                applyEntry()
            } label: {
                Label(applyTitle, systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.cyan)
            .disabled(!canApplyEntry)
        }
    }

    private func timeSpentNumberField(
        _ label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(label, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 64)
                .onChange(of: value.wrappedValue) { _, newValue in
                    value.wrappedValue = min(max(newValue, range.lowerBound), range.upperBound)
                }
        }
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

    private var previewText: String {
        TaskDetailTimeSpentPresentation.previewText(
            currentMinutes: task.actualDurationMinutes,
            entryMinutes: entryTotalMinutes
        )
    }

    private var applyTitle: String {
        TaskDetailTimeSpentPresentation.applyTitle(entryMinutes: entryTotalMinutes)
    }

    private var canApplyEntry: Bool {
        TaskDetailTimeSpentPresentation.canApplyEntry(
            currentMinutes: task.actualDurationMinutes,
            entryMinutes: entryTotalMinutes
        )
    }

    private func setEntryTotal(_ minutes: Int) {
        let clampedMinutes = TaskDetailTimeSpentPresentation.clampedMinutes(minutes)
        entryHours = clampedMinutes / 60
        entryMinutes = clampedMinutes % 60
    }

    private func resetEntry() {
        setEntryTotal(
            TaskDetailTimeSpentPresentation.defaultAdditionalEntryMinutes(
                currentMinutes: task.actualDurationMinutes,
                estimatedMinutes: task.estimatedDurationMinutes
            )
        )
    }

    private func applyEntry() {
        guard canApplyEntry else { return }
        onApplyMinutes(previewMinutes)
        setEntryTotal(TaskDetailTimeSpentPresentation.fallbackEntryMinutes)
    }
}

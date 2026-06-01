import SwiftUI

struct TaskDetailHistorySectionView<RowContent: View>: View {
    let logs: [RoutineLog]
    let changes: [RoutineTaskChangeLogEntry]
    @Binding var isExpanded: Bool
    @Binding var isShowingAllLogs: Bool
    let createdAtBadgeValue: String?
    let showPersianDates: Bool
    let background: Color
    let stroke: Color
    let relatedTaskName: (RoutineTaskChangeLogEntry) -> String
    let rowContent: (Int, RoutineLog, [RoutineLog]) -> RowContent

    @State private var isShowingAllChanges = false

    init(
        logs: [RoutineLog],
        changes: [RoutineTaskChangeLogEntry],
        isExpanded: Binding<Bool>,
        isShowingAllLogs: Binding<Bool>,
        createdAtBadgeValue: String?,
        showPersianDates: Bool,
        background: Color,
        stroke: Color,
        relatedTaskName: @escaping (RoutineTaskChangeLogEntry) -> String,
        @ViewBuilder rowContent: @escaping (Int, RoutineLog, [RoutineLog]) -> RowContent
    ) {
        self.logs = logs
        self.changes = changes
        self._isExpanded = isExpanded
        self._isShowingAllLogs = isShowingAllLogs
        self.createdAtBadgeValue = createdAtBadgeValue
        self.showPersianDates = showPersianDates
        self.background = background
        self.stroke = stroke
        self.relatedTaskName = relatedTaskName
        self.rowContent = rowContent
    }

    private var historyCount: Int {
        logs.count + changes.count
    }

    private var displayedLogs: [RoutineLog] {
        TaskDetailLogPresentation.displayedLogs(logs, showingAll: isShowingAllLogs)
    }

    private var displayedChanges: [RoutineTaskChangeLogEntry] {
        TaskDetailLogPresentation.displayedTaskChanges(
            changes,
            showingAll: isShowingAllChanges
        )
    }

    private var hiddenLogCount: Int {
        max(0, logs.count - displayedLogs.count)
    }

    private var hiddenChangeCount: Int {
        max(0, changes.count - displayedChanges.count)
    }

    private var shouldShowAllLogsControl: Bool {
        logs.count > displayedLogs.count || isShowingAllLogs
    }

    private var shouldShowAllChangesControl: Bool {
        changes.count > displayedChanges.count || isShowingAllChanges
    }

    var body: some View {
        TaskDetailSectionCardView(background: background, stroke: stroke) {
            VStack(alignment: .leading, spacing: 10) {
                TaskDetailCollapsibleSectionHeaderView(
                    title: "History",
                    count: historyCount,
                    isExpanded: isExpanded,
                    onToggle: { isExpanded.toggle() }
                )

                if let createdAtBadgeValue {
                    Label("Created \(createdAtBadgeValue)", systemImage: "calendar.badge.plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if isExpanded {
                    if logs.isEmpty && changes.isEmpty {
                        Text("No history yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        historyContent
                    }
                }
            }
        }
        .onChange(of: logs.map(\.id)) { _, _ in
            isShowingAllLogs = false
        }
        .onChange(of: changes.map(\.id)) { _, _ in
            isShowingAllChanges = false
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        if !logs.isEmpty {
            historyGroupTitle("Activity", count: logs.count)

            ForEach(Array(displayedLogs.enumerated()), id: \.element.id) { index, log in
                rowContent(index, log, displayedLogs)

                if index < displayedLogs.count - 1 {
                    Divider()
                }
            }

            if shouldShowAllLogsControl {
                showAllLogsControl
            }
        }

        if !logs.isEmpty && !changes.isEmpty {
            Divider()
                .padding(.vertical, 2)
        }

        if !changes.isEmpty {
            historyGroupTitle("Changes", count: changes.count)

            ForEach(Array(displayedChanges.enumerated()), id: \.element.id) { index, change in
                taskChangeRow(change)

                if index < displayedChanges.count - 1 {
                    Divider()
                }
            }

            if shouldShowAllChangesControl {
                Divider()
                showAllChangesControl
            }
        }
    }

    private func historyGroupTitle(_ title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(count.formatted())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.14))
                )
        }
        .padding(.top, 2)
    }

    private var showAllLogsControl: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                isShowingAllLogs.toggle()
            }
        } label: {
            Label(
                isShowingAllLogs ? "Show fewer activity entries" : "Show all activity",
                systemImage: isShowingAllLogs ? "chevron.up.circle" : "chevron.down.circle"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityHint(isShowingAllLogs ? "Shows only recent activity" : "Shows \(hiddenLogCount) older activity entries")
    }

    private var showAllChangesControl: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                isShowingAllChanges.toggle()
            }
        } label: {
            Label(
                isShowingAllChanges ? "Show fewer changes" : "Show all changes",
                systemImage: isShowingAllChanges ? "chevron.up.circle" : "chevron.down.circle"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityHint(isShowingAllChanges ? "Shows only recent changes" : "Shows \(hiddenChangeCount) older changes")
    }

    private func taskChangeRow(_ change: RoutineTaskChangeLogEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: TaskDetailLogPresentation.taskChangeSystemImage(for: change))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(TaskDetailLogPresentation.taskChangeTitle(for: change, relatedTaskName: relatedTaskName(change)))
                    .font(.subheadline.weight(.medium))
                Text(TaskDetailLogPresentation.timestampText(change.timestamp, showPersianDates: showPersianDates))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 7)
    }
}

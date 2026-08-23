import SwiftUI

enum TaskDetailHistorySectionPresentationStyle {
    case standard
    case compactMobile
}

struct TaskDetailHistorySectionView<RowContent: View>: View {
    let logs: [RoutineLog]
    let changes: [RoutineTaskChangeLogEntry]
    @Binding var isExpanded: Bool
    @Binding var isShowingAllLogs: Bool
    let createdAtBadgeValue: String?
    let showPersianDates: Bool
    let background: Color
    let stroke: Color
    let presentationStyle: TaskDetailHistorySectionPresentationStyle
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
        presentationStyle: TaskDetailHistorySectionPresentationStyle = .standard,
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
        self.presentationStyle = presentationStyle
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
        Group {
            if presentationStyle == .compactMobile {
                historyCardContent
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(background)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(stroke, lineWidth: 1)
                    )
            } else {
                TaskDetailSectionCardView(background: background, stroke: stroke) {
                    historyCardContent
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

    private var historyCardContent: some View {
        VStack(alignment: .leading, spacing: presentationStyle == .compactMobile ? 8 : 10) {
            TaskDetailCollapsibleSectionHeaderView(
                title: "History",
                count: historyCount,
                isExpanded: isExpanded,
                onToggle: { isExpanded.toggle() }
            )

            if let createdAtBadgeValue {
                createdBadge(createdAtBadgeValue)
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

    @ViewBuilder
    private var historyContent: some View {
        if !logs.isEmpty {
            historyGroupTitle("Activity", count: logs.count, systemImage: "clock")

            ForEach(Array(displayedLogs.enumerated()), id: \.element.id) { index, log in
                rowContent(index, log, displayedLogs)

                if index < displayedLogs.count - 1 {
                    historyDivider
                }
            }

            if shouldShowAllLogsControl {
                showAllLogsControl
            }
        }

        if !logs.isEmpty && !changes.isEmpty {
            historyGroupDivider
        }

        if !changes.isEmpty {
            historyGroupTitle("Changes", count: changes.count, systemImage: "pencil")

            ForEach(Array(displayedChanges.enumerated()), id: \.element.id) { index, change in
                taskChangeRow(change)

                if index < displayedChanges.count - 1 {
                    historyDivider
                }
            }

            if shouldShowAllChangesControl {
                historyDivider
                showAllChangesControl
            }
        }
    }

    @ViewBuilder
    private func createdBadge(_ value: String) -> some View {
        if presentationStyle == .compactMobile {
            Label("Created \(value)", systemImage: "calendar.badge.plus")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(.vertical, 2)
        } else {
            Label("Created \(value)", systemImage: "calendar.badge.plus")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func historyGroupTitle(_ title: String, count: Int, systemImage: String) -> some View {
        if presentationStyle == .compactMobile {
            HStack(spacing: 8) {
                Label(title, systemImage: systemImage)
                Spacer(minLength: 8)
                Text(count.formatted())
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 5)
            .padding(.bottom, 1)
        } else {
            HStack(spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
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
            .padding(.top, 4)
            .padding(.bottom, 2)
        }
    }

    @ViewBuilder
    private var historyDivider: some View {
        if presentationStyle != .compactMobile {
            Divider()
                .padding(.leading, 40)
                .opacity(0.65)
        }
    }

    private var historyGroupDivider: some View {
        Divider()
            .padding(.vertical, 6)
            .opacity(0.7)
    }

    @ViewBuilder
    private var showAllLogsControl: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                isShowingAllLogs.toggle()
            }
        } label: {
            if presentationStyle == .compactMobile {
                HStack(spacing: 8) {
                    Text(isShowingAllLogs ? "Show recent activity" : "Show \(hiddenLogCount) older entries")
                    Image(systemName: isShowingAllLogs ? "chevron.up" : "chevron.down")
                }
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            } else {
                Label(
                    isShowingAllLogs ? "Show fewer activity entries" : "Show all activity",
                    systemImage: isShowingAllLogs ? "chevron.up.circle" : "chevron.down.circle"
                )
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                )
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
        .accessibilityHint(isShowingAllLogs ? "Shows only recent activity" : "Shows \(hiddenLogCount) older activity entries")
    }

    @ViewBuilder
    private var showAllChangesControl: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                isShowingAllChanges.toggle()
            }
        } label: {
            if presentationStyle == .compactMobile {
                HStack(spacing: 8) {
                    Text(isShowingAllChanges ? "Show recent changes" : "Show \(hiddenChangeCount) older changes")
                    Image(systemName: isShowingAllChanges ? "chevron.up" : "chevron.down")
                }
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            } else {
                Label(
                    isShowingAllChanges ? "Show fewer changes" : "Show all changes",
                    systemImage: isShowingAllChanges ? "chevron.up.circle" : "chevron.down.circle"
                )
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                )
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
        .accessibilityHint(isShowingAllChanges ? "Shows only recent changes" : "Shows \(hiddenChangeCount) older changes")
    }

    @ViewBuilder
    private func taskChangeRow(_ change: RoutineTaskChangeLogEntry) -> some View {
        let row = HStack(alignment: .top, spacing: 10) {
            TaskDetailHistoryMarker(
                systemImage: TaskDetailLogPresentation.taskChangeSystemImage(for: change),
                tint: .secondary
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(TaskDetailLogPresentation.taskChangeTitle(for: change, relatedTaskName: relatedTaskName(change)))
                    .font(.subheadline.weight(.semibold))

                Text(change.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let supplementaryDateText = PersianDateDisplay.supplementaryText(
                    for: change.timestamp,
                    enabled: showPersianDates
                ) {
                    Text(supplementaryDateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if presentationStyle == .compactMobile {
            row
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.055))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
                )
        } else {
            row.padding(.vertical, 7)
        }
    }
}

struct TaskDetailHistoryMarker: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.16))

            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }
}

struct TaskDetailHistoryStatusBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.13))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
    }
}

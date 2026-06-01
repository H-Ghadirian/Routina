import SwiftUI

struct TaskDetailTaskChangesSectionView: View {
    let changes: [RoutineTaskChangeLogEntry]
    @Binding var isExpanded: Bool
    let showPersianDates: Bool
    let background: Color
    let stroke: Color
    let relatedTaskName: (RoutineTaskChangeLogEntry) -> String

    @State private var isShowingAllChanges = false

    private var displayedChanges: [RoutineTaskChangeLogEntry] {
        TaskDetailLogPresentation.displayedTaskChanges(
            changes,
            showingAll: isShowingAllChanges
        )
    }

    private var hiddenChangeCount: Int {
        max(0, changes.count - displayedChanges.count)
    }

    private var shouldShowAllControl: Bool {
        changes.count > displayedChanges.count || isShowingAllChanges
    }

    var body: some View {
        TaskDetailSectionCardView(background: background, stroke: stroke) {
            VStack(alignment: .leading, spacing: 8) {
                TaskDetailCollapsibleSectionHeaderView(
                    title: "Task Changes",
                    count: changes.count,
                    isExpanded: isExpanded,
                    onToggle: { isExpanded.toggle() }
                )

                if isExpanded {
                    if changes.isEmpty {
                        Text("No changes yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(displayedChanges.enumerated()), id: \.element.id) { index, change in
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

                            if index < displayedChanges.count - 1 {
                                Divider()
                            }
                        }

                        if shouldShowAllControl {
                            Divider()
                            showAllControl
                        }
                    }
                }
            }
        }
        .onChange(of: changes.map(\.id)) { _, _ in
            isShowingAllChanges = false
        }
    }

    private var showAllControl: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                isShowingAllChanges.toggle()
            }
        } label: {
            Label(
                isShowingAllChanges ? "Show less" : "Show all",
                systemImage: isShowingAllChanges ? "chevron.up.circle" : "chevron.down.circle"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityHint(showAllAccessibilityHint)
    }

    private var showAllAccessibilityHint: String {
        if isShowingAllChanges {
            return "Shows only the latest changes"
        }
        return "Shows \(hiddenChangeCount) older changes"
    }
}

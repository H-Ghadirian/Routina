import SwiftUI

struct TaskDetailTaskChangesSectionView: View {
    let changes: [RoutineTaskChangeLogEntry]
    @Binding var isExpanded: Bool
    let showPersianDates: Bool
    let background: Color
    let stroke: Color
    let relatedTaskName: (RoutineTaskChangeLogEntry) -> String

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
                        ForEach(Array(changes.prefix(12).enumerated()), id: \.element.id) { index, change in
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

                            if index < min(changes.count, 12) - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}

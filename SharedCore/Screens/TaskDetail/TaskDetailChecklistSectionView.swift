import SwiftUI

struct TaskDetailChecklistSectionView: View {
    let task: RoutineTask
    let selectedDate: Date
    let isDoneToday: Bool
    let background: Color
    let stroke: Color
    let isMarkedDone: (RoutineChecklistItem) -> Bool
    let onToggleCompletion: (UUID) -> Void
    let onMarkPurchased: (UUID) -> Void

    private var sortedItems: [RoutineChecklistItem] {
        TaskDetailChecklistPresentation.sortedItems(for: task)
    }

    var body: some View {
        TaskDetailSectionCardView(background: background, stroke: stroke) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Checklist Items")
                    .font(.headline)

                if task.checklistItems.isEmpty {
                    Text("No checklist items yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sortedItems, id: \.id) { item in
                        checklistRow(for: item)

                        if item.id != sortedItems.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func checklistRow(for item: RoutineChecklistItem) -> some View {
        if task.isChecklistCompletionRoutine {
            completionChecklistRow(for: item)
        } else {
            dueChecklistRow(for: item)
        }
    }

    private func completionChecklistRow(for item: RoutineChecklistItem) -> some View {
        let isDone = isMarkedDone(item)
        let isInteractive = TaskDetailChecklistPresentation.canToggleItem(
            item,
            task: task,
            selectedDate: selectedDate,
            isDoneToday: isDoneToday
        )

        return Button {
            onToggleCompletion(item.id)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isDone ? .green : TaskDetailChecklistPresentation.completionControlColor(isInteractive: isInteractive))
                    .frame(width: 24, height: 24)

                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDone ? .secondary : .primary)
                    .strikethrough(isDone, color: .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .accessibilityLabel(item.title)
        .accessibilityValue(isDone ? "Completed" : "Not completed")
    }

    private func dueChecklistRow(for item: RoutineChecklistItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text(TaskDetailChecklistPresentation.statusText(
                    for: item,
                    task: task,
                    isMarkedDone: isMarkedDone(item)
                ))
                .font(.caption)
                .foregroundStyle(TaskDetailChecklistPresentation.statusColor(for: item, task: task, isMarkedDone: isMarkedDone(item)))
            }

            Spacer(minLength: 0)

            Button("Bought") {
                onMarkPurchased(item.id)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(task.isArchived() || !Calendar.current.isDateInToday(selectedDate))
        }
    }
}

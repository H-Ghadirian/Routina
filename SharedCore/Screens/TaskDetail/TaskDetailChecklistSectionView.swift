import SwiftUI

struct TaskDetailChecklistSectionView: View {
    let task: RoutineTask
    let selectedDate: Date
    let isDoneToday: Bool
    let background: Color
    let stroke: Color
    @Binding var newItemTitle: String
    @Binding var newItemIntervalDays: Int
    let isAddItemDisabled: Bool
    let isMarkedDone: (RoutineChecklistItem) -> Bool
    let onAddItem: () -> Void
    let onToggleCompletion: (UUID) -> Void
    let onMarkPurchased: (UUID) -> Void

    @State private var isShowingDoneItems = false

    private var sortedItems: [RoutineChecklistItem] {
        TaskDetailChecklistPresentation.sortedItems(for: task)
    }

    private var visibleItems: [RoutineChecklistItem] {
        TaskDetailChecklistPresentation.visibleItems(
            sortedItems,
            showDone: isShowingDoneItems,
            isMarkedDone: isMarkedDone
        )
    }

    private var doneItemCount: Int {
        sortedItems.filter(isMarkedDone).count
    }

    private var hiddenDoneItemCount: Int {
        max(0, sortedItems.count - visibleItems.count)
    }

    private var shouldShowDoneToggle: Bool {
        doneItemCount > 0
    }

    var body: some View {
        TaskDetailSectionCardView(background: background, stroke: stroke) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Checklist Items")
                    .font(.headline)

                checklistComposer

                if shouldShowDoneToggle {
                    doneVisibilityControl
                }

                if task.checklistItems.isEmpty {
                    Text("No checklist items yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if visibleItems.isEmpty {
                    Text("All checklist items are done")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(visibleItems, id: \.id) { item in
                        checklistRow(for: item)

                        if item.id != visibleItems.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .onChange(of: task.id) { _, _ in
            isShowingDoneItems = false
        }
    }

    private var checklistComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    checklistTextField
                    addItemButton
                }

                VStack(alignment: .leading, spacing: 8) {
                    checklistTextField
                    HStack {
                        Spacer()
                        addItemButton
                    }
                }
            }

            if task.isChecklistDriven {
                Stepper(value: $newItemIntervalDays, in: 1...365) {
                    Text(TaskFormPresentation.checklistIntervalLabel(for: newItemIntervalDays))
                        .font(.caption)
                }
            }
        }
    }

    private var checklistTextField: some View {
        TextField("Add checklist item", text: $newItemTitle)
            .textFieldStyle(.roundedBorder)
            .onSubmit(onAddItem)
    }

    private var addItemButton: some View {
        Button {
            onAddItem()
        } label: {
            Label("Add Item", systemImage: "plus.circle.fill")
        }
        .buttonStyle(.borderedProminent)
        .disabled(isAddItemDisabled)
    }

    private var doneVisibilityControl: some View {
        HStack(spacing: 8) {
            Label(doneSummaryText, systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isShowingDoneItems.toggle()
                }
            } label: {
                Label(isShowingDoneItems ? "Hide done" : "Show done", systemImage: isShowingDoneItems ? "eye.slash" : "eye")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.07)
    }

    private var doneSummaryText: String {
        if isShowingDoneItems {
            return "\(doneItemCount) done shown"
        }
        return "\(hiddenDoneItemCount) done hidden"
    }

    @ViewBuilder
    private func checklistRow(for item: RoutineChecklistItem) -> some View {
        if task.isChecklistDriven {
            dueChecklistRow(for: item)
        } else {
            completionChecklistRow(for: item)
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

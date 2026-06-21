import SwiftUI

struct TaskDetailChecklistSectionView: View {
    let task: RoutineTask
    let selectedDate: Date
    let isSelectedDateDone: Bool
    let background: Color
    let stroke: Color
    @Binding var newItemTitle: String
    @Binding var newItemIntervalDays: Int
    let isAddItemDisabled: Bool
    var isComposerInitiallyExpanded = false
    let isMarkedDone: (RoutineChecklistItem) -> Bool
    let onAddItem: () -> Void
    let onToggleCompletion: (UUID) -> Void
    let onToggleRunoutDone: (UUID) -> Void
    let onExtend: (UUID) -> Void
    let onUpdateItem: (UUID, String, Int) -> Void

    @State private var isShowingDoneItems = false
    @State private var isChecklistComposerExpanded = false
    @State private var editingChecklistItemID: UUID?
    @State private var editingChecklistItemTitle = ""
    @State private var editingChecklistItemIntervalDays = 3

    private var sortedItems: [RoutineChecklistItem] {
        TaskDetailChecklistPresentation.sortedItems(for: task)
    }

    private var visibleItems: [RoutineChecklistItem] {
        if !TaskDetailChecklistPresentation.usesDoneVisibilityFilter(for: task) {
            return sortedItems
        }
        return TaskDetailChecklistPresentation.visibleItems(
            sortedItems,
            showDone: isShowingDoneItems,
            isMarkedDone: isMarkedDone
        )
    }

    private var doneItemCount: Int {
        guard TaskDetailChecklistPresentation.usesDoneVisibilityFilter(for: task) else { return 0 }
        return sortedItems.filter(isMarkedDone).count
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
                checklistHeader

                if isChecklistComposerExpanded {
                    checklistComposer
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

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
            isChecklistComposerExpanded = false
            cancelChecklistItemEditing()
        }
        .onAppear {
            if isComposerInitiallyExpanded {
                isChecklistComposerExpanded = true
            }
        }
        .onChange(of: isComposerInitiallyExpanded) { _, shouldExpand in
            if shouldExpand {
                isChecklistComposerExpanded = true
            }
        }
    }

    private var checklistHeader: some View {
        HStack(spacing: 8) {
            Text("Checklist Items")
                .font(.headline)

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isChecklistComposerExpanded.toggle()
                }
            } label: {
                Image(systemName: isChecklistComposerExpanded ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel(isChecklistComposerExpanded ? "Hide add checklist item" : "Add checklist item")

            Spacer(minLength: 0)
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
        if editingChecklistItemID == item.id {
            checklistItemEditor(for: item)
        } else if task.isChecklistDriven {
            dueChecklistRow(for: item)
        } else {
            completionChecklistRow(for: item)
        }
    }

    private func checklistItemEditor(for item: RoutineChecklistItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Checklist item", text: $editingChecklistItemTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit { saveChecklistItemEditing(item.id) }

            Stepper(value: $editingChecklistItemIntervalDays, in: 1...365) {
                Text(TaskFormPresentation.checklistIntervalLabel(for: editingChecklistItemIntervalDays))
                    .font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    cancelChecklistItemEditing()
                }
                .controlSize(.small)

                Button("Save") {
                    saveChecklistItemEditing(item.id)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(RoutineChecklistItem.normalizedTitle(editingChecklistItemTitle) == nil)
            }
        }
        .padding(.vertical, 4)
    }

    private func completionChecklistRow(for item: RoutineChecklistItem) -> some View {
        let isDone = isMarkedDone(item)
        let isInteractive = TaskDetailChecklistPresentation.canToggleItem(
            item,
            task: task,
            selectedDate: selectedDate,
            isSelectedDateCompleted: isSelectedDateDone
        )

        return HStack(alignment: .center, spacing: 12) {
            Button {
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

            editChecklistItemButton(for: item)
        }
    }

    private func dueChecklistRow(for item: RoutineChecklistItem) -> some View {
        let isDone = isMarkedDone(item)

        return HStack(alignment: .center, spacing: 12) {
            Button {
                onToggleRunoutDone(item.id)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: isDone ? "checkmark.square.fill" : "square")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isDone ? .green : TaskDetailChecklistPresentation.completionControlColor(isInteractive: isRunoutCheckboxInteractive))
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isDone ? .secondary : .primary)
                            .strikethrough(isDone, color: .secondary)
                        Text(TaskDetailChecklistPresentation.statusText(
                            for: item,
                            task: task,
                            isMarkedDone: isDone
                        ))
                        .font(.caption)
                        .foregroundStyle(TaskDetailChecklistPresentation.statusColor(for: item, task: task, isMarkedDone: isDone))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isRunoutCheckboxInteractive && !isDone)
            .accessibilityLabel(item.title)
            .accessibilityValue(isDone ? "Done today" : "Not done today")

            Spacer(minLength: 0)

            Button("Extend") {
                onExtend(item.id)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isDone || task.isArchived() || !Calendar.current.isDateInToday(selectedDate))

            editChecklistItemButton(for: item)
        }
    }

    private func editChecklistItemButton(for item: RoutineChecklistItem) -> some View {
        Button {
            beginChecklistItemEditing(item)
        } label: {
            Image(systemName: "pencil.circle")
                .font(.title3.weight(.semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel("Edit \(item.title)")
    }

    private var isRunoutCheckboxInteractive: Bool {
        !task.isArchived() && Calendar.current.isDateInToday(selectedDate)
    }

    private func beginChecklistItemEditing(_ item: RoutineChecklistItem) {
        editingChecklistItemID = item.id
        editingChecklistItemTitle = item.title
        editingChecklistItemIntervalDays = RoutineChecklistItem.clampedIntervalDays(item.intervalDays)
    }

    private func cancelChecklistItemEditing() {
        editingChecklistItemID = nil
        editingChecklistItemTitle = ""
        editingChecklistItemIntervalDays = 3
    }

    private func saveChecklistItemEditing(_ itemID: UUID) {
        guard RoutineChecklistItem.normalizedTitle(editingChecklistItemTitle) != nil else { return }
        onUpdateItem(
            itemID,
            editingChecklistItemTitle,
            editingChecklistItemIntervalDays
        )
        cancelChecklistItemEditing()
    }
}

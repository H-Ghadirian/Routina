import SwiftUI

struct HomeMacTodoBoardBacklogListView: View {
    let tasks: [HomeFeature.RoutineDisplay]
    let isCompactLayout: Bool
    let selectedTaskID: UUID?
    let availableBacklogs: [BoardBacklog]
    let availableSprints: [BoardSprint]
    let activeSprints: [BoardSprint]
    let onSelectTask: (UUID) -> Void
    let onOpenTask: (UUID) -> Void
    let onMoveTask: (UUID, TodoState) -> Void
    let onAssignTaskToBacklog: (UUID, UUID?) -> Void
    let onAssignTasksToBacklog: ([UUID], UUID?) -> Void
    let onAssignTaskToSprint: (UUID, UUID?) -> Void
    let onAssignTasksToSprint: ([UUID], UUID?) -> Void
    @Binding var selectedTaskIDs: Set<UUID>

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(tasks) { task in
                        row(task)
                        Divider()
                            .padding(.leading, isCompactLayout ? 12 : 16)
                    }
                } header: {
                    header
                }
            }
            .padding(.horizontal, isCompactLayout ? 12 : 20)
            .padding(.vertical, isCompactLayout ? 12 : 18)
        }
        .onChange(of: tasks.map(\.id)) { _, visibleTaskIDs in
            selectedTaskIDs.formIntersection(Set(visibleTaskIDs))
        }
    }

    private var header: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 0) {
            GridRow {
                selectionControl
                    .frame(width: 28, alignment: .leading)
                Text("Task")
                    .gridCellColumns(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Status")
                Text("Due")
                Text("List")
                Text("")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, isCompactLayout ? 12 : 16)
            .padding(.vertical, 9)
        }
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func row(_ task: HomeFeature.RoutineDisplay) -> some View {
        let isSelectedForBulkAction = selectedTaskIDs.contains(task.id)

        return Grid(horizontalSpacing: 12, verticalSpacing: 0) {
            GridRow {
                Button {
                    toggleSelection(for: task.id)
                } label: {
                    Image(systemName: isSelectedForBulkAction ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isSelectedForBulkAction ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelectedForBulkAction ? "Deselect \(task.name)" : "Select \(task.name)")
                .frame(width: 28, alignment: .leading)

                taskSummary(task)

                statusBadge(for: task)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(task.dueDate.map(HomeMacTodoBoardFormatting.dueLabel(for:)) ?? "No due date")
                    .font(.caption)
                    .foregroundStyle(task.dueDate == nil ? .tertiary : .secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(task.assignedSprintTitle ?? task.assignedBacklogTitle ?? "Backlog")
                    .font(.caption)
                    .foregroundStyle(task.assignedSprintTitle == nil && task.assignedBacklogTitle == nil ? .tertiary : .secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    taskMenuItems(for: task)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, isCompactLayout ? 12 : 16)
            .padding(.vertical, isCompactLayout ? 9 : 11)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(rowBackground(isSelectedForBulkAction: isSelectedForBulkAction, taskID: task.id))
            )
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                onOpenTask(task.id)
            }
            .onTapGesture {
                onSelectTask(task.id)
            }
            .contextMenu {
                taskMenuItems(for: task)
            }
        }
    }

    private func taskSummary(_ task: HomeFeature.RoutineDisplay) -> some View {
        HStack(spacing: 10) {
            Text(task.emoji)
                .font(isCompactLayout ? .subheadline : .headline)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font((isCompactLayout ? Font.caption : Font.subheadline).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .gridCellColumns(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var selectionControl: some View {
        if selectedTaskIDs.isEmpty {
            Button {
                selectedTaskIDs = Set(tasks.map(\.id))
            } label: {
                Image(systemName: "square")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select all backlog rows")
        } else {
            Menu {
                bulkSelectionMenuItems
            } label: {
                Label("\(selectedTaskIDs.count)", systemImage: "checkmark.square.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Color.accentColor)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("\(selectedTaskIDs.count) backlog rows selected")
        }
    }

    private var bulkSelectionMenuItems: some View {
        Group {
            Button("Clear Selection") {
                selectedTaskIDs.removeAll()
            }

            Divider()

            Button("Remove from Sprint") {
                assignSelectedTasks(to: nil)
            }

            backlogBulkMenuItems
            activeSprintBulkMenuItems

            if !availableSprints.isEmpty {
                Menu("Assign to Sprint") {
                    ForEach(availableSprints) { sprint in
                        Button(sprint.title) {
                            assignSelectedTasks(to: sprint.id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var backlogBulkMenuItems: some View {
        if availableBacklogs.isEmpty {
            Button("Move to Backlog") {
                assignSelectedTasksToBacklog(nil)
            }
        } else {
            Menu("Move to Backlog") {
                Button("Backlog") {
                    assignSelectedTasksToBacklog(nil)
                }

                ForEach(availableBacklogs) { backlog in
                    Button(backlog.title) {
                        assignSelectedTasksToBacklog(backlog.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var activeSprintBulkMenuItems: some View {
        if activeSprints.count == 1, let activeSprint = activeSprints.first {
            Button("Assign to \(activeSprint.title)") {
                assignSelectedTasks(to: activeSprint.id)
            }
        } else if activeSprints.count > 1 {
            Menu("Assign to Active Sprint") {
                ForEach(activeSprints) { sprint in
                    Button(sprint.title) {
                        assignSelectedTasks(to: sprint.id)
                    }
                }
            }
        }
    }

    private func taskMenuItems(for task: HomeFeature.RoutineDisplay) -> some View {
        HomeMacTodoBoardTaskMenuItems(
            task: task,
            availableBacklogs: availableBacklogs,
            availableSprints: availableSprints,
            activeSprints: activeSprints,
            onMoveTask: onMoveTask,
            onAssignTaskToBacklog: onAssignTaskToBacklog,
            onAssignTaskToSprint: onAssignTaskToSprint
        )
    }

    private func statusBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        HomeMacTodoBoardBadgeView(
            title: task.todoState == .paused ? "Paused" : (task.todoState ?? .ready).displayTitle,
            tint: HomeMacTodoBoardFormatting.tint(for: task.todoState ?? .ready),
            isCompactLayout: isCompactLayout
        )
    }

    private func toggleSelection(for taskID: UUID) {
        if selectedTaskIDs.contains(taskID) {
            selectedTaskIDs.remove(taskID)
        } else {
            selectedTaskIDs.insert(taskID)
        }
    }

    private func assignSelectedTasks(to sprintID: UUID?) {
        let selectedIDs = Array(selectedTaskIDs)
        guard !selectedIDs.isEmpty else { return }
        onAssignTasksToSprint(selectedIDs, sprintID)
        selectedTaskIDs.removeAll()
    }

    private func assignSelectedTasksToBacklog(_ backlogID: UUID?) {
        let selectedIDs = Array(selectedTaskIDs)
        guard !selectedIDs.isEmpty else { return }
        onAssignTasksToBacklog(selectedIDs, backlogID)
        selectedTaskIDs.removeAll()
    }

    private func rowBackground(isSelectedForBulkAction: Bool, taskID: UUID) -> Color {
        if isSelectedForBulkAction {
            return Color.accentColor.opacity(0.18)
        }
        if selectedTaskID == taskID {
            return Color.accentColor.opacity(0.12)
        }
        return Color.clear
    }
}

import SwiftUI

struct HomeMacTodoBoardView: View {
    struct Column: Identifiable {
        let state: TodoState
        let title: String
        let tint: Color
        let tasks: [HomeFeature.RoutineDisplay]

        var id: String { title }
    }

    let columns: [Column]
    let selectedTaskID: UUID?
    let isCompactLayout: Bool
    let availableSprints: [BoardSprint]
    let activeSprint: BoardSprint?
    let onSelectTask: (UUID) -> Void
    let onOpenTask: (UUID) -> Void
    let onMoveTask: (UUID, TodoState) -> Void
    let onAssignTaskToSprint: (UUID, UUID?) -> Void
    let onDropTask: (UUID, TodoState, [UUID]) -> Void
    let onMoveUp: (UUID, TodoState, [UUID]) -> Void
    let onMoveDown: (UUID, TodoState, [UUID]) -> Void

    @State private var draggedTaskID: UUID?
    @State private var highlightedColumnState: TodoState?
    @State private var hoverTargetTaskID: UUID?
    @State private var trailingDropColumnState: TodoState?

    private var isBoardEmpty: Bool {
        columns.allSatisfy { $0.tasks.isEmpty }
    }

    var body: some View {
        Group {
            if isBoardEmpty {
                boardEmptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(columns) { column in
                            boardColumn(column)
                                .frame(width: isCompactLayout ? 248 : 280)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: isCompactLayout)
    }

    @ViewBuilder
    private func boardColumn(_ column: Column) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(column.tint)
                    .frame(width: 8, height: 8)

                Text(column.title)
                    .font(.headline)

                Spacer(minLength: 0)

                Text("\(column.tasks.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: isCompactLayout ? 8 : 10) {
                    ForEach(Array(column.tasks.enumerated()), id: \.element.id) { index, task in
                        boardCard(
                            task,
                            columnState: column.state,
                            orderedTaskIDs: column.tasks.map(\.id),
                            isSelected: selectedTaskID == task.id,
                            canMoveUp: index > 0,
                            canMoveDown: index < column.tasks.count - 1,
                            showsInsertionIndicator: hoverTargetTaskID == task.id
                        )
                        .onDrop(
                            of: [.text],
                            delegate: BoardCardDropDelegate(
                                destinationTaskID: task.id,
                                columnState: column.state,
                                orderedTaskIDs: column.tasks.map(\.id),
                                draggedTaskID: $draggedTaskID,
                                highlightedColumnState: $highlightedColumnState,
                                hoverTargetTaskID: $hoverTargetTaskID,
                                trailingDropColumnState: $trailingDropColumnState,
                                onDropTask: onDropTask
                            )
                        )
                    }

                    boardColumnDropSpacer(
                        column,
                        isHighlighted: trailingDropColumnState == column.state
                    )
                }
                .padding(.bottom, 4)
            }
            .onDrop(
                of: [.text],
                delegate: BoardColumnDropDelegate(
                    columnState: column.state,
                    orderedTaskIDs: column.tasks.map(\.id),
                    draggedTaskID: $draggedTaskID,
                    highlightedColumnState: $highlightedColumnState,
                    hoverTargetTaskID: $hoverTargetTaskID,
                    trailingDropColumnState: $trailingDropColumnState,
                    onDropTask: onDropTask
                )
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundFill(for: column.state))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor(for: column.state), lineWidth: highlightedColumnState == column.state ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.12), value: highlightedColumnState)
        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: hoverTargetTaskID)
        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: trailingDropColumnState)
    }

    @ViewBuilder
    private func boardCard(
        _ task: HomeFeature.RoutineDisplay,
        columnState: TodoState,
        orderedTaskIDs: [UUID],
        isSelected: Bool,
        canMoveUp: Bool,
        canMoveDown: Bool,
        showsInsertionIndicator: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: isCompactLayout ? 8 : 10) {
            if showsInsertionIndicator {
                insertionIndicator
            }

            HStack(alignment: .top, spacing: 10) {
                Text(task.emoji)
                    .font(isCompactLayout ? .headline : .title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name)
                        .font((isCompactLayout ? Font.caption : Font.subheadline).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(isCompactLayout ? 1 : 2)

                    if let notes = task.notes, !notes.isEmpty {
                        Text(notes)
                            .font(isCompactLayout ? .caption2 : .caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(isCompactLayout ? 1 : 2)
                    }
                }

                Spacer(minLength: 0)

                if task.todoState != .done {
                    Menu {
                        moveMenuItems(for: task)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            if task.todoState == .paused || task.canceledAt != nil || task.dueDate != nil {
                HStack(spacing: 6) {
                    if task.todoState == .paused {
                        statusBadge(title: "Paused", tint: .orange)
                    }
                    if task.canceledAt != nil {
                        statusBadge(title: "Canceled", tint: .secondary)
                    } else if let dueDate = task.dueDate {
                        statusBadge(title: dueLabel(for: dueDate), tint: .blue)
                    }
                }
            }

            if let assignedSprintTitle = task.assignedSprintTitle {
                HStack(spacing: 6) {
                    statusBadge(title: assignedSprintTitle, tint: .purple)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)

                Button {
                    onMoveUp(task.id, columnState, orderedTaskIDs)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                .disabled(!canMoveUp)

                Button {
                    onMoveDown(task.id, columnState, orderedTaskIDs)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.borderless)
                .disabled(!canMoveDown)

                Spacer(minLength: 0)

                if task.todoState == .done {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(isCompactLayout ? 10 : 12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(count: 2) {
            onOpenTask(task.id)
        }
        .onTapGesture {
            onSelectTask(task.id)
        }
        .onDrag {
            draggedTaskID = task.id
            onSelectTask(task.id)
            return NSItemProvider(object: task.id.uuidString as NSString)
        }
        .contextMenu {
            moveMenuItems(for: task)
        }
        .scaleEffect(showsInsertionIndicator ? 0.985 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.86), value: showsInsertionIndicator)
    }

    @ViewBuilder
    private func moveMenuItems(for task: HomeFeature.RoutineDisplay) -> some View {
        if task.todoState != .ready {
            Button("Move to Ready") {
                onMoveTask(task.id, .ready)
            }
        }
        if task.todoState != .paused {
            Button("Pause") {
                onMoveTask(task.id, .paused)
            }
        }
        if task.todoState != .inProgress {
            Button("Move to In Progress") {
                onMoveTask(task.id, .inProgress)
            }
        }
        if task.todoState != .blocked {
            Button("Move to Blocked") {
                onMoveTask(task.id, .blocked)
            }
        }
        if task.todoState != .done {
            Button("Mark Done") {
                onMoveTask(task.id, .done)
            }
        }

        Divider()

        Button(task.assignedSprintID == nil ? "Move to Backlog" : "Remove from Sprint") {
            onAssignTaskToSprint(task.id, nil)
        }

        if let activeSprint, task.assignedSprintID != activeSprint.id {
            Button("Assign to \(activeSprint.title)") {
                onAssignTaskToSprint(task.id, activeSprint.id)
            }
        }

        if !availableSprints.isEmpty {
            Menu("Assign to Sprint") {
                ForEach(availableSprints) { sprint in
                    Button(sprint.title) {
                        onAssignTaskToSprint(task.id, sprint.id)
                    }
                    .disabled(task.assignedSprintID == sprint.id)
                }
            }
        }
    }

    private func statusBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font((isCompactLayout ? Font.system(size: 10) : Font.caption2).weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, isCompactLayout ? 2 : 3)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }

    private func dueLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func boardColumnDropSpacer(_ column: Column, isHighlighted: Bool) -> some View {
        VStack(spacing: 8) {
            if isHighlighted {
                insertionIndicator
            }

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isHighlighted
                        ? column.tint.opacity(0.14)
                        : Color.clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isHighlighted
                                ? column.tint.opacity(0.45)
                                : Color.primary.opacity(0.06),
                            style: StrokeStyle(lineWidth: isHighlighted ? 1.5 : 1, dash: [6, 6])
                        )
                )
                .frame(maxWidth: .infinity, minHeight: column.tasks.isEmpty ? 160 : (isCompactLayout ? 56 : 72))
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.86), value: isHighlighted)
    }

    private func backgroundFill(for state: TodoState) -> Color {
        if highlightedColumnState == state {
            return Color.accentColor.opacity(0.08)
        }
        return Color.secondary.opacity(0.08)
    }

    private func borderColor(for state: TodoState) -> Color {
        if highlightedColumnState == state {
            return Color.accentColor.opacity(0.5)
        }
        return Color.primary.opacity(0.06)
    }

    private var insertionIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(Color.accentColor)
                .frame(height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var boardEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.grid.3x3.topleft.filled")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("Nothing on this board yet")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Try another scope, change filters, or move a todo into this board.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

private struct BoardCardDropDelegate: DropDelegate {
    let destinationTaskID: UUID
    let columnState: TodoState
    let orderedTaskIDs: [UUID]
    @Binding var draggedTaskID: UUID?
    @Binding var highlightedColumnState: TodoState?
    @Binding var hoverTargetTaskID: UUID?
    @Binding var trailingDropColumnState: TodoState?
    let onDropTask: (UUID, TodoState, [UUID]) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedTaskID != nil
    }

    func dropEntered(info: DropInfo) {
        highlightedColumnState = columnState
        hoverTargetTaskID = destinationTaskID
        trailingDropColumnState = nil
    }

    func dropExited(info: DropInfo) {
        if highlightedColumnState == columnState {
            highlightedColumnState = nil
        }
        if hoverTargetTaskID == destinationTaskID {
            hoverTargetTaskID = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            clearDragState()
        }

        guard let draggedTaskID,
              draggedTaskID != destinationTaskID,
              let destinationIndex = orderedTaskIDs.firstIndex(of: destinationTaskID) else {
            return false
        }

        let reorderedIDs = reorderedTaskIDs(
            draggedTaskID: draggedTaskID,
            destinationIndex: destinationIndex,
            orderedTaskIDs: orderedTaskIDs
        )
        onDropTask(draggedTaskID, columnState, reorderedIDs)
        return true
    }

    private func reorderedTaskIDs(
        draggedTaskID: UUID,
        destinationIndex: Int,
        orderedTaskIDs: [UUID]
    ) -> [UUID] {
        var result = orderedTaskIDs.filter { $0 != draggedTaskID }
        let boundedIndex = min(max(destinationIndex, 0), result.count)
        result.insert(draggedTaskID, at: boundedIndex)
        return result
    }

    private func clearDragState() {
        highlightedColumnState = nil
        hoverTargetTaskID = nil
        trailingDropColumnState = nil
        draggedTaskID = nil
    }
}

private struct BoardColumnDropDelegate: DropDelegate {
    let columnState: TodoState
    let orderedTaskIDs: [UUID]
    @Binding var draggedTaskID: UUID?
    @Binding var highlightedColumnState: TodoState?
    @Binding var hoverTargetTaskID: UUID?
    @Binding var trailingDropColumnState: TodoState?
    let onDropTask: (UUID, TodoState, [UUID]) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedTaskID != nil
    }

    func dropEntered(info: DropInfo) {
        highlightedColumnState = columnState
        hoverTargetTaskID = nil
        trailingDropColumnState = columnState
    }

    func dropExited(info: DropInfo) {
        if highlightedColumnState == columnState {
            highlightedColumnState = nil
        }
        if trailingDropColumnState == columnState {
            trailingDropColumnState = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            clearDragState()
        }

        guard let draggedTaskID else { return false }
        var reorderedIDs = orderedTaskIDs.filter { $0 != draggedTaskID }
        reorderedIDs.append(draggedTaskID)
        onDropTask(draggedTaskID, columnState, reorderedIDs)
        return true
    }

    private func clearDragState() {
        highlightedColumnState = nil
        hoverTargetTaskID = nil
        trailingDropColumnState = nil
        draggedTaskID = nil
    }
}

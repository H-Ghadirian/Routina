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
    let onSelectTask: (UUID) -> Void
    let onMoveTask: (UUID, TodoState) -> Void
    let onMoveUp: (UUID, TodoState, [UUID]) -> Void
    let onMoveDown: (UUID, TodoState, [UUID]) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(columns) { column in
                    boardColumn(column)
                        .frame(width: 280)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
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
                LazyVStack(spacing: 10) {
                    ForEach(Array(column.tasks.enumerated()), id: \.element.id) { index, task in
                        boardCard(
                            task,
                            columnState: column.state,
                            orderedTaskIDs: column.tasks.map(\.id),
                            isSelected: selectedTaskID == task.id,
                            canMoveUp: index > 0,
                            canMoveDown: index < column.tasks.count - 1
                        )
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func boardCard(
        _ task: HomeFeature.RoutineDisplay,
        columnState: TodoState,
        orderedTaskIDs: [UUID],
        isSelected: Bool,
        canMoveUp: Bool,
        canMoveDown: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(task.emoji)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let notes = task.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
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

            HStack(spacing: 8) {
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
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            onSelectTask(task.id)
        }
        .contextMenu {
            moveMenuItems(for: task)
        }
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
    }

    private func statusBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
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
}

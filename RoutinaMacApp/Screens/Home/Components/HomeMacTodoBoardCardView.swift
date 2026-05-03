import SwiftUI

struct HomeMacTodoBoardCardView: View {
    let task: HomeFeature.RoutineDisplay
    let columnState: TodoState
    let orderedTaskIDs: [UUID]
    let isSelected: Bool
    let isCompactLayout: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let showsInsertionIndicator: Bool
    let availableBacklogs: [BoardBacklog]
    let availableSprints: [BoardSprint]
    let activeSprints: [BoardSprint]
    let onSelectTask: (UUID) -> Void
    let onOpenTask: (UUID) -> Void
    let onMoveTask: (UUID, TodoState) -> Void
    let onAssignTaskToBacklog: (UUID, UUID?) -> Void
    let onAssignTaskToSprint: (UUID, UUID?) -> Void
    let onMoveUp: (UUID, TodoState, [UUID]) -> Void
    let onMoveDown: (UUID, TodoState, [UUID]) -> Void
    @Binding var draggedTaskID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactLayout ? 8 : 10) {
            if showsInsertionIndicator {
                HomeMacTodoBoardInsertionIndicator()
            }

            header
            stateBadges
            assignmentBadges
            moveControls
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
            taskMenuItems
        }
        .scaleEffect(showsInsertionIndicator ? 0.985 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.86), value: showsInsertionIndicator)
    }

    private var header: some View {
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
                    taskMenuItems
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    @ViewBuilder
    private var stateBadges: some View {
        if task.todoState == .paused || task.canceledAt != nil || task.dueDate != nil {
            HStack(spacing: 6) {
                if task.todoState == .paused {
                    badge("Paused", tint: .orange)
                }
                if task.canceledAt != nil {
                    badge("Canceled", tint: .secondary)
                } else if let dueDate = task.dueDate {
                    badge(HomeMacTodoBoardFormatting.dueLabel(for: dueDate), tint: .blue)
                }
            }
        }
    }

    @ViewBuilder
    private var assignmentBadges: some View {
        if let assignedSprintTitle = task.assignedSprintTitle {
            HStack(spacing: 6) {
                badge(assignedSprintTitle, tint: .purple)
            }
        } else if let assignedBacklogTitle = task.assignedBacklogTitle {
            HStack(spacing: 6) {
                badge(assignedBacklogTitle, tint: .teal)
            }
        }
    }

    private var moveControls: some View {
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

    private var taskMenuItems: some View {
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

    private func badge(_ title: String, tint: Color) -> some View {
        HomeMacTodoBoardBadgeView(
            title: title,
            tint: tint,
            isCompactLayout: isCompactLayout
        )
    }
}

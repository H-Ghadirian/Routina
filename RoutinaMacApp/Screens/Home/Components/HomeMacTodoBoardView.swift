import SwiftUI

struct HomeMacTodoBoardView: View {
    struct Column: Identifiable {
        let state: TodoState
        let title: String
        let tint: Color
        let tasks: [HomeFeature.RoutineDisplay]

        var id: String { title }
    }

    enum Layout {
        case board
        case backlogList
    }

    let columns: [Column]
    let layout: Layout
    let selectedTaskID: UUID?
    let isCompactLayout: Bool
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
    let onDropTask: (UUID, TodoState, [UUID]) -> Void
    let onMoveUp: (UUID, TodoState, [UUID]) -> Void
    let onMoveDown: (UUID, TodoState, [UUID]) -> Void

    @State private var draggedTaskID: UUID?
    @State private var selectedBacklogTaskIDs: Set<UUID> = []
    @State private var highlightedColumnState: TodoState?
    @State private var hoverTargetTaskID: UUID?
    @State private var trailingDropColumnState: TodoState?

    private var isBoardEmpty: Bool {
        columns.allSatisfy { $0.tasks.isEmpty }
    }

    private var backlogTasks: [HomeFeature.RoutineDisplay] {
        columns.flatMap(\.tasks).sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }

            let lhsDue = lhs.dueDate ?? .distantFuture
            let rhsDue = rhs.dueDate ?? .distantFuture
            if lhsDue != rhsDue {
                return lhsDue < rhsDue
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        Group {
            if isBoardEmpty {
                HomeMacTodoBoardEmptyStateView()
            } else if layout == .backlogList {
                HomeMacTodoBoardBacklogListView(
                    tasks: backlogTasks,
                    isCompactLayout: isCompactLayout,
                    selectedTaskID: selectedTaskID,
                    availableBacklogs: availableBacklogs,
                    availableSprints: availableSprints,
                    activeSprints: activeSprints,
                    onSelectTask: onSelectTask,
                    onOpenTask: onOpenTask,
                    onMoveTask: onMoveTask,
                    onAssignTaskToBacklog: onAssignTaskToBacklog,
                    onAssignTasksToBacklog: onAssignTasksToBacklog,
                    onAssignTaskToSprint: onAssignTaskToSprint,
                    onAssignTasksToSprint: onAssignTasksToSprint,
                    selectedTaskIDs: $selectedBacklogTaskIDs
                )
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
                        HomeMacTodoBoardCardView(
                            task: task,
                            columnState: column.state,
                            orderedTaskIDs: column.tasks.map(\.id),
                            isSelected: selectedTaskID == task.id,
                            isCompactLayout: isCompactLayout,
                            canMoveUp: index > 0,
                            canMoveDown: index < column.tasks.count - 1,
                            showsInsertionIndicator: hoverTargetTaskID == task.id,
                            availableBacklogs: availableBacklogs,
                            availableSprints: availableSprints,
                            activeSprints: activeSprints,
                            onSelectTask: onSelectTask,
                            onOpenTask: onOpenTask,
                            onMoveTask: onMoveTask,
                            onAssignTaskToBacklog: onAssignTaskToBacklog,
                            onAssignTaskToSprint: onAssignTaskToSprint,
                            onMoveUp: onMoveUp,
                            onMoveDown: onMoveDown,
                            draggedTaskID: $draggedTaskID
                        )
                        .onDrop(
                            of: [.text],
                            delegate: HomeMacTodoBoardCardDropDelegate(
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

                    HomeMacTodoBoardColumnDropSpacer(
                        column: column,
                        isHighlighted: trailingDropColumnState == column.state,
                        isCompactLayout: isCompactLayout
                    )
                }
                .padding(.bottom, 4)
            }
            .onDrop(
                of: [.text],
                delegate: HomeMacTodoBoardColumnDropDelegate(
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
}

import ComposableArchitecture
import SwiftUI

extension HomeTCAView {
    var boardFilteredTodoDisplays: [HomeFeature.RoutineDisplay] {
        store.boardTodoDisplays
            .filter { task in
                task.isOneOffTask
                    && matchesSearch(task)
                    && matchesFilter(task)
                    && matchesManualPlaceFilter(task)
                    && HomeFeature.matchesImportanceUrgencyFilter(
                        store.selectedImportanceUrgencyFilter,
                        importance: task.importance,
                        urgency: task.urgency
                    )
                    && HomeFeature.matchesSelectedTag(store.selectedTag, in: task.tags)
                    && HomeFeature.matchesExcludedTags(store.excludedTags, in: task.tags)
            }
    }

    var boardOpenTodoCount: Int {
        boardFilteredTodoDisplays.count { display in
            display.todoState != .done
        }
    }

    var boardDoneTodoCount: Int {
        boardFilteredTodoDisplays.count { display in
            display.todoState == .done
        }
    }

    var boardBlockedTodoCount: Int {
        boardFilteredTodoDisplays.count { display in
            display.todoState == .blocked
        }
    }

    var boardInProgressTodoCount: Int {
        boardFilteredTodoDisplays.count { display in
            display.todoState == .inProgress
        }
    }

    var macTodoBoardColumns: [HomeMacTodoBoardView.Column] {
        [
            HomeMacTodoBoardView.Column(
                state: .ready,
                title: "Ready / Paused",
                tint: .orange,
                tasks: boardTasks(for: .ready)
            ),
            HomeMacTodoBoardView.Column(
                state: .inProgress,
                title: "In Progress",
                tint: .blue,
                tasks: boardTasks(for: .inProgress)
            ),
            HomeMacTodoBoardView.Column(
                state: .blocked,
                title: "Blocked",
                tint: .red,
                tasks: boardTasks(for: .blocked)
            ),
            HomeMacTodoBoardView.Column(
                state: .done,
                title: "Done",
                tint: .green,
                tasks: boardTasks(for: .done)
            )
        ]
    }

    var boardSelectedTodoDisplay: HomeFeature.RoutineDisplay? {
        guard let selectedTaskID = store.selectedTaskID else { return nil }
        return boardFilteredTodoDisplays.first(where: { $0.id == selectedTaskID })
    }

    var macBoardSidebarView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                HomeMacSidebarSectionCard(title: "Board") {
                    VStack(alignment: .leading, spacing: 12) {
                        boardSidebarStatRow(
                            title: "Ready / Paused",
                            value: boardTasks(for: .ready).count,
                            tint: .orange
                        )
                        boardSidebarStatRow(
                            title: "In Progress",
                            value: boardInProgressTodoCount,
                            tint: .blue
                        )
                        boardSidebarStatRow(
                            title: "Blocked",
                            value: boardBlockedTodoCount,
                            tint: .red
                        )
                        boardSidebarStatRow(
                            title: "Done",
                            value: boardDoneTodoCount,
                            tint: .green
                        )
                    }
                }

                HomeMacSidebarSectionCard(title: "Visible") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(boardFilteredTodoDisplays.count) cards in view")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("Search and filters shape these counts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HomeMacSidebarSectionCard(title: "Layout") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Compact cards", isOn: $isMacTodoBoardCompactCards)
                            .toggleStyle(.switch)

                        Text(
                            isMacTodoBoardCompactCards
                                ? "Shows a denser board for longer columns."
                                : "Shows fuller cards with a little more breathing room."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                HomeMacSidebarSectionCard(title: "Selected") {
                    if let selected = boardSelectedTodoDisplay {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center, spacing: 8) {
                                Text(selected.emoji)
                                    .font(.headline)

                                Text(selected.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                            }

                            if let notes = selected.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }

                            HStack(spacing: 8) {
                                boardStatePill(for: selected.todoState ?? .ready)

                                if let dueDate = selected.dueDate {
                                    Text(dueDate, style: .date)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("Select a card on the board to inspect it here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    var macTodoBoardDetailView: some View {
        HomeMacTodoBoardView(
            columns: macTodoBoardColumns,
            selectedTaskID: store.selectedTaskID,
            isCompactLayout: isMacTodoBoardCompactCards,
            onSelectTask: { taskID in
                store.send(.setSelectedTask(taskID))
            },
            onMoveTask: { taskID, state in
                store.send(.moveTodoToState(taskID, state))
            },
            onDropTask: { taskID, state, orderedTaskIDs in
                store.send(
                    .moveTodoOnBoard(
                        taskID: taskID,
                        targetState: state,
                        orderedTaskIDs: orderedTaskIDs
                    )
                )
            },
            onMoveUp: { taskID, state, orderedTaskIDs in
                store.send(
                    .moveTaskInSection(
                        taskID: taskID,
                        sectionKey: HomeFeature.boardSectionKey(for: state),
                        orderedTaskIDs: orderedTaskIDs,
                        direction: .up
                    )
                )
            },
            onMoveDown: { taskID, state, orderedTaskIDs in
                store.send(
                    .moveTaskInSection(
                        taskID: taskID,
                        sectionKey: HomeFeature.boardSectionKey(for: state),
                        orderedTaskIDs: orderedTaskIDs,
                        direction: .down
                    )
                )
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func boardTasks(for columnState: TodoState) -> [HomeFeature.RoutineDisplay] {
        let sectionKey = HomeFeature.boardSectionKey(for: columnState)
        let tasks = boardFilteredTodoDisplays.filter { task in
            switch columnState {
            case .ready:
                return task.todoState == .ready || task.todoState == .paused
            case .inProgress:
                return task.todoState == .inProgress
            case .blocked:
                return task.todoState == .blocked
            case .done:
                return task.todoState == .done
            case .paused:
                return false
            }
        }

        return tasks.sorted { lhs, rhs in
            let lhsOrder = lhs.manualSectionOrders[sectionKey] ?? Int.max
            let rhsOrder = rhs.manualSectionOrders[sectionKey] ?? Int.max
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }

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

    private func boardSidebarStatRow(title: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text("\(value)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
        }
    }

    private func boardStatePill(for state: TodoState) -> some View {
        Text(state == .paused ? "Paused" : state.displayTitle)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(boardTint(for: state))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(boardTint(for: state).opacity(0.12))
            )
    }

    private func boardTint(for state: TodoState) -> Color {
        switch state {
        case .ready, .paused:
            return .orange
        case .inProgress:
            return .blue
        case .blocked:
            return .red
        case .done:
            return .green
        }
    }
}

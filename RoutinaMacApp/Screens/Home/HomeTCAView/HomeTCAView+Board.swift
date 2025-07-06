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

    @ViewBuilder
    var macTodoBoardDetailView: some View {
        HomeMacTodoBoardView(
            columns: macTodoBoardColumns,
            selectedTaskID: store.selectedTaskID,
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
}

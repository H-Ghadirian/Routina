import ComposableArchitecture
import Foundation

extension HomeFeature {
    static func matchesBoardScope(
        _ task: RoutineDisplay,
        selectedScope: BoardScope,
        activeSprintIDs: Set<UUID>
    ) -> Bool {
        HomeBoardMutationSupport.matchesScope(
            assignedSprintID: task.assignedSprintID,
            assignedBacklogID: task.assignedBacklogID,
            todoState: task.todoState,
            selectedScope: selectedScope,
            activeSprintIDs: activeSprintIDs
        )
    }

    func handleMoveTodoToState(
        _ id: UUID,
        newState: TodoState,
        state: inout State
    ) -> Effect<Action> {
        guard let index = state.routineTasks.firstIndex(where: { $0.id == id }) else { return .none }
        guard state.routineTasks[index].isOneOffTask else { return .none }

        if newState == .done {
            guard !state.routineTasks[index].isCompletedOneOff,
                  !state.routineTasks[index].isCanceledOneOff else { return .none }
            return reduce(into: &state, action: .markTaskDone(id))
        }

        guard !state.routineTasks[index].isCompletedOneOff,
              !state.routineTasks[index].isCanceledOneOff else { return .none }

        let targetSectionKey = Self.boardSectionKey(for: newState)
        let nextOrder = nextManualOrder(in: targetSectionKey, tasks: state.routineTasks)
        let previousStateTitle = state.routineTasks[index].todoState?.displayTitle
        let newStateTitle = newState.displayTitle

        switch newState {
        case .paused:
            let pauseDate = now
            state.routineTasks[index].pausedAt = pauseDate
            state.routineTasks[index].snoozedUntil = nil
            state.routineTasks[index].todoStateRawValue = nil
            state.routineTasks[index].setManualSectionOrder(nextOrder, for: targetSectionKey)
            appendBoardTodoStateChange(
                to: state.routineTasks[index],
                previousStateTitle: previousStateTitle,
                newStateTitle: newStateTitle,
                timestamp: pauseDate
            )
            refreshDisplays(&state)
            syncSelectedTaskDetailState(&state)

            return .run { @MainActor [id, pauseDate, targetSectionKey, nextOrder, previousStateTitle, newStateTitle] _ in
                do {
                    let context = self.modelContext()
                    guard let task = try context.fetch(HomeTaskSupport.taskDescriptor(for: id)).first else { return }
                    task.pausedAt = pauseDate
                    task.snoozedUntil = nil
                    task.todoStateRawValue = nil
                    task.setManualSectionOrder(nextOrder, for: targetSectionKey)
                    self.appendBoardTodoStateChange(
                        to: task,
                        previousStateTitle: previousStateTitle,
                        newStateTitle: newStateTitle,
                        timestamp: pauseDate
                    )
                    try context.save()
                    NotificationCenter.default.postRoutineDidUpdate()
                } catch {
                    print("Failed to move todo to paused from board: \(error)")
                }
            }

        case .ready, .inProgress, .blocked:
            state.routineTasks[index].pausedAt = nil
            state.routineTasks[index].snoozedUntil = nil
            state.routineTasks[index].todoStateRawValue = newState.rawValue
            state.routineTasks[index].setManualSectionOrder(nextOrder, for: targetSectionKey)
            appendBoardTodoStateChange(
                to: state.routineTasks[index],
                previousStateTitle: previousStateTitle,
                newStateTitle: newStateTitle,
                timestamp: now
            )
            refreshDisplays(&state)
            syncSelectedTaskDetailState(&state)

            return .run { @MainActor [id, rawValue = newState.rawValue, targetSectionKey, nextOrder, previousStateTitle, newStateTitle, timestamp = now] _ in
                do {
                    let context = self.modelContext()
                    guard let task = try context.fetch(HomeTaskSupport.taskDescriptor(for: id)).first else { return }
                    task.pausedAt = nil
                    task.snoozedUntil = nil
                    task.todoStateRawValue = rawValue
                    task.setManualSectionOrder(nextOrder, for: targetSectionKey)
                    self.appendBoardTodoStateChange(
                        to: task,
                        previousStateTitle: previousStateTitle,
                        newStateTitle: newStateTitle,
                        timestamp: timestamp
                    )
                    try context.save()
                    NotificationCenter.default.postRoutineDidUpdate()
                } catch {
                    print("Failed to move todo to \(rawValue) from board: \(error)")
                }
            }

        case .done:
            return .none
        }
    }

    private func appendBoardTodoStateChange(
        to task: RoutineTask,
        previousStateTitle: String?,
        newStateTitle: String,
        timestamp: Date
    ) {
        guard task.isOneOffTask, previousStateTitle != newStateTitle else { return }
        task.appendChangeLogEntry(
            RoutineTaskChangeLogEntry(
                timestamp: timestamp,
                kind: .stateChanged,
                previousValue: previousStateTitle,
                newValue: newStateTitle
            )
        )
    }

    func handleMoveTodoOnBoard(
        taskID: UUID,
        targetState: TodoState,
        orderedTaskIDs: [UUID],
        state: inout State
    ) -> Effect<Action> {
        guard let index = state.routineTasks.firstIndex(where: { $0.id == taskID }) else { return .none }
        guard state.routineTasks[index].isOneOffTask else { return .none }

        let currentState = state.routineTasks[index].todoState ?? .ready
        let targetSectionKey = Self.boardSectionKey(for: targetState)

        if currentState == targetState {
            return reduce(
                into: &state,
                action: .setTaskOrderInSection(
                    sectionKey: targetSectionKey,
                    orderedTaskIDs: orderedTaskIDs
                )
            )
        }

        if currentState == .done && targetState != .done {
            return .none
        }

        let moveEffect = reduce(into: &state, action: .moveTodoToState(taskID, targetState))
        let reorderEffect: Effect<Action> = .send(
            .setTaskOrderInSection(
                sectionKey: targetSectionKey,
                orderedTaskIDs: orderedTaskIDs
            )
        )
        return .merge(moveEffect, reorderEffect)
    }

    func handleCreateBacklogConfirmed(title: String, state: inout State) -> Effect<Action> {
        state.creatingBacklogTitle = nil
        var sprintBoardData = state.sprintBoardData
        var selectedBoardScope = state.selectedBoardScope
        guard HomeBoardMutationSupport.createBacklog(
            title: title,
            now: now,
            data: &sprintBoardData,
            selectedScope: &selectedBoardScope
        ) else { return .none }
        state.sprintBoardData = sprintBoardData
        state.selectedBoardScope = selectedBoardScope
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleCreateSprintConfirmed(title: String, state: inout State) -> Effect<Action> {
        state.creatingSprintTitle = nil
        var sprintBoardData = state.sprintBoardData
        var selectedBoardScope = state.selectedBoardScope
        guard HomeBoardMutationSupport.createSprint(
            title: title,
            now: now,
            data: &sprintBoardData,
            selectedScope: &selectedBoardScope
        ) else { return .none }
        state.sprintBoardData = sprintBoardData
        state.selectedBoardScope = selectedBoardScope
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleRenameSprint(id: UUID, title: String, state: inout State) -> Effect<Action> {
        state.renamingSprintID = nil
        state.renamingSprintTitle = ""
        guard HomeBoardMutationSupport.renameSprint(
            id: id,
            title: title,
            data: &state.sprintBoardData
        ) else { return .none }
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleDeleteSprint(id: UUID, state: inout State) -> Effect<Action> {
        state.deletingSprintID = nil
        var sprintBoardData = state.sprintBoardData
        var selectedBoardScope = state.selectedBoardScope
        HomeBoardMutationSupport.deleteSprint(
            id: id,
            data: &sprintBoardData,
            selectedScope: &selectedBoardScope
        )
        state.sprintBoardData = sprintBoardData
        state.selectedBoardScope = selectedBoardScope
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleStartSprint(
        _ sprintID: UUID,
        state: inout State
    ) -> Effect<Action> {
        var sprintBoardData = state.sprintBoardData
        var selectedBoardScope = state.selectedBoardScope
        guard HomeBoardMutationSupport.startSprint(
            id: sprintID,
            now: now,
            data: &sprintBoardData,
            selectedScope: &selectedBoardScope
        ) else { return .none }
        state.sprintBoardData = sprintBoardData
        state.selectedBoardScope = selectedBoardScope
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleFinishSprint(
        _ sprintID: UUID,
        state: inout State
    ) -> Effect<Action> {
        var sprintBoardData = state.sprintBoardData
        var selectedBoardScope = state.selectedBoardScope
        guard HomeBoardMutationSupport.finishSprint(
            id: sprintID,
            now: now,
            data: &sprintBoardData,
            selectedScope: &selectedBoardScope
        ) else { return .none }
        state.sprintBoardData = sprintBoardData
        state.selectedBoardScope = selectedBoardScope
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleAssignTodoToSprint(
        taskID: UUID,
        sprintID: UUID?,
        state: inout State
    ) -> Effect<Action> {
        HomeBoardMutationSupport.assignTodoToSprint(
            taskID: taskID,
            sprintID: sprintID,
            data: &state.sprintBoardData
        )
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleAssignTodosToSprint(
        taskIDs: [UUID],
        sprintID: UUID?,
        state: inout State
    ) -> Effect<Action> {
        guard HomeBoardMutationSupport.assignTodosToSprint(
            taskIDs: taskIDs,
            sprintID: sprintID,
            data: &state.sprintBoardData
        ) else { return .none }
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleAssignTodoToBacklog(
        taskID: UUID,
        backlogID: UUID?,
        state: inout State
    ) -> Effect<Action> {
        HomeBoardMutationSupport.assignTodoToBacklog(
            taskID: taskID,
            backlogID: backlogID,
            data: &state.sprintBoardData
        )
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleAssignTodosToBacklog(
        taskIDs: [UUID],
        backlogID: UUID?,
        state: inout State
    ) -> Effect<Action> {
        guard HomeBoardMutationSupport.assignTodosToBacklog(
            taskIDs: taskIDs,
            backlogID: backlogID,
            data: &state.sprintBoardData
        ) else { return .none }
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }
}

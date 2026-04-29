import ComposableArchitecture
import Foundation

extension HomeFeature {
    static func matchesBoardScope(
        _ task: RoutineDisplay,
        selectedScope: BoardScope,
        activeSprintIDs: Set<UUID>
    ) -> Bool {
        switch selectedScope {
        case .backlog:
            return task.assignedSprintID == nil
                && task.assignedBacklogID == nil
                && task.todoState != .done
        case let .namedBacklog(backlogID):
            return task.assignedSprintID == nil
                && task.assignedBacklogID == backlogID
                && task.todoState != .done
        case .currentSprint:
            guard let assignedSprintID = task.assignedSprintID else { return false }
            return activeSprintIDs.contains(assignedSprintID)
        case let .sprint(sprintID):
            return task.assignedSprintID == sprintID
        }
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

        switch newState {
        case .paused:
            let pauseDate = now
            state.routineTasks[index].pausedAt = pauseDate
            state.routineTasks[index].snoozedUntil = nil
            state.routineTasks[index].todoStateRawValue = nil
            state.routineTasks[index].setManualSectionOrder(nextOrder, for: targetSectionKey)
            refreshDisplays(&state)
            syncSelectedTaskDetailState(&state)

            return .run { @MainActor [id, pauseDate, targetSectionKey, nextOrder] _ in
                do {
                    let context = self.modelContext()
                    guard let task = try context.fetch(taskDescriptor(for: id)).first else { return }
                    task.pausedAt = pauseDate
                    task.snoozedUntil = nil
                    task.todoStateRawValue = nil
                    task.setManualSectionOrder(nextOrder, for: targetSectionKey)
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
            refreshDisplays(&state)
            syncSelectedTaskDetailState(&state)

            return .run { @MainActor [id, rawValue = newState.rawValue, targetSectionKey, nextOrder] _ in
                do {
                    let context = self.modelContext()
                    guard let task = try context.fetch(taskDescriptor(for: id)).first else { return }
                    task.pausedAt = nil
                    task.snoozedUntil = nil
                    task.todoStateRawValue = rawValue
                    task.setManualSectionOrder(nextOrder, for: targetSectionKey)
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
        let finalTitle = title.trimmingCharacters(in: .whitespaces)
        state.creatingBacklogTitle = nil
        guard !finalTitle.isEmpty else { return .none }
        let backlog = BoardBacklog(title: finalTitle, createdAt: now)
        state.sprintBoardData.backlogs.insert(backlog, at: 0)
        state.selectedBoardScope = .namedBacklog(backlog.id)
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleCreateSprintConfirmed(title: String, state: inout State) -> Effect<Action> {
        let finalTitle = title.trimmingCharacters(in: .whitespaces)
        state.creatingSprintTitle = nil
        guard !finalTitle.isEmpty else { return .none }
        state.sprintBoardData.sprints.insert(
            BoardSprint(title: finalTitle, createdAt: now),
            at: 0
        )
        if case .backlog = state.selectedBoardScope,
           let createdSprintID = state.sprintBoardData.sprints.first?.id {
            state.selectedBoardScope = .sprint(createdSprintID)
        }
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleRenameSprint(id: UUID, title: String, state: inout State) -> Effect<Action> {
        let finalTitle = title.trimmingCharacters(in: .whitespaces)
        state.renamingSprintID = nil
        state.renamingSprintTitle = ""
        guard !finalTitle.isEmpty,
              let index = state.sprintBoardData.sprints.firstIndex(where: { $0.id == id }) else {
            return .none
        }
        state.sprintBoardData.sprints[index].title = finalTitle
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleDeleteSprint(id: UUID, state: inout State) -> Effect<Action> {
        state.deletingSprintID = nil
        state.sprintBoardData.assignments.removeAll(where: { $0.sprintID == id })
        state.sprintBoardData.sprints.removeAll(where: { $0.id == id })
        if case .sprint(let selectedID) = state.selectedBoardScope, selectedID == id {
            state.selectedBoardScope = .backlog
        }
        if case .currentSprint = state.selectedBoardScope,
           state.sprintBoardData.activeSprints.isEmpty {
            state.selectedBoardScope = .backlog
        }
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleStartSprint(
        _ sprintID: UUID,
        state: inout State
    ) -> Effect<Action> {
        guard let index = state.sprintBoardData.sprints.firstIndex(where: { $0.id == sprintID }) else {
            return .none
        }

        state.sprintBoardData.sprints[index].status = .active
        if state.sprintBoardData.sprints[index].startedAt == nil {
            state.sprintBoardData.sprints[index].startedAt = now
        }
        state.sprintBoardData.sprints[index].finishedAt = nil
        state.selectedBoardScope = .currentSprint
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleFinishSprint(
        _ sprintID: UUID,
        state: inout State
    ) -> Effect<Action> {
        guard let index = state.sprintBoardData.sprints.firstIndex(where: { $0.id == sprintID }) else {
            return .none
        }
        state.sprintBoardData.sprints[index].status = .finished
        state.sprintBoardData.sprints[index].finishedAt = now
        if case .currentSprint = state.selectedBoardScope,
           state.sprintBoardData.activeSprints.isEmpty {
            state.selectedBoardScope = .backlog
        }
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleAssignTodoToSprint(
        taskID: UUID,
        sprintID: UUID?,
        state: inout State
    ) -> Effect<Action> {
        applySprintAssignment(taskIDs: [taskID], sprintID: sprintID, state: &state)
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleAssignTodosToSprint(
        taskIDs: [UUID],
        sprintID: UUID?,
        state: inout State
    ) -> Effect<Action> {
        let uniqueIDs = uniqueTaskIDs(taskIDs)
        guard !uniqueIDs.isEmpty else { return .none }
        applySprintAssignment(taskIDs: uniqueIDs, sprintID: sprintID, state: &state)
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleAssignTodoToBacklog(
        taskID: UUID,
        backlogID: UUID?,
        state: inout State
    ) -> Effect<Action> {
        applyBacklogAssignment(taskIDs: [taskID], backlogID: backlogID, state: &state)
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleAssignTodosToBacklog(
        taskIDs: [UUID],
        backlogID: UUID?,
        state: inout State
    ) -> Effect<Action> {
        let uniqueIDs = uniqueTaskIDs(taskIDs)
        guard !uniqueIDs.isEmpty else { return .none }
        applyBacklogAssignment(taskIDs: uniqueIDs, backlogID: backlogID, state: &state)
        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    private func applySprintAssignment(
        taskIDs: [UUID],
        sprintID: UUID?,
        state: inout State
    ) {
        let taskIDSet = Set(taskIDs)
        state.sprintBoardData.assignments.removeAll(where: { taskIDSet.contains($0.todoID) })
        if sprintID != nil {
            state.sprintBoardData.backlogAssignments.removeAll(where: { taskIDSet.contains($0.todoID) })
        }
        if let sprintID {
            state.sprintBoardData.assignments.append(
                contentsOf: taskIDs.map { SprintAssignment(todoID: $0, sprintID: sprintID) }
            )
        }
    }

    private func applyBacklogAssignment(
        taskIDs: [UUID],
        backlogID: UUID?,
        state: inout State
    ) {
        let taskIDSet = Set(taskIDs)
        state.sprintBoardData.assignments.removeAll(where: { taskIDSet.contains($0.todoID) })
        state.sprintBoardData.backlogAssignments.removeAll(where: { taskIDSet.contains($0.todoID) })
        if let backlogID {
            state.sprintBoardData.backlogAssignments.append(
                contentsOf: taskIDs.map { BacklogAssignment(todoID: $0, backlogID: backlogID) }
            )
        }
    }
}

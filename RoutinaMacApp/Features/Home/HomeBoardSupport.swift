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

    func handleSetBacklogRoutingTags(
        backlogID: UUID,
        tags: [String],
        state: inout State
    ) -> Effect<Action> {
        guard HomeBoardMutationSupport.setBacklogRoutingTags(
            backlogID: backlogID,
            tags: tags,
            data: &state.sprintBoardData
        ) else { return .none }

        refreshDisplays(&state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func finishSaveAndRouteNewTodoToBacklog(
        _ task: RoutineTask,
        state: inout State
    ) -> Effect<Action> {
        let backlogSaveEffect: Effect<Action>
        if HomeBoardMutationSupport.assignNewTodoToMatchingBacklog(
            taskID: task.id,
            tags: task.tags,
            isOneOffTask: task.isOneOffTask,
            data: &state.sprintBoardData
        ) {
            backlogSaveEffect = saveSprintBoardEffect(state.sprintBoardData)
        } else {
            backlogSaveEffect = .none
        }

        return .merge(
            backlogSaveEffect,
            addRoutineActionHandler().finishSave(task, state: &state)
        )
    }

    func handleStartSprintFocus(
        _ sprintID: UUID,
        state: inout State
    ) -> Effect<Action> {
        guard HomeBoardMutationSupport.startSprintFocusSession(
            sprintID: sprintID,
            now: now,
            data: &state.sprintBoardData
        ) else { return .none }

        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleStopSprintFocus(
        _ sessionID: UUID,
        state: inout State
    ) -> Effect<Action> {
        guard HomeBoardMutationSupport.stopSprintFocusSession(
            sessionID: sessionID,
            now: now,
            data: &state.sprintBoardData
        ) else { return .none }

        beginSprintFocusAllocationReview(sessionID: sessionID, state: &state)
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func beginSprintFocusAllocationReview(
        sessionID: UUID,
        state: inout State
    ) {
        guard let session = state.sprintBoardData.focusSessions.first(where: { $0.id == sessionID }),
              !session.isActive else {
            state.sprintFocusAllocationSessionID = nil
            state.sprintFocusAllocationDrafts = []
            return
        }

        let existingAllocations = allocationMinutesByTask(session.allocations)
        let sprintTaskIDs = state.boardTodoDisplays
            .filter { $0.assignedSprintID == session.sprintID }
            .map(\.id)

        state.sprintFocusAllocationSessionID = sessionID
        state.sprintFocusAllocationDrafts = HomeTaskSupport.uniqueTaskIDs(sprintTaskIDs)
            .map { taskID in
                SprintFocusAllocationDraft(
                    taskID: taskID,
                    minutes: existingAllocations[taskID] ?? 0
                )
            }
    }

    func updateSprintFocusAllocationDraft(
        taskID: UUID,
        minutes: Int,
        state: inout State
    ) {
        guard let index = state.sprintFocusAllocationDrafts.firstIndex(where: { $0.taskID == taskID }) else {
            return
        }

        let maximumMinutes = maximumAllocationMinutes(for: taskID, state: state)
        state.sprintFocusAllocationDrafts[index].minutes = min(max(0, minutes), maximumMinutes)
    }

    func handleSaveSprintFocusAllocations(state: inout State) -> Effect<Action> {
        guard let sessionID = state.sprintFocusAllocationSessionID,
              let session = state.sprintBoardData.focusSessions.first(where: { $0.id == sessionID }) else {
            return .none
        }

        let previousAllocations = allocationMinutesByTask(session.allocations)
        let allocations = cappedSprintFocusAllocations(
            drafts: state.sprintFocusAllocationDrafts,
            recordedMinutes: session.roundedDurationMinutes
        )
        let updatedAllocations = allocationMinutesByTask(allocations)
        let allAllocatedTaskIDs = Set(previousAllocations.keys).union(updatedAllocations.keys)
        let deltas = allAllocatedTaskIDs.reduce(into: [UUID: Int]()) { result, taskID in
            let delta = (updatedAllocations[taskID] ?? 0) - (previousAllocations[taskID] ?? 0)
            if delta != 0 {
                result[taskID] = delta
            }
        }

        guard HomeBoardMutationSupport.updateSprintFocusAllocations(
            sessionID: sessionID,
            allocations: allocations,
            data: &state.sprintBoardData
        ) else { return .none }

        applySprintFocusAllocationDeltas(deltas, state: &state)
        state.sprintFocusAllocationSessionID = nil
        state.sprintFocusAllocationDrafts = []
        refreshDisplays(&state)

        return .merge(
            saveSprintBoardEffect(state.sprintBoardData),
            persistSprintFocusAllocationDeltas(deltas)
        )
    }

    func handleDeleteSprintFocusSession(
        _ sessionID: UUID,
        state: inout State
    ) -> Effect<Action> {
        guard let deletedSession = HomeBoardMutationSupport.deleteSprintFocusSession(
            sessionID: sessionID,
            data: &state.sprintBoardData
        ) else { return .none }
        state.board.sprintBoardRevision += 1

        let deltas = allocationMinutesByTask(deletedSession.allocations)
            .reduce(into: [UUID: Int]()) { result, item in
                result[item.key] = -item.value
            }

        applySprintFocusAllocationDeltas(deltas, state: &state)
        if state.sprintFocusAllocationSessionID == sessionID {
            state.sprintFocusAllocationSessionID = nil
            state.sprintFocusAllocationDrafts = []
        }
        refreshDisplays(&state)

        return .merge(
            saveSprintBoardEffect(state.sprintBoardData),
            persistSprintFocusAllocationDeltas(deltas)
        )
    }

    private func maximumAllocationMinutes(
        for taskID: UUID,
        state: State
    ) -> Int {
        guard let sessionID = state.sprintFocusAllocationSessionID,
              let session = state.sprintBoardData.focusSessions.first(where: { $0.id == sessionID }) else {
            return 720
        }

        let currentMinutes = state.sprintFocusAllocationDrafts
            .first(where: { $0.taskID == taskID })?
            .minutes ?? 0
        let otherAllocatedMinutes = state.sprintFocusAllocationDrafts.reduce(0) { total, draft in
            draft.taskID == taskID ? total : total + max(0, draft.minutes)
        }
        return max(0, session.roundedDurationMinutes - otherAllocatedMinutes + currentMinutes)
    }

    private func cappedSprintFocusAllocations(
        drafts: [SprintFocusAllocationDraft],
        recordedMinutes: Int
    ) -> [SprintFocusAllocation] {
        var remainingMinutes = max(0, recordedMinutes)
        var allocations: [SprintFocusAllocation] = []

        for draft in drafts where remainingMinutes > 0 {
            let minutes = min(max(0, draft.minutes), remainingMinutes)
            if minutes > 0 {
                allocations.append(SprintFocusAllocation(taskID: draft.taskID, minutes: minutes))
                remainingMinutes -= minutes
            }
        }

        return allocations
    }

    private func applySprintFocusAllocationDeltas(
        _ deltas: [UUID: Int],
        state: inout State
    ) {
        for (taskID, delta) in deltas {
            guard let index = state.routineTasks.firstIndex(where: { $0.id == taskID }) else { continue }
            let previousDuration = state.routineTasks[index].actualDurationMinutes
            let updatedDuration = sprintFocusDuration(
                afterApplying: delta,
                to: previousDuration
            )
            state.routineTasks[index].actualDurationMinutes = updatedDuration
            state.routineTasks[index].appendChangeLogEntry(
                sprintFocusTimeSpentChangeEntry(
                    previousDurationMinutes: previousDuration,
                    durationMinutes: updatedDuration
                )
            )
        }
    }

    private func persistSprintFocusAllocationDeltas(
        _ deltas: [UUID: Int]
    ) -> Effect<Action> {
        guard !deltas.isEmpty else { return .none }

        return .run { @MainActor _ in
            do {
                let context = self.modelContext()
                for (taskID, delta) in deltas {
                    guard let task = try context.fetch(HomeTaskSupport.taskDescriptor(for: taskID)).first else {
                        continue
                    }

                    let previousDuration = task.actualDurationMinutes
                    let updatedDuration = sprintFocusDuration(
                        afterApplying: delta,
                        to: previousDuration
                    )
                    task.actualDurationMinutes = updatedDuration
                    task.appendChangeLogEntry(
                        sprintFocusTimeSpentChangeEntry(
                            previousDurationMinutes: previousDuration,
                            durationMinutes: updatedDuration
                        )
                    )
                }
                try context.save()
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Failed to save sprint focus allocations: \(error)")
            }
        }
    }

    private func sprintFocusDuration(
        afterApplying delta: Int,
        to previousDuration: Int?
    ) -> Int? {
        let updated = max(0, (previousDuration ?? 0) + delta)
        return RoutineTask.sanitizedActualDurationMinutes(updated)
    }

    private func allocationMinutesByTask(
        _ allocations: [SprintFocusAllocation]
    ) -> [UUID: Int] {
        allocations.reduce(into: [UUID: Int]()) { result, allocation in
            result[allocation.taskID, default: 0] += max(0, allocation.minutes)
        }
    }

    private func sprintFocusTimeSpentChangeEntry(
        previousDurationMinutes: Int?,
        durationMinutes: Int?
    ) -> RoutineTaskChangeLogEntry {
        let kind: RoutineTaskChangeKind
        switch (previousDurationMinutes, durationMinutes) {
        case (nil, .some):
            kind = .timeSpentAdded
        case (.some, nil):
            kind = .timeSpentRemoved
        default:
            kind = .timeSpentChanged
        }

        return RoutineTaskChangeLogEntry(
            timestamp: now,
            kind: kind,
            previousValue: previousDurationMinutes.map(String.init),
            newValue: durationMinutes.map(String.init),
            durationMinutes: durationMinutes
        )
    }
}

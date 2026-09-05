import ComposableArchitecture
import Foundation

extension HomeFeature {
    func handleStartSprintFocus(
        _ sprintID: UUID,
        state: inout State
    ) -> Effect<Action> {
        guard
            HomeBoardMutationSupport.startSprintFocusSession(
                sprintID: sprintID,
                now: now,
                data: &state.sprintBoardData
            )
        else { return .none }

        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handlePauseSprintFocus(
        _ sessionID: UUID,
        state: inout State
    ) -> Effect<Action> {
        guard
            HomeBoardMutationSupport.pauseSprintFocusSession(
                sessionID: sessionID,
                now: now,
                data: &state.sprintBoardData
            )
        else { return .none }

        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleResumeSprintFocus(
        _ sessionID: UUID,
        state: inout State
    ) -> Effect<Action> {
        guard
            HomeBoardMutationSupport.resumeSprintFocusSession(
                sessionID: sessionID,
                now: now,
                data: &state.sprintBoardData
            )
        else { return .none }

        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleStopSprintFocus(
        _ sessionID: UUID,
        state: inout State
    ) -> Effect<Action> {
        guard
            HomeBoardMutationSupport.stopSprintFocusSession(
                sessionID: sessionID,
                now: now,
                data: &state.sprintBoardData
            )
        else { return .none }

        if state.sprintFocusAllocationSessionID == sessionID {
            state.sprintFocusAllocationSessionID = nil
            state.sprintFocusAllocationDrafts = []
        }
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func handleAbandonSprintFocus(
        _ sessionID: UUID,
        state: inout State
    ) -> Effect<Action> {
        guard
            HomeBoardMutationSupport.abandonSprintFocusSession(
                sessionID: sessionID,
                data: &state.sprintBoardData
            )
        else { return .none }

        if state.sprintFocusAllocationSessionID == sessionID {
            state.sprintFocusAllocationSessionID = nil
            state.sprintFocusAllocationDrafts = []
        }
        return saveSprintBoardEffect(state.sprintBoardData)
    }

    func beginSprintFocusAllocationReview(
        sessionID: UUID,
        state: inout State
    ) {
        guard let session = state.sprintBoardData.focusSessions.first(where: { $0.id == sessionID }),
            !session.isActive
        else {
            state.sprintFocusAllocationSessionID = nil
            state.sprintFocusAllocationDrafts = []
            return
        }

        let existingAllocations = allocationMinutesByTask(session.allocations)
        let sprintTaskIDs = state.boardTodoDisplays
            .filter { $0.assignedSprintID == session.sprintID }
            .map(\.id)

        state.sprintFocusAllocationSessionID = sessionID
        let drafts = HomeTaskSupport.uniqueTaskIDs(sprintTaskIDs)
            .map { taskID in
                SprintFocusAllocationDraft(
                    taskID: taskID,
                    minutes: existingAllocations[taskID] ?? 0
                )
            }
        state.sprintFocusAllocationDrafts = cappedSprintFocusAllocationDrafts(
            drafts: drafts,
            recordedMinutes: session.roundedDurationMinutes
        )
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
            let session = state.sprintBoardData.focusSessions.first(where: { $0.id == sessionID })
        else {
            return .none
        }

        let previousAllocations = allocationMinutesByTask(session.allocations)
        let allocations = cappedSprintFocusAllocations(
            drafts: state.sprintFocusAllocationDrafts,
            recordedMinutes: session.roundedDurationMinutes,
            existingAllocations: session.allocations
        )
        let updatedAllocations = allocationMinutesByTask(allocations)
        let allAllocatedTaskIDs = Set(previousAllocations.keys).union(updatedAllocations.keys)
        let deltas = allAllocatedTaskIDs.reduce(into: [UUID: Int]()) { result, taskID in
            let delta = (updatedAllocations[taskID] ?? 0) - (previousAllocations[taskID] ?? 0)
            if delta != 0 {
                result[taskID] = delta
            }
        }

        guard
            HomeBoardMutationSupport.updateSprintFocusAllocations(
                sessionID: sessionID,
                allocations: allocations,
                data: &state.sprintBoardData
            )
        else { return .none }

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
        guard
            let deletedSession = HomeBoardMutationSupport.deleteSprintFocusSession(
                sessionID: sessionID,
                data: &state.sprintBoardData
            )
        else { return .none }
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
            let session = state.sprintBoardData.focusSessions.first(where: { $0.id == sessionID })
        else {
            return 720
        }

        let currentMinutes =
            state.sprintFocusAllocationDrafts
            .first(where: { $0.taskID == taskID })?
            .minutes ?? 0
        let otherAllocatedMinutes = state.sprintFocusAllocationDrafts.reduce(0) { total, draft in
            draft.taskID == taskID ? total : total + max(0, draft.minutes)
        }
        return max(0, session.roundedDurationMinutes - otherAllocatedMinutes + currentMinutes)
    }

    private func cappedSprintFocusAllocations(
        drafts: [SprintFocusAllocationDraft],
        recordedMinutes: Int,
        existingAllocations: [SprintFocusAllocation] = []
    ) -> [SprintFocusAllocation] {
        var remainingMinutes = max(0, recordedMinutes)
        var allocations: [SprintFocusAllocation] = []
        let existingIDsByTaskID = Dictionary(
            existingAllocations.map { ($0.taskID, $0.id) },
            uniquingKeysWith: { first, _ in first }
        )

        for draft in drafts where remainingMinutes > 0 {
            let minutes = min(max(0, draft.minutes), remainingMinutes)
            if minutes > 0 {
                allocations.append(
                    SprintFocusAllocation(
                        id: existingIDsByTaskID[draft.taskID] ?? UUID(),
                        taskID: draft.taskID,
                        minutes: minutes
                    )
                )
                remainingMinutes -= minutes
            }
        }

        return allocations
    }

    private func cappedSprintFocusAllocationDrafts(
        drafts: [SprintFocusAllocationDraft],
        recordedMinutes: Int
    ) -> [SprintFocusAllocationDraft] {
        var remainingMinutes = max(0, recordedMinutes)

        return drafts.map { draft in
            let minutes = min(max(0, draft.minutes), remainingMinutes)
            remainingMinutes -= minutes
            return SprintFocusAllocationDraft(taskID: draft.taskID, minutes: minutes)
        }
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
                RoutinaLog.error("Failed to save sprint focus allocations: \(error)")
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

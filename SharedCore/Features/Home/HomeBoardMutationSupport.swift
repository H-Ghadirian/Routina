import Foundation

enum HomeBoardScope: Equatable, Sendable {
    case backlog
    case namedBacklog(UUID)
    case currentSprint
    case sprint(UUID)
}

enum HomeBoardMutationSupport {
    static func matchesScope(
        assignedSprintID: UUID?,
        assignedBacklogID: UUID?,
        todoState: TodoState?,
        selectedScope: HomeBoardScope,
        activeSprintIDs: Set<UUID>
    ) -> Bool {
        switch selectedScope {
        case .backlog:
            return assignedSprintID == nil
                && assignedBacklogID == nil
                && todoState != .done
        case let .namedBacklog(backlogID):
            return assignedSprintID == nil
                && assignedBacklogID == backlogID
                && todoState != .done
        case .currentSprint:
            guard let assignedSprintID else { return false }
            return activeSprintIDs.contains(assignedSprintID)
        case let .sprint(sprintID):
            return assignedSprintID == sprintID
        }
    }

    static func validatedScope(
        _ scope: HomeBoardScope,
        in data: SprintBoardData
    ) -> HomeBoardScope {
        if case .currentSprint = scope, data.activeSprints.isEmpty {
            return .backlog
        }
        if case let .namedBacklog(backlogID) = scope,
           !data.backlogs.contains(where: { $0.id == backlogID }) {
            return .backlog
        }
        if case let .sprint(sprintID) = scope,
           !data.sprints.contains(where: { $0.id == sprintID }) {
            return .backlog
        }
        return scope
    }

    @discardableResult
    static func createBacklog(
        title: String,
        now: Date,
        data: inout SprintBoardData,
        selectedScope: inout HomeBoardScope
    ) -> Bool {
        let finalTitle = title.trimmingCharacters(in: .whitespaces)
        guard !finalTitle.isEmpty else { return false }

        let backlog = BoardBacklog(title: finalTitle, createdAt: now)
        data.backlogs.insert(backlog, at: 0)
        selectedScope = .namedBacklog(backlog.id)
        return true
    }

    @discardableResult
    static func createSprint(
        title: String,
        now: Date,
        data: inout SprintBoardData,
        selectedScope: inout HomeBoardScope
    ) -> Bool {
        let finalTitle = title.trimmingCharacters(in: .whitespaces)
        guard !finalTitle.isEmpty else { return false }

        let sprint = BoardSprint(title: finalTitle, createdAt: now)
        data.sprints.insert(sprint, at: 0)
        if case .backlog = selectedScope {
            selectedScope = .sprint(sprint.id)
        }
        return true
    }

    @discardableResult
    static func renameSprint(
        id: UUID,
        title: String,
        data: inout SprintBoardData
    ) -> Bool {
        let finalTitle = title.trimmingCharacters(in: .whitespaces)
        guard !finalTitle.isEmpty,
              let index = data.sprints.firstIndex(where: { $0.id == id }) else {
            return false
        }

        data.sprints[index].title = finalTitle
        return true
    }

    static func deleteSprint(
        id: UUID,
        data: inout SprintBoardData,
        selectedScope: inout HomeBoardScope
    ) {
        data.assignments.removeAll(where: { $0.sprintID == id })
        data.focusSessions.removeAll(where: { $0.sprintID == id })
        data.sprints.removeAll(where: { $0.id == id })
        selectedScope = validatedScope(selectedScope, in: data)
    }

    @discardableResult
    static func startSprint(
        id: UUID,
        now: Date,
        data: inout SprintBoardData,
        selectedScope: inout HomeBoardScope
    ) -> Bool {
        guard let index = data.sprints.firstIndex(where: { $0.id == id }) else {
            return false
        }

        data.sprints[index].status = .active
        if data.sprints[index].startedAt == nil {
            data.sprints[index].startedAt = now
        }
        data.sprints[index].finishedAt = nil
        selectedScope = .currentSprint
        return true
    }

    @discardableResult
    static func finishSprint(
        id: UUID,
        now: Date,
        data: inout SprintBoardData,
        selectedScope: inout HomeBoardScope
    ) -> Bool {
        guard let index = data.sprints.firstIndex(where: { $0.id == id }) else {
            return false
        }

        data.sprints[index].status = .finished
        data.sprints[index].finishedAt = now
        selectedScope = validatedScope(selectedScope, in: data)
        return true
    }

    static func assignTodoToSprint(
        taskID: UUID,
        sprintID: UUID?,
        data: inout SprintBoardData
    ) {
        assignTodosToSprint(taskIDs: [taskID], sprintID: sprintID, data: &data)
    }

    @discardableResult
    static func assignTodosToSprint(
        taskIDs: [UUID],
        sprintID: UUID?,
        data: inout SprintBoardData
    ) -> Bool {
        let uniqueIDs = HomeTaskSupport.uniqueTaskIDs(taskIDs)
        guard !uniqueIDs.isEmpty else { return false }

        let taskIDSet = Set(uniqueIDs)
        data.assignments.removeAll(where: { taskIDSet.contains($0.todoID) })
        if sprintID != nil {
            data.backlogAssignments.removeAll(where: { taskIDSet.contains($0.todoID) })
        }
        if let sprintID {
            data.assignments.append(
                contentsOf: uniqueIDs.map { SprintAssignment(todoID: $0, sprintID: sprintID) }
            )
        }
        return true
    }

    static func assignTodoToBacklog(
        taskID: UUID,
        backlogID: UUID?,
        data: inout SprintBoardData
    ) {
        assignTodosToBacklog(taskIDs: [taskID], backlogID: backlogID, data: &data)
    }

    @discardableResult
    static func assignTodosToBacklog(
        taskIDs: [UUID],
        backlogID: UUID?,
        data: inout SprintBoardData
    ) -> Bool {
        let uniqueIDs = HomeTaskSupport.uniqueTaskIDs(taskIDs)
        guard !uniqueIDs.isEmpty else { return false }

        let taskIDSet = Set(uniqueIDs)
        data.assignments.removeAll(where: { taskIDSet.contains($0.todoID) })
        data.backlogAssignments.removeAll(where: { taskIDSet.contains($0.todoID) })
        if let backlogID {
            data.backlogAssignments.append(
                contentsOf: uniqueIDs.map { BacklogAssignment(todoID: $0, backlogID: backlogID) }
            )
        }
        return true
    }

    @discardableResult
    static func startSprintFocusSession(
        sprintID: UUID,
        now: Date,
        data: inout SprintBoardData
    ) -> Bool {
        guard data.sprints.contains(where: { $0.id == sprintID }),
              data.activeFocusSession == nil else {
            return false
        }

        data.focusSessions.insert(
            SprintFocusSession(sprintID: sprintID, startedAt: now),
            at: 0
        )
        return true
    }

    @discardableResult
    static func stopSprintFocusSession(
        sessionID: UUID,
        now: Date,
        data: inout SprintBoardData
    ) -> Bool {
        guard let index = data.focusSessions.firstIndex(where: { $0.id == sessionID }),
              data.focusSessions[index].isActive else {
            return false
        }

        data.focusSessions[index].stoppedAt = now
        return true
    }

    @discardableResult
    static func updateSprintFocusAllocations(
        sessionID: UUID,
        allocations: [SprintFocusAllocation],
        data: inout SprintBoardData
    ) -> Bool {
        guard let index = data.focusSessions.firstIndex(where: { $0.id == sessionID }),
              !data.focusSessions[index].isActive else {
            return false
        }

        data.focusSessions[index].allocations = allocations
            .filter { $0.minutes > 0 }
            .sorted { lhs, rhs in
                if lhs.minutes != rhs.minutes {
                    return lhs.minutes > rhs.minutes
                }
                return lhs.taskID.uuidString < rhs.taskID.uuidString
            }
        return true
    }
}

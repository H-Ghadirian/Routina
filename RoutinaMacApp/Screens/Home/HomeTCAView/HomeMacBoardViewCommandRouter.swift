import Foundation

struct HomeMacBoardViewCommandRouter {
    let send: (HomeFeature.Action) -> Void

    func selectTask(_ taskID: UUID) {
        send(.setSelectedTask(taskID))
    }

    func moveTask(_ taskID: UUID, to state: TodoState) {
        send(.moveTodoToState(taskID, state))
    }

    func assignTaskToBacklog(taskID: UUID, backlogID: UUID?) {
        send(.assignTodoToBacklog(taskID: taskID, backlogID: backlogID))
    }

    func assignTasksToBacklog(taskIDs: [UUID], backlogID: UUID?) {
        send(.assignTodosToBacklog(taskIDs: taskIDs, backlogID: backlogID))
    }

    func assignTaskToSprint(taskID: UUID, sprintID: UUID?) {
        send(.assignTodoToSprint(taskID: taskID, sprintID: sprintID))
    }

    func assignTasksToSprint(taskIDs: [UUID], sprintID: UUID?) {
        send(.assignTodosToSprint(taskIDs: taskIDs, sprintID: sprintID))
    }

    func dropTask(taskID: UUID, state: TodoState, orderedTaskIDs: [UUID]) {
        send(
            .moveTodoOnBoard(
                taskID: taskID,
                targetState: state,
                orderedTaskIDs: orderedTaskIDs
            )
        )
    }

    func moveTaskInBoardSection(
        taskID: UUID,
        state: TodoState,
        orderedTaskIDs: [UUID],
        direction: HomeTaskMoveDirection
    ) {
        send(
            .moveTaskInSection(
                taskID: taskID,
                sectionKey: HomeFeature.boardSectionKey(for: state),
                orderedTaskIDs: orderedTaskIDs,
                direction: direction
            )
        )
    }
}

import Foundation

struct TaskDetailStatusMutationHandler {
    typealias State = TaskDetailFeature.State

    struct TodoStatePersistenceRequest {
        var taskID: UUID
        var rawValue: String?
        var pausedAt: Date?
        var clearSnoozed: Bool
        var previousStateTitle: String?
        var newStateTitle: String
    }

    enum TodoStateMutationResult {
        case none
        case markAsDone
        case persist(TodoStatePersistenceRequest)
    }

    struct PressureMutation {
        var taskID: UUID
        var pressure: RoutineTaskPressure
    }

    struct MatrixMutation {
        var taskID: UUID
        var importance: RoutineTaskImportance
        var urgency: RoutineTaskUrgency
        var priority: RoutineTaskPriority
    }

    var now: () -> Date
    var matrixPriority: (RoutineTaskImportance, RoutineTaskUrgency) -> RoutineTaskPriority
    var appendLocalTodoStateChange: (RoutineTask, String?, String) -> Void
    var refreshTaskView: (inout State) -> Void
    var updateDerivedState: (inout State) -> Void

    func applyTodoStateChange(
        _ newState: TodoState,
        state: inout State
    ) -> TodoStateMutationResult {
        guard state.task.isOneOffTask else { return .none }
        guard !state.task.isCompletedOneOff, !state.task.isCanceledOneOff else { return .none }

        let previousStateTitle = state.task.todoState?.displayTitle
        switch newState {
        case .done:
            return .markAsDone

        case .paused:
            let pauseDate = now()
            state.task.pausedAt = pauseDate
            state.task.todoStateRawValue = nil
            appendLocalTodoStateChange(state.task, previousStateTitle, newState.displayTitle)
            refreshTaskView(&state)
            updateDerivedState(&state)
            return .persist(
                TodoStatePersistenceRequest(
                    taskID: state.task.id,
                    rawValue: nil,
                    pausedAt: pauseDate,
                    clearSnoozed: false,
                    previousStateTitle: previousStateTitle,
                    newStateTitle: newState.displayTitle
                )
            )

        case .ready, .inProgress, .blocked:
            state.task.pausedAt = nil
            state.task.snoozedUntil = nil
            state.task.todoStateRawValue = newState.rawValue
            appendLocalTodoStateChange(state.task, previousStateTitle, newState.displayTitle)
            refreshTaskView(&state)
            updateDerivedState(&state)
            return .persist(
                TodoStatePersistenceRequest(
                    taskID: state.task.id,
                    rawValue: newState.rawValue,
                    pausedAt: nil,
                    clearSnoozed: true,
                    previousStateTitle: previousStateTitle,
                    newStateTitle: newState.displayTitle
                )
            )
        }
    }

    func applyPressureChange(
        _ pressure: RoutineTaskPressure,
        state: inout State
    ) -> PressureMutation? {
        guard state.task.pressure != pressure else { return nil }
        state.task.pressure = pressure
        state.editPressure = pressure
        refreshTaskView(&state)
        updateDerivedState(&state)
        return PressureMutation(taskID: state.task.id, pressure: pressure)
    }

    func applyImportanceChange(
        _ importance: RoutineTaskImportance,
        state: inout State
    ) -> MatrixMutation? {
        guard state.task.importance != importance else { return nil }
        state.task.importance = importance
        state.editImportance = importance
        let newPriority = matrixPriority(importance, state.task.urgency)
        state.task.priority = newPriority
        state.editPriority = newPriority
        refreshTaskView(&state)
        updateDerivedState(&state)
        return MatrixMutation(
            taskID: state.task.id,
            importance: importance,
            urgency: state.task.urgency,
            priority: newPriority
        )
    }

    func applyUrgencyChange(
        _ urgency: RoutineTaskUrgency,
        state: inout State
    ) -> MatrixMutation? {
        guard state.task.urgency != urgency else { return nil }
        state.task.urgency = urgency
        state.editUrgency = urgency
        let newPriority = matrixPriority(state.task.importance, urgency)
        state.task.priority = newPriority
        state.editPriority = newPriority
        refreshTaskView(&state)
        updateDerivedState(&state)
        return MatrixMutation(
            taskID: state.task.id,
            importance: state.task.importance,
            urgency: urgency,
            priority: newPriority
        )
    }
}

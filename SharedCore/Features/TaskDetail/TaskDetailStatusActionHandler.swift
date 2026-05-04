import ComposableArchitecture
import Foundation

struct TaskDetailStatusActionHandler {
    typealias State = TaskDetailFeature.State
    typealias Action = TaskDetailFeature.Action

    var mutationHandler: TaskDetailStatusMutationHandler
    var markAsDone: (inout State) -> Effect<Action>
    var persistTodoStateChange: (TaskDetailStatusMutationHandler.TodoStatePersistenceRequest) -> Effect<Action>
    var persistPressureChange: (TaskDetailStatusMutationHandler.PressureMutation) -> Effect<Action>
    var persistMatrixPositionChange: (TaskDetailStatusMutationHandler.MatrixMutation) -> Effect<Action>

    func todoStateChanged(_ newState: TodoState, state: inout State) -> Effect<Action> {
        switch mutationHandler.applyTodoStateChange(newState, state: &state) {
        case .none:
            return .none

        case .markAsDone:
            return markAsDone(&state)

        case let .persist(request):
            return persistTodoStateChange(request)
        }
    }

    func pressureChanged(_ pressure: RoutineTaskPressure, state: inout State) -> Effect<Action> {
        guard let mutation = mutationHandler.applyPressureChange(pressure, state: &state) else {
            return .none
        }
        return persistPressureChange(mutation)
    }

    func importanceChanged(
        _ importance: RoutineTaskImportance,
        state: inout State
    ) -> Effect<Action> {
        guard let mutation = mutationHandler.applyImportanceChange(importance, state: &state) else {
            return .none
        }
        return persistMatrixPositionChange(mutation)
    }

    func urgencyChanged(_ urgency: RoutineTaskUrgency, state: inout State) -> Effect<Action> {
        guard let mutation = mutationHandler.applyUrgencyChange(urgency, state: &state) else {
            return .none
        }
        return persistMatrixPositionChange(mutation)
    }

    func setBlockedStateConfirmation(
        _ isPresented: Bool,
        state: inout State
    ) -> Effect<Action> {
        state.isBlockedStateConfirmationPresented = isPresented
        return .none
    }

    func confirmBlockedStateCompletion(state: inout State) -> Effect<Action> {
        state.isBlockedStateConfirmationPresented = false
        return markAsDone(&state)
    }
}

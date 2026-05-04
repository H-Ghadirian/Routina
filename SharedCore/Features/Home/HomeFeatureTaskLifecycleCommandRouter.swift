import ComposableArchitecture
import Foundation

protocol HomeFeatureTaskLifecycleCommandState {
    var routineTasks: [RoutineTask] { get set }
    var doneStats: HomeDoneStats { get set }
}

struct HomeFeatureTaskLifecycleCommandRouter<State: HomeFeatureTaskLifecycleCommandState, Action> {
    var markDone: (UUID, inout [RoutineTask], inout HomeDoneStats) -> Effect<Action>?
    var pause: (UUID, inout [RoutineTask]) -> Effect<Action>?
    var resume: (UUID, inout [RoutineTask]) -> Effect<Action>?
    var notToday: (UUID, inout [RoutineTask]) -> Effect<Action>?
    var pin: (UUID, inout [RoutineTask]) -> Effect<Action>?
    var unpin: (UUID, inout [RoutineTask]) -> Effect<Action>?
    var finishMutation: (Effect<Action>, inout State) -> Effect<Action>

    func markTaskDone(_ id: UUID, state: inout State) -> Effect<Action> {
        var routineTasks = state.routineTasks
        var doneStats = state.doneStats
        guard let effect = markDone(id, &routineTasks, &doneStats) else {
            return .none
        }
        state.routineTasks = routineTasks
        state.doneStats = doneStats
        return finishMutation(effect, &state)
    }

    func pauseTask(_ id: UUID, state: inout State) -> Effect<Action> {
        route(id, state: &state, command: pause)
    }

    func resumeTask(_ id: UUID, state: inout State) -> Effect<Action> {
        route(id, state: &state, command: resume)
    }

    func notTodayTask(_ id: UUID, state: inout State) -> Effect<Action> {
        route(id, state: &state, command: notToday)
    }

    func pinTask(_ id: UUID, state: inout State) -> Effect<Action> {
        route(id, state: &state, command: pin)
    }

    func unpinTask(_ id: UUID, state: inout State) -> Effect<Action> {
        route(id, state: &state, command: unpin)
    }

    private func route(
        _ id: UUID,
        state: inout State,
        command: (UUID, inout [RoutineTask]) -> Effect<Action>?
    ) -> Effect<Action> {
        guard let effect = command(id, &state.routineTasks) else {
            return .none
        }
        return finishMutation(effect, &state)
    }
}

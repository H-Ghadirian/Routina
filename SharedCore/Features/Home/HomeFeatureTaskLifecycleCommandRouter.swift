import ComposableArchitecture
import Foundation

protocol HomeFeatureTaskLifecycleCommandState {
    var routineTasks: [RoutineTask] { get set }
    var doneStats: HomeDoneStats { get set }
}

struct HomeFeatureTaskLifecycleCommandRouter<State: HomeFeatureTaskLifecycleCommandState, Action> {
    var markDone: (UUID, inout [RoutineTask], inout HomeDoneStats) -> Effect<Action>?
    var markMissed: (UUID, [RoutineTask], inout HomeDoneStats) -> Effect<Action>?
    var markCanceled: (UUID, [RoutineTask], inout HomeDoneStats) -> Effect<Action>?
    var pause: (UUID, inout [RoutineTask]) -> Effect<Action>?
    var resume: (UUID, inout [RoutineTask]) -> Effect<Action>?
    var notToday: (UUID, inout [RoutineTask]) -> Effect<Action>?
    var pin: (UUID, inout [RoutineTask]) -> Effect<Action>?
    var plan: (UUID, Date?, inout [RoutineTask]) -> Effect<Action>?
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

    func markTaskMissed(_ id: UUID, state: inout State) -> Effect<Action> {
        var doneStats = state.doneStats
        guard let effect = markMissed(id, state.routineTasks, &doneStats) else {
            return .none
        }
        state.doneStats = doneStats
        return finishMutation(effect, &state)
    }

    func markTaskCanceled(_ id: UUID, state: inout State) -> Effect<Action> {
        var doneStats = state.doneStats
        guard let effect = markCanceled(id, state.routineTasks, &doneStats) else {
            return .none
        }
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

    func planTask(_ id: UUID, plannedDate: Date?, state: inout State) -> Effect<Action> {
        guard let effect = plan(id, plannedDate, &state.routineTasks) else {
            return finishMutation(.none, &state)
        }
        return finishMutation(effect, &state)
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

import ComposableArchitecture
import Foundation

struct HomeFeatureTaskLifecycleCommandRouter {
    var pause: (UUID, inout [RoutineTask]) -> Effect<HomeFeature.Action>?
    var resume: (UUID, inout [RoutineTask]) -> Effect<HomeFeature.Action>?
    var notToday: (UUID, inout [RoutineTask]) -> Effect<HomeFeature.Action>?
    var pin: (UUID, inout [RoutineTask]) -> Effect<HomeFeature.Action>?
    var unpin: (UUID, inout [RoutineTask]) -> Effect<HomeFeature.Action>?
    var finishMutation: (Effect<HomeFeature.Action>, inout HomeFeature.State) -> Effect<HomeFeature.Action>

    func pauseTask(_ id: UUID, state: inout HomeFeature.State) -> Effect<HomeFeature.Action> {
        route(id, state: &state, command: pause)
    }

    func resumeTask(_ id: UUID, state: inout HomeFeature.State) -> Effect<HomeFeature.Action> {
        route(id, state: &state, command: resume)
    }

    func notTodayTask(_ id: UUID, state: inout HomeFeature.State) -> Effect<HomeFeature.Action> {
        route(id, state: &state, command: notToday)
    }

    func pinTask(_ id: UUID, state: inout HomeFeature.State) -> Effect<HomeFeature.Action> {
        route(id, state: &state, command: pin)
    }

    func unpinTask(_ id: UUID, state: inout HomeFeature.State) -> Effect<HomeFeature.Action> {
        route(id, state: &state, command: unpin)
    }

    private func route(
        _ id: UUID,
        state: inout HomeFeature.State,
        command: (UUID, inout [RoutineTask]) -> Effect<HomeFeature.Action>?
    ) -> Effect<HomeFeature.Action> {
        guard let effect = command(id, &state.routineTasks) else {
            return .none
        }
        return finishMutation(effect, &state)
    }
}

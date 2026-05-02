import ComposableArchitecture
import Foundation

protocol HomeFeaturePostMutationRefreshState {
    var routineTasks: [RoutineTask] { get }
    var routinePlaces: [RoutinePlace] { get }
    var routineGoals: [RoutineGoal] { get }
    var doneStats: HomeDoneStats { get }
    var presentation: HomePresentationState { get }
}

struct HomeFeaturePostMutationRefresher<State: HomeFeaturePostMutationRefreshState, Action> {
    var refreshDisplays: (inout State) -> Void
    var syncSelectedTaskDetailState: (inout State) -> Void
    var addRoutineAction: (AddRoutineFeature.Action) -> Action

    func refreshDisplaysAndSelection(_ state: inout State) {
        refreshDisplays(&state)
        syncSelectedTaskDetailState(&state)
    }

    func finishMutation(
        _ effect: Effect<Action>,
        state: inout State,
        refreshAddRoutineAvailability: Bool = false
    ) -> Effect<Action> {
        refreshDisplaysAndSelection(&state)

        guard refreshAddRoutineAvailability, state.presentation.addRoutineState != nil else {
            return effect
        }
        return .merge(
            effect,
            HomeAddRoutineSupport.availabilityRefreshEffect(
                tasks: state.routineTasks,
                places: state.routinePlaces,
                goals: state.routineGoals,
                doneStats: state.doneStats,
                action: addRoutineAction
            )
        )
    }
}

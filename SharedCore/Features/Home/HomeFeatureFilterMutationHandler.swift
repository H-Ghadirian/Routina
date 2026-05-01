import ComposableArchitecture
import Foundation

protocol HomeFeatureFilterMutationState {
    associatedtype RoutineDisplay: HomeTaskListDisplay

    var taskFilters: HomeTaskFiltersState { get set }
    var timelineFilters: HomeTimelineFiltersState { get set }
    var statsFilters: HomeStatsFiltersState { get set }
    var hideUnavailableRoutines: Bool { get set }
    var routineDisplays: [RoutineDisplay] { get }
    var awayRoutineDisplays: [RoutineDisplay] { get }
    var archivedRoutineDisplays: [RoutineDisplay] { get }
    var routinePlaces: [RoutinePlace] { get }
}

struct HomeFeatureFilterMutationHandler<State: HomeFeatureFilterMutationState, Action> {
    var setHideUnavailableRoutines: (Bool) -> Void
    var persistTemporaryViewState: (State) -> Void

    func validateFilterState(_ state: inout State) {
        HomeDisplayFilterSupport.validateTaskFilters(
            taskFilters: &state.taskFilters,
            routineDisplays: state.routineDisplays,
            awayRoutineDisplays: state.awayRoutineDisplays,
            archivedRoutineDisplays: state.archivedRoutineDisplays,
            routinePlaces: state.routinePlaces,
            tags: \.tags
        )
    }

    func applyTaskFilterMutation(
        _ mutation: HomeTaskFilterMutation,
        state: inout State
    ) -> Effect<Action> {
        var taskFilters = state.taskFilters
        var hideUnavailableRoutines = state.hideUnavailableRoutines
        let result = HomeFilterEditor.apply(
            mutation,
            taskFilters: &taskFilters,
            hideUnavailableRoutines: &hideUnavailableRoutines
        )
        state.taskFilters = taskFilters
        state.hideUnavailableRoutines = hideUnavailableRoutines
        if result.didResetHideUnavailableRoutines {
            setHideUnavailableRoutines(false)
        }
        if result.shouldPersistTemporaryViewState {
            persistTemporaryViewState(state)
        }
        return .none
    }

    func applyTimelineFilterMutation(
        _ mutation: HomeTimelineFilterMutation,
        state: inout State
    ) -> Effect<Action> {
        HomeFilterEditor.apply(mutation, timelineFilters: &state.timelineFilters)
        persistTemporaryViewState(state)
        return .none
    }

    func applyStatsFilterMutation(
        _ mutation: HomeStatsFilterMutation,
        state: inout State
    ) -> Effect<Action> {
        HomeFilterEditor.apply(mutation, statsFilters: &state.statsFilters)
        persistTemporaryViewState(state)
        return .none
    }
}

import ComposableArchitecture
import Foundation

protocol HomeFeatureTaskLoadState {
    var routineTasks: [RoutineTask] { get set }
    var routinePlaces: [RoutinePlace] { get set }
    var routineGoals: [RoutineGoal] { get set }
    var timelineLogs: [RoutineLog] { get set }
    var doneStats: HomeDoneStats { get set }
    var selection: HomeSelectionState { get set }
    var presentation: HomePresentationState { get set }
    var relatedTagRules: [RoutineRelatedTagRule] { get set }
    var tagColors: [String: String] { get set }
}

struct HomeFeatureTaskLoadHandler<State: HomeFeatureTaskLoadState, Action> {
    var relatedTagRules: () -> [RoutineRelatedTagRule]
    var tagColors: () -> [String: String]
    var refreshDisplays: (inout State) -> Void
    var syncSelectedTaskDetailState: (inout State) -> Void
    var validateFilterState: (inout State) -> Void
    var persistTemporaryViewState: (State) -> Void
    var refreshSelectedTaskDetailEffect: (State) -> Effect<Action>
    var addRoutineAction: (AddRoutineFeature.Action) -> Action

    func applyLoadedTasks(
        tasks: [RoutineTask],
        places: [RoutinePlace],
        goals: [RoutineGoal],
        logs: [RoutineLog],
        doneStats: HomeDoneStats,
        state: inout State
    ) -> Effect<Action> {
        let snapshot = HomeTaskLoadSupport.makeSnapshot(
            tasks: tasks,
            places: places,
            goals: goals,
            logs: logs,
            doneStats: doneStats,
            selectedTaskID: state.selection.selectedTaskID,
            detailTask: state.selection.taskDetailState?.task,
            selectedTaskReloadGuard: state.selection.selectedTaskReloadGuard,
            persistedRelatedTagRules: relatedTagRules()
        )
        state.relatedTagRules = snapshot.relatedTagRules
        state.tagColors = tagColors()
        state.selection.selectedTaskReloadGuard = snapshot.selectedTaskReloadGuard
        state.routineTasks = snapshot.tasks
        state.routinePlaces = snapshot.places
        state.routineGoals = snapshot.goals
        state.timelineLogs = snapshot.timelineLogs
        state.doneStats = snapshot.doneStats
        refreshDisplays(&state)
        syncSelectedTaskDetailState(&state)
        validateFilterState(&state)
        persistTemporaryViewState(state)

        let detailRefreshEffect = refreshSelectedTaskDetailEffect(state)
        guard state.presentation.addRoutineState != nil else { return detailRefreshEffect }
        return .merge(
            detailRefreshEffect,
            HomeAddRoutineSupport.availabilityRefreshEffect(
                tasks: snapshot.tasks,
                places: snapshot.places,
                goals: snapshot.goals,
                doneStats: snapshot.doneStats,
                action: addRoutineAction
            )
        )
    }
}

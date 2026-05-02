import Foundation

protocol HomeFeatureAddRoutinePresentationState {
    var routineTasks: [RoutineTask] { get }
    var routinePlaces: [RoutinePlace] { get }
    var routineGoals: [RoutineGoal] { get }
    var doneStats: HomeDoneStats { get }
    var selection: HomeSelectionState { get }
    var presentation: HomePresentationState { get set }
}

struct HomeFeatureAddRoutinePresentationRouter<State: HomeFeatureAddRoutinePresentationState> {
    var tagCounterDisplayMode: () -> TagCounterDisplayMode
    var relatedTagRules: () -> [RoutineRelatedTagRule]

    func setSheet(_ isPresented: Bool, state: inout State) {
        state.presentation.isAddRoutineSheetPresented = isPresented
        if isPresented {
            state.presentation.isMacFilterDetailPresented = false
            state.presentation.addRoutineState = makeAddRoutineState(for: state)
        } else {
            state.presentation.addRoutineState = nil
        }
    }

    func dismissSheet(state: inout State) {
        state.presentation.isAddRoutineSheetPresented = false
        state.presentation.addRoutineState = nil
    }

    @discardableResult
    func openLinkedTaskSheet(state: inout State) -> Bool {
        guard let currentTaskID = state.selection.taskDetailState?.task.id,
              let kind = state.selection.taskDetailState?.addLinkedTaskRelationshipKind else {
            return false
        }

        state.presentation.isAddRoutineSheetPresented = true
        state.presentation.isMacFilterDetailPresented = false
        state.presentation.addRoutineState = makeAddRoutineState(
            for: state,
            preselectedRelationships: [
                RoutineTaskRelationship(targetTaskID: currentTaskID, kind: kind.inverse)
            ],
            excludingRelationshipTaskID: currentTaskID
        )
        return true
    }

    private func makeAddRoutineState(
        for state: State,
        preselectedRelationships: [RoutineTaskRelationship] = [],
        excludingRelationshipTaskID: UUID? = nil
    ) -> AddRoutineFeature.State {
        HomeAddRoutineSupport.makeAddRoutineState(
            tasks: state.routineTasks,
            places: state.routinePlaces,
            goals: state.routineGoals,
            doneStats: state.doneStats,
            tagCounterDisplayMode: tagCounterDisplayMode(),
            relatedTagRules: relatedTagRules(),
            preselectedRelationships: preselectedRelationships,
            excludingRelationshipTaskID: excludingRelationshipTaskID
        )
    }
}

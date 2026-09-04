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
    var definedFlags: () -> [String] = { [] }
    var flagRules: () -> [RoutineFlagRule] = { [] }
    var addRoutineDraft: () -> AddRoutineDraftSnapshot?
    var referenceDate: () -> Date
    var calendar: Calendar

    func setSheet(
        _ isPresented: Bool,
        state: inout State,
        seedName: String? = nil,
        customTaskSectionID: UUID? = nil
    ) {
        state.presentation.isAddRoutineSheetPresented = isPresented
        if isPresented {
            state.presentation.isMacFilterDetailPresented = false
            state.presentation.addRoutineState = makeAddRoutineState(
                for: state,
                seedName: seedName,
                customTaskSectionID: customTaskSectionID
            )
        } else {
            state.presentation.addRoutineState = nil
        }
    }

    func dismissSheet(state: inout State) {
        state.presentation.isAddRoutineSheetPresented = false
        state.presentation.addRoutineState = nil
    }

    func setSmartSheet(_ isPresented: Bool, state: inout State) {
        state.presentation.isAddRoutineSheetPresented = isPresented
        if isPresented {
            state.presentation.isMacFilterDetailPresented = false
            state.presentation.addRoutineState = nil
        } else {
            state.presentation.addRoutineState = nil
        }
    }

    func prepareSheetDetails(state: inout State) {
        guard state.presentation.isAddRoutineSheetPresented,
            state.presentation.addRoutineState == nil
        else { return }

        state.presentation.addRoutineState = makeAddRoutineState(for: state)
    }

    @discardableResult
    func openLinkedTaskSheet(state: inout State) -> Bool {
        guard let currentTaskID = state.selection.taskDetailState?.task.id,
            let kind = state.selection.taskDetailState?.addLinkedTaskRelationshipKind
        else {
            return false
        }

        state.presentation.isAddRoutineSheetPresented = true
        state.presentation.isMacFilterDetailPresented = false
        state.presentation.addRoutineState = makeAddRoutineState(
            for: state,
            preselectedRelationships: [
                RoutineTaskRelationship(targetTaskID: currentTaskID, kind: kind.inverse)
            ]
        )
        return true
    }

    private func makeAddRoutineState(
        for state: State,
        preselectedRelationships: [RoutineTaskRelationship] = [],
        seedName: String? = nil,
        customTaskSectionID: UUID? = nil
    ) -> AddRoutineFeature.State {
        var addRoutineState = HomeAddRoutineSupport.makeAddRoutineState(
            tasks: state.routineTasks,
            places: state.routinePlaces,
            goals: state.routineGoals,
            doneStats: state.doneStats,
            tagCounterDisplayMode: tagCounterDisplayMode(),
            relatedTagRules: relatedTagRules(),
            availableFlags: definedFlags(),
            flagRules: flagRules(),
            preselectedRelationships: preselectedRelationships,
            initialDate: AddRoutineInitialDate(
                referenceDate: referenceDate(),
                calendar: calendar
            )
        )
        if let seedName = seedName.flatMap(RoutineTask.trimmedName),
            !seedName.isEmpty {
            AddRoutineValidationEditor.setRoutineName(
                seedName,
                state: &addRoutineState
            )
            addRoutineState.organization.customTaskSectionID = customTaskSectionID
            return addRoutineState
        }
        guard preselectedRelationships.isEmpty,
            let draft = addRoutineDraft()
        else {
            addRoutineState.organization.customTaskSectionID = customTaskSectionID
            return addRoutineState
        }
        draft.apply(to: &addRoutineState)
        if let customTaskSectionID {
            addRoutineState.organization.customTaskSectionID = customTaskSectionID
        }
        return addRoutineState
    }
}

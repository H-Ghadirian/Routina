import ComposableArchitecture

extension AddRoutineFeature {
    func reduceLifecycleActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .applyQuickAddDraftFromName:
            applyQuickAddDraftFromName(state: &state)
            return .none
        case .saveTapped:
            guard !state.isSaving else { return .none }
            applyQuickAddDraftFromName(state: &state)
            AddRoutineDraftFinalizer(now: now).apply(to: &state)
            AddRoutineValidationEditor.refreshNameValidation(state: &state)
            AddRoutineValidationEditor.refreshChecklistValidation(state: &state)
            guard state.checklist.checklistValidationMessage == nil else { return .none }
            guard
                let request = AddRoutineSaveRequest(
                    state: state,
                    calendar: calendar
                )
            else {
                return .none
            }
            state.isSaving = true
            return onSave(request)
        case .saveFailed:
            state.isSaving = false
            return .none
        case .cancelTapped:
            return onCancel()
        case .delegate:
            return .none
        default:
            return .none
        }
    }
}

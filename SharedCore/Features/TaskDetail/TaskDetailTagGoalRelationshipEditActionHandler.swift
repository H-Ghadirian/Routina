import ComposableArchitecture
import Foundation

struct TaskDetailTagGoalRelationshipEditActionHandler {
    typealias State = TaskDetailFeature.State
    typealias Action = TaskDetailFeature.Action

    var draftMutationHandler: TaskDetailEditDraftMutationHandler

    func editTagDraftChanged(_ value: String, state: inout State) -> Effect<Action> {
        draftMutationHandler.setTagDraft(value, state: &state)
        return .none
    }

    func editGoalDraftChanged(_ value: String, state: inout State) -> Effect<Action> {
        draftMutationHandler.setGoalDraft(value, state: &state)
        return .none
    }

    func editAddTagTapped(state: inout State) -> Effect<Action> {
        draftMutationHandler.addTag(state: &state)
        return .none
    }

    func editAddGoalTapped(state: inout State) -> Effect<Action> {
        draftMutationHandler.addGoal(state: &state)
        return .none
    }

    func editRemoveTag(_ tag: String, state: inout State) -> Effect<Action> {
        draftMutationHandler.removeTag(tag, state: &state)
        return .none
    }

    func editRemoveGoal(_ goalID: UUID, state: inout State) -> Effect<Action> {
        draftMutationHandler.removeGoal(goalID, state: &state)
        return .none
    }

    func editAddRelationship(
        taskID: UUID,
        kind: RoutineTaskRelationshipKind,
        state: inout State
    ) -> Effect<Action> {
        draftMutationHandler.addRelationship(taskID: taskID, kind: kind, state: &state)
        return .none
    }

    func editRemoveRelationship(_ taskID: UUID, state: inout State) -> Effect<Action> {
        draftMutationHandler.removeRelationship(taskID, state: &state)
        return .none
    }

    func editTagRenamed(
        oldName: String,
        newName: String,
        state: inout State
    ) -> Effect<Action> {
        draftMutationHandler.renameTag(oldName: oldName, newName: newName, state: &state)
        return .none
    }

    func editTagDeleted(_ tag: String, state: inout State) -> Effect<Action> {
        draftMutationHandler.deleteTag(tag, state: &state)
        return .none
    }

    func editSelectedPlaceChanged(_ placeID: UUID?, state: inout State) -> Effect<Action> {
        draftMutationHandler.setSelectedPlace(placeID, state: &state)
        return .none
    }

    func editToggleTagSelection(_ tag: String, state: inout State) -> Effect<Action> {
        draftMutationHandler.toggleTagSelection(tag, state: &state)
        return .none
    }

    func editToggleGoalSelection(
        _ goal: RoutineGoalSummary,
        state: inout State
    ) -> Effect<Action> {
        draftMutationHandler.toggleGoalSelection(goal, state: &state)
        return .none
    }

    func addLinkedTaskRelationshipKindChanged(
        _ kind: RoutineTaskRelationshipKind,
        state: inout State
    ) -> Effect<Action> {
        state.addLinkedTaskRelationshipKind = kind
        return .none
    }
}

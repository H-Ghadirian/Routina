import Foundation

struct AddRoutineOrganizationMutationHandler {
    func setAvailableTags(
        _ tags: [String],
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineOrganizationEditor.setAvailableTags(
            tags,
            organization: &state.organization
        )
    }

    func setAvailableTagSummaries(
        _ summaries: [RoutineTagSummary],
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineOrganizationEditor.setAvailableTagSummaries(
            summaries,
            organization: &state.organization
        )
    }

    func setAvailableGoals(
        _ goals: [RoutineGoalSummary],
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineOrganizationEditor.setAvailableGoals(
            goals,
            organization: &state.organization
        )
    }

    func setRelatedTagRules(
        _ rules: [RoutineRelatedTagRule],
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineOrganizationEditor.setRelatedTagRules(
            rules,
            organization: &state.organization
        )
    }

    func setAvailableRelationshipTasks(
        _ tasks: [RoutineTaskRelationshipCandidate],
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineOrganizationEditor.setAvailableRelationshipTasks(
            tasks,
            organization: &state.organization
        )
    }

    func setTagDraft(
        _ value: String,
        state: inout AddRoutineFeature.State
    ) {
        state.organization.tagDraft = value
    }

    func setGoalDraft(
        _ value: String,
        state: inout AddRoutineFeature.State
    ) {
        state.organization.goalDraft = value
    }

    func commitDraftTag(state: inout AddRoutineFeature.State) {
        AddRoutineOrganizationEditor.commitDraftTag(
            organization: &state.organization
        )
    }

    func commitDraftGoal(state: inout AddRoutineFeature.State) {
        AddRoutineOrganizationEditor.commitDraftGoal(
            organization: &state.organization
        )
    }

    func removeTag(
        _ tag: String,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineOrganizationEditor.removeTag(
            tag,
            organization: &state.organization
        )
    }

    func removeGoal(
        _ goalID: UUID,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineOrganizationEditor.removeGoal(
            goalID,
            organization: &state.organization
        )
    }

    func toggleTagSelection(
        _ tag: String,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineOrganizationEditor.toggleTagSelection(
            tag,
            organization: &state.organization
        )
    }

    func toggleGoalSelection(
        _ goal: RoutineGoalSummary,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineOrganizationEditor.toggleGoalSelection(
            goal,
            organization: &state.organization
        )
    }

    func addRelationship(
        targetTaskID: UUID,
        kind: RoutineTaskRelationshipKind,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineOrganizationEditor.addRelationship(
            targetTaskID: targetTaskID,
            kind: kind,
            organization: &state.organization
        )
    }

    func removeRelationship(
        targetTaskID: UUID,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineOrganizationEditor.removeRelationship(
            targetTaskID: targetTaskID,
            organization: &state.organization
        )
    }

    func renameTag(
        oldName: String,
        newName: String,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineOrganizationEditor.renameTag(
            oldName: oldName,
            newName: newName,
            organization: &state.organization
        )
    }

    func deleteTag(
        _ tag: String,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineOrganizationEditor.deleteTag(
            tag,
            organization: &state.organization
        )
    }

    func setAvailablePlaces(
        _ places: [RoutinePlaceSummary],
        state: inout AddRoutineFeature.State
    ) {
        var basics = state.basics
        var organization = state.organization
        AddRoutineFormEditor.setAvailablePlaces(
            places,
            basics: &basics,
            organization: &organization
        )
        state.basics = basics
        state.organization = organization
    }
}

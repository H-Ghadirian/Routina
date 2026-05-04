import ComposableArchitecture
import Foundation

struct TaskDetailEditContextActionHandler {
    typealias State = TaskDetailFeature.State
    typealias Action = TaskDetailFeature.Action

    func availablePlacesLoaded(_ places: [RoutinePlaceSummary], state: inout State) -> Effect<Action> {
        state.availablePlaces = places
        if let selectedPlaceID = state.editSelectedPlaceID,
           !places.contains(where: { $0.id == selectedPlaceID }) {
            state.editSelectedPlaceID = nil
        }
        return .none
    }

    func availableTagsLoaded(_ tags: [String], state: inout State) -> Effect<Action> {
        state.availableTags = RoutineTag.allTags(from: [tags])
        return .none
    }

    func availableGoalsLoaded(_ goals: [RoutineGoalSummary], state: inout State) -> Effect<Action> {
        state.availableGoals = RoutineGoalSummary.sanitized(goals).sorted {
            $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }
        state.editRoutineGoals = RoutineGoalSummary.summaries(
            for: state.task.goalIDs,
            in: state.availableGoals
        )
        return .none
    }

    func relatedTagRulesLoaded(
        _ rules: [RoutineRelatedTagRule],
        state: inout State
    ) -> Effect<Action> {
        state.relatedTagRules = RoutineTagRelations.sanitized(rules)
        return .none
    }

    func availableRelationshipTasksLoaded(
        _ tasks: [RoutineTaskRelationshipCandidate],
        state: inout State
    ) -> Effect<Action> {
        state.availableRelationshipTasks = tasks
        state.editRelationships = RoutineTaskRelationship.sanitized(
            state.editRelationships.filter { relationship in
                tasks.contains(where: { $0.id == relationship.targetTaskID })
            },
            ownerID: state.task.id
        )
        return .none
    }
}

import ComposableArchitecture
import Foundation

struct TaskDetailEditContextActionHandler {
    typealias State = TaskDetailFeature.State
    typealias Action = TaskDetailFeature.Action

    func availablePlacesLoaded(_ places: [RoutinePlaceSummary], state: inout State) -> Effect<Action> {
        state.availablePlaces = places
        let availablePlaceIDs = Set(places.map(\.id))
        let currentPlaceIDs = state.editSelectedPlaceIDs.isEmpty
            ? state.editSelectedPlaceID.map { [$0] } ?? []
            : state.editSelectedPlaceIDs
        state.editSelectedPlaceIDs = currentPlaceIDs.filter { availablePlaceIDs.contains($0) }
        state.editSelectedPlaceID = state.editSelectedPlaceIDs.first
        return .none
    }

    func availableTagsLoaded(_ tags: [String], state: inout State) -> Effect<Action> {
        state.availableTags = RoutineTag.allTags(from: [tags])
        state.availableTagSummaries = state.availableTags.map {
            RoutineTagSummary(name: $0, linkedRoutineCount: 0)
        }
        state.editRoutineTags = RoutineTag.deduplicated(
            state.editRoutineTags,
            preferredTags: state.availableTags
        )
        return .none
    }

    func availableTagSummariesLoaded(
        _ summaries: [RoutineTagSummary],
        state: inout State
    ) -> Effect<Action> {
        state.availableTagSummaries = AddRoutineOrganizationEditor.sortedTagSummaries(summaries)
        state.availableTags = state.availableTagSummaries.map(\.name)
        state.editRoutineTags = RoutineTag.deduplicated(
            state.editRoutineTags,
            preferredTags: state.availableTags
        )
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

    func availableEventsLoaded(
        _ events: [RoutineEventLinkCandidate],
        state: inout State
    ) -> Effect<Action> {
        state.availableEvents = events.sorted(by: RoutineEventLinkCandidate.sort)
        let availableEventIDs = Set(state.availableEvents.map(\.id))
        state.editEventIDs = RoutineEventIDStorage.sanitized(
            state.editEventIDs.filter { availableEventIDs.contains($0) }
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
        state.editAvailableRelationshipTasks = tasks
        let graphRelationships = RoutineTask.editableRelationships(
            for: state.task,
            within: tasks
        )
        let availableTaskIDs = Set(tasks.map(\.id))
        state.editRelationships = RoutineTaskRelationship.sanitized(
            (graphRelationships + state.editRelationships).filter { relationship in
                availableTaskIDs.contains(relationship.targetTaskID)
            },
            ownerID: state.task.id
        )
        return .none
    }
}

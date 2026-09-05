import ComposableArchitecture

extension AddRoutineFeature {
    func reduceOrganizationCatalogActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .availableTagsChanged(tags):
            organizationMutationHandler().setAvailableTags(tags, state: &state)
            return .none
        case let .availableFlagsChanged(flags):
            organizationMutationHandler().setAvailableFlags(flags, state: &state)
            return .none
        case let .flagRulesChanged(rules):
            state.organization.flagRules = RoutineFlagRules.sanitized(rules)
            return .none
        case let .availableTagSummariesChanged(summaries):
            organizationMutationHandler().setAvailableTagSummaries(summaries, state: &state)
            return .none
        case let .availableGoalsChanged(goals):
            organizationMutationHandler().setAvailableGoals(goals, state: &state)
            return .none
        case let .availableEventsChanged(events):
            organizationMutationHandler().setAvailableEvents(events, state: &state)
            return .none
        case let .relatedTagRulesChanged(rules):
            organizationMutationHandler().setRelatedTagRules(rules, state: &state)
            return .none
        case let .availableRelationshipTasksChanged(tasks):
            organizationMutationHandler().setAvailableRelationshipTasks(tasks, state: &state)
            return .none
        case let .availablePlacesChanged(places):
            organizationMutationHandler().setAvailablePlaces(places, state: &state)
            return .none
        default:
            return .none
        }
    }

    func reduceOrganizationDraftActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .tagDraftChanged(value):
            organizationMutationHandler().setTagDraft(value, state: &state)
            return .none
        case let .flagDraftChanged(value):
            organizationMutationHandler().setFlagDraft(value, state: &state)
            return .none
        case let .goalDraftChanged(value):
            organizationMutationHandler().setGoalDraft(value, state: &state)
            return .none
        case .addTagTapped:
            organizationMutationHandler().commitDraftTag(state: &state)
            return .none
        case .addFlagTapped:
            addDraftFlag(state: &state)
            return .none
        case .addGoalTapped:
            organizationMutationHandler().commitDraftGoal(state: &state)
            return .none
        case let .removeTag(tag):
            organizationMutationHandler().removeTag(tag, state: &state)
            return .none
        case let .removeFlag(flag):
            organizationMutationHandler().removeFlag(flag, state: &state)
            return .none
        case let .removeGoal(goalID):
            organizationMutationHandler().removeGoal(goalID, state: &state)
            return .none
        default:
            return .none
        }
    }

    func reduceOrganizationSelectionActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .toggleTagSelection(tag):
            organizationMutationHandler().toggleTagSelection(tag, state: &state)
            return .none
        case let .toggleFlagSelection(flag):
            toggleFlagSelection(flag, state: &state)
            return .none
        case let .toggleGoalSelection(goal):
            organizationMutationHandler().toggleGoalSelection(goal, state: &state)
            return .none
        case let .toggleEventSelection(eventID):
            organizationMutationHandler().toggleEventSelection(eventID, state: &state)
            return .none
        case let .addRelationship(taskID, kind):
            organizationMutationHandler().addRelationship(
                targetTaskID: taskID,
                kind: kind,
                state: &state
            )
            return .none
        case let .removeRelationship(taskID):
            organizationMutationHandler().removeRelationship(
                targetTaskID: taskID,
                state: &state
            )
            return .none
        case let .tagRenamed(oldName, newName):
            organizationMutationHandler().renameTag(
                oldName: oldName,
                newName: newName,
                state: &state
            )
            return .none
        case let .tagDeleted(tag):
            organizationMutationHandler().deleteTag(tag, state: &state)
            return .none
        default:
            return .none
        }
    }

    func reducePlaceActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .selectedPlaceChanged(placeID):
            AddRoutineFormEditor.setSelectedPlace(placeID, basics: &state.basics)
            return .none
        case let .selectedPlaceIDsChanged(placeIDs):
            AddRoutineFormEditor.setSelectedPlaces(placeIDs, basics: &state.basics)
            return .none
        case let .destinationAddressChanged(address):
            state.basics.destinationAddress = address
            return .none
        case let .destinationCoordinateChanged(coordinate):
            state.basics.destinationLatitude = coordinate?.latitude
            state.basics.destinationLongitude = coordinate?.longitude
            return .none
        default:
            return .none
        }
    }
}

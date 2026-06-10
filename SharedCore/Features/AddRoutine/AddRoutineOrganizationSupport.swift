import Foundation

enum AddRoutineOrganizationEditor {
    static func setAvailableTags(
        _ tags: [String],
        organization: inout AddRoutineOrganizationState
    ) {
        organization.availableTags = RoutineTag.allTags(from: [tags])
        organization.routineTags = RoutineTag.deduplicated(
            organization.routineTags,
            preferredTags: organization.availableTags
        )
        organization.availableTagSummaries = organization.availableTags.map {
            RoutineTagSummary(name: $0, linkedRoutineCount: 0)
        }
    }

    static func setAvailableTagSummaries(
        _ summaries: [RoutineTagSummary],
        organization: inout AddRoutineOrganizationState
    ) {
        organization.availableTagSummaries = sortedTagSummaries(summaries)
        organization.availableTags = organization.availableTagSummaries.map(\.name)
        organization.routineTags = RoutineTag.deduplicated(
            organization.routineTags,
            preferredTags: organization.availableTags
        )
    }

    static func setAvailableGoals(
        _ goals: [RoutineGoalSummary],
        organization: inout AddRoutineOrganizationState
    ) {
        organization.availableGoals = RoutineGoalSummary.sanitized(goals).sorted {
            $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }
        organization.routineGoals = RoutineGoalSummary.sanitized(
            organization.routineGoals.filter { selectedGoal in
                organization.availableGoals.contains(where: { $0.id == selectedGoal.id })
                    || RoutineGoal.normalizedTitle(selectedGoal.title) != nil
            }
        )
    }

    static func setAvailableEvents(
        _ events: [RoutineEventLinkCandidate],
        organization: inout AddRoutineOrganizationState
    ) {
        organization.availableEvents = events.sorted(by: RoutineEventLinkCandidate.sort)
        let availableEventIDs = Set(organization.availableEvents.map(\.id))
        organization.eventIDs = RoutineEventIDStorage.sanitized(
            organization.eventIDs.filter { availableEventIDs.contains($0) }
        )
    }

    static func setRelatedTagRules(
        _ rules: [RoutineRelatedTagRule],
        organization: inout AddRoutineOrganizationState
    ) {
        organization.relatedTagRules = RoutineTagRelations.sanitized(rules)
    }

    static func setAvailableRelationshipTasks(
        _ tasks: [RoutineTaskRelationshipCandidate],
        organization: inout AddRoutineOrganizationState
    ) {
        organization.availableRelationshipTasks = tasks
        organization.relationships = RoutineTaskRelationship.sanitized(
            organization.relationships.filter { relationship in
                tasks.contains(where: { $0.id == relationship.targetTaskID })
            }
        )
    }

    static func commitDraftTag(
        organization: inout AddRoutineOrganizationState
    ) {
        organization.routineTags = RoutineTag.appending(
            organization.tagDraft,
            to: organization.routineTags,
            availableTags: organization.availableTags
        )
        organization.tagDraft = ""
    }

    static func commitDraftGoal(
        organization: inout AddRoutineOrganizationState
    ) {
        organization.routineGoals = RoutineGoalSummary.appending(
            organization.goalDraft,
            availableGoals: organization.availableGoals,
            to: organization.routineGoals
        )
        organization.goalDraft = ""
    }

    static func removeTag(
        _ tag: String,
        organization: inout AddRoutineOrganizationState
    ) {
        organization.routineTags = RoutineTag.removing(tag, from: organization.routineTags)
    }

    static func toggleTagSelection(
        _ tag: String,
        organization: inout AddRoutineOrganizationState
    ) {
        if RoutineTag.contains(tag, in: organization.routineTags) {
            organization.routineTags = RoutineTag.removing(tag, from: organization.routineTags)
        } else {
            organization.routineTags = RoutineTag.appending(
                tag,
                to: organization.routineTags,
                availableTags: organization.availableTags
            )
        }
    }

    static func removeGoal(
        _ goalID: UUID,
        organization: inout AddRoutineOrganizationState
    ) {
        organization.routineGoals = RoutineGoalSummary.removing(goalID, from: organization.routineGoals)
    }

    static func toggleGoalSelection(
        _ goal: RoutineGoalSummary,
        organization: inout AddRoutineOrganizationState
    ) {
        organization.routineGoals = RoutineGoalSummary.toggling(goal, in: organization.routineGoals)
    }

    static func toggleEventSelection(
        _ eventID: UUID,
        organization: inout AddRoutineOrganizationState
    ) {
        guard organization.availableEvents.contains(where: { $0.id == eventID }) else { return }
        var eventIDs = organization.eventIDs
        if eventIDs.contains(eventID) {
            eventIDs.removeAll { $0 == eventID }
        } else {
            eventIDs.append(eventID)
        }
        organization.eventIDs = RoutineEventIDStorage.sanitized(eventIDs)
    }

    static func addRelationship(
        targetTaskID: UUID,
        kind: RoutineTaskRelationshipKind,
        organization: inout AddRoutineOrganizationState
    ) {
        organization.relationships = RoutineTaskRelationship.sanitized(
            organization.relationships + [RoutineTaskRelationship(targetTaskID: targetTaskID, kind: kind)]
        )
    }

    static func removeRelationship(
        targetTaskID: UUID,
        organization: inout AddRoutineOrganizationState
    ) {
        organization.relationships.removeAll { $0.targetTaskID == targetTaskID }
    }

    static func renameTag(
        oldName: String,
        newName: String,
        organization: inout AddRoutineOrganizationState
    ) {
        organization.availableTags = RoutineTag.replacing(
            oldName,
            with: newName,
            in: organization.availableTags
        )
        if let index = organization.availableTagSummaries.firstIndex(where: {
            RoutineTag.normalized($0.name) == RoutineTag.normalized(oldName)
        }) {
            organization.availableTagSummaries[index].name = RoutineTag.cleaned(newName) ?? newName
            organization.availableTagSummaries = sortedTagSummaries(organization.availableTagSummaries)
            organization.availableTags = organization.availableTagSummaries.map(\.name)
        }
        if RoutineTag.contains(oldName, in: organization.routineTags) {
            organization.routineTags = RoutineTag.replacing(
                oldName,
                with: newName,
                in: organization.routineTags
            )
        }
        organization.relatedTagRules = RoutineTagRelations.replacing(
            oldName,
            with: newName,
            in: organization.relatedTagRules
        )
    }

    static func deleteTag(
        _ tag: String,
        organization: inout AddRoutineOrganizationState
    ) {
        organization.availableTags = RoutineTag.removing(tag, from: organization.availableTags)
        organization.availableTagSummaries.removeAll {
            RoutineTag.normalized($0.name) == RoutineTag.normalized(tag)
        }
        organization.routineTags = RoutineTag.removing(tag, from: organization.routineTags)
        organization.relatedTagRules = RoutineTagRelations.removing(tag, from: organization.relatedTagRules)
    }

    static func sortedTagSummaries(
        _ summaries: [RoutineTagSummary]
    ) -> [RoutineTagSummary] {
        summaries.sorted { lhs, rhs in
            let lhsTotal = lhs.linkedRoutineCount + lhs.doneCount
            let rhsTotal = rhs.linkedRoutineCount + rhs.doneCount

            if lhsTotal != rhsTotal {
                return lhsTotal > rhsTotal
            }
            if lhs.doneCount != rhs.doneCount {
                return lhs.doneCount > rhs.doneCount
            }
            if lhs.linkedRoutineCount != rhs.linkedRoutineCount {
                return lhs.linkedRoutineCount > rhs.linkedRoutineCount
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

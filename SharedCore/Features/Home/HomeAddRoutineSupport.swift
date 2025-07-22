import Foundation

enum HomeAddRoutineSupport {
    static func makeAddRoutineState(
        tasks: [RoutineTask],
        places: [RoutinePlace],
        doneStats: HomeDoneStats,
        tagCounterDisplayMode: TagCounterDisplayMode,
        relatedTagRules: [RoutineRelatedTagRule],
        preselectedRelationships: [RoutineTaskRelationship] = [],
        excludingRelationshipTaskID: UUID? = nil
    ) -> AddRoutineFeature.State {
        let learnedRules = RoutineTagRelations.learnedRules(from: tasks.map(\.tags))
        return AddRoutineFeature.State(
            organization: AddRoutineOrganizationState(
                relationships: preselectedRelationships,
                availableTags: HomeTaskSupport.availableTags(from: tasks),
                availableTagSummaries: RoutineTag.summaries(
                    from: tasks,
                    countsByTaskID: doneStats.countsByTaskID
                ),
                relatedTagRules: RoutineTagRelations.sanitized(relatedTagRules + learnedRules),
                tagCounterDisplayMode: tagCounterDisplayMode,
                availableRelationshipTasks: RoutineTaskRelationshipCandidate.from(
                    tasks,
                    excluding: excludingRelationshipTaskID
                ),
                existingRoutineNames: HomeTaskSupport.existingRoutineNames(from: tasks),
                availablePlaces: RoutinePlace.summaries(from: places, linkedTo: tasks)
            )
        )
    }
}

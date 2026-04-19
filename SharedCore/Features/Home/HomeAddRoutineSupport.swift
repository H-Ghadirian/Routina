import Foundation

enum HomeAddRoutineSupport {
    static func makeAddRoutineState(
        tasks: [RoutineTask],
        places: [RoutinePlace],
        doneStats: HomeDoneStats,
        tagCounterDisplayMode: TagCounterDisplayMode,
        preselectedRelationships: [RoutineTaskRelationship] = [],
        excludingRelationshipTaskID: UUID? = nil
    ) -> AddRoutineFeature.State {
        AddRoutineFeature.State(
            organization: AddRoutineOrganizationState(
                relationships: preselectedRelationships,
                availableTags: HomeTaskSupport.availableTags(from: tasks),
                availableTagSummaries: RoutineTag.summaries(
                    from: tasks,
                    countsByTaskID: doneStats.countsByTaskID
                ),
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

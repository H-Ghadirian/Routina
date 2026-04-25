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
        let tagSummaries = AddRoutineOrganizationEditor.sortedTagSummaries(
            RoutineTag.summaries(
                from: tasks,
                countsByTaskID: doneStats.countsByTaskID
            )
        )
        return AddRoutineFeature.State(
            organization: AddRoutineOrganizationState(
                relationships: preselectedRelationships,
                availableTags: tagSummaries.map(\.name),
                availableTagSummaries: tagSummaries,
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

    static func makeRoutine(
        from request: AddRoutineSaveRequest,
        name: String,
        scheduleAnchor: Date
    ) -> RoutineTask {
        RoutineTask(
            name: name,
            emoji: request.emoji,
            notes: request.notes,
            link: request.link,
            deadline: request.deadline,
            priority: request.priority,
            importance: request.importance,
            urgency: request.urgency,
            imageData: request.imageData,
            placeID: request.selectedPlaceID,
            tags: request.tags,
            relationships: request.relationships,
            steps: request.steps,
            checklistItems: request.checklistItems,
            scheduleMode: request.scheduleMode,
            interval: Int16(request.frequencyInDays),
            recurrenceRule: request.recurrenceRule,
            lastDone: nil,
            scheduleAnchor: request.scheduleMode == .oneOff ? nil : scheduleAnchor,
            color: request.color,
            autoAssumeDailyDone: request.autoAssumeDailyDone,
            estimatedDurationMinutes: request.estimatedDurationMinutes,
            storyPoints: request.storyPoints
        )
    }

    static func makeAttachments(
        from request: AddRoutineSaveRequest,
        taskID: UUID
    ) -> [RoutineAttachment] {
        request.attachments.map { item in
            RoutineAttachment(
                id: item.id,
                taskID: taskID,
                fileName: item.fileName,
                data: item.data
            )
        }
    }
}

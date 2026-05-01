import ComposableArchitecture
import Foundation
import SwiftData

enum HomeAddRoutineSupport {
    static func makeAddRoutineState(
        tasks: [RoutineTask],
        places: [RoutinePlace],
        goals: [RoutineGoal],
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
                availableGoals: RoutineGoalSummary.summaries(from: goals),
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
        goalIDs: [UUID],
        scheduleAnchor: Date
    ) -> RoutineTask {
        RoutineTask(
            name: name,
            emoji: request.emoji,
            notes: request.notes,
            link: request.link,
            deadline: request.deadline,
            reminderAt: request.reminderAt,
            priority: request.priority,
            importance: request.importance,
            urgency: request.urgency,
            pressure: request.pressure,
            imageData: request.imageData,
            placeID: request.selectedPlaceID,
            tags: request.tags,
            goalIDs: goalIDs,
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
            storyPoints: request.storyPoints,
            focusModeEnabled: request.focusModeEnabled
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

    static func saveRoutine<Action>(
        from request: AddRoutineSaveRequest,
        scheduleAnchor: @escaping @MainActor @Sendable () -> Date,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        savedAction: @escaping @Sendable (RoutineTask) -> Action,
        failedAction: @escaping @Sendable () -> Action
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                guard let trimmedName = RoutineTask.trimmedName(request.name), !trimmedName.isEmpty else {
                    send(failedAction())
                    return
                }

                if try HomeDeduplicationSupport.hasDuplicateRoutineName(trimmedName, in: context) {
                    send(failedAction())
                    return
                }

                let goalIDs = try RoutineGoalPersistence.ensureGoals(request.goals, in: context)
                let newRoutine = makeRoutine(
                    from: request,
                    name: trimmedName,
                    goalIDs: goalIDs,
                    scheduleAnchor: scheduleAnchor()
                )
                context.insert(newRoutine)
                for attachment in makeAttachments(from: request, taskID: newRoutine.id) {
                    context.insert(attachment)
                }
                try context.save()
                send(savedAction(newRoutine))
            } catch {
                send(failedAction())
            }
        }
    }

    static func applySavedRoutine<Action>(
        _ task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar,
        tasks: inout [RoutineTask],
        presentation: inout HomePresentationState,
        scheduleNotification: @escaping @Sendable (NotificationPayload) async -> Void
    ) -> Effect<Action> {
        tasks.append(task.detachedCopy())
        presentation.isAddRoutineSheetPresented = false
        presentation.addRoutineState = nil
        NotificationCenter.default.postRoutineDidUpdate()

        guard NotificationCoordinator.shouldScheduleNotification(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        ) else {
            return .none
        }

        let payload = NotificationCoordinator.notificationPayload(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        return .run { _ in
            await scheduleNotification(payload)
        }
    }

    static func availabilityRefreshEffect<Action>(
        tasks: [RoutineTask],
        places: [RoutinePlace],
        goals: [RoutineGoal],
        doneStats: HomeDoneStats,
        action: @escaping (AddRoutineFeature.Action) -> Action
    ) -> Effect<Action> {
        .merge(
            .send(action(.existingRoutineNamesChanged(HomeTaskSupport.existingRoutineNames(from: tasks)))),
            .send(action(.availableTagSummariesChanged(
                RoutineTag.summaries(
                    from: tasks,
                    countsByTaskID: doneStats.countsByTaskID
                )
            ))),
            .send(action(.availablePlacesChanged(RoutinePlace.summaries(from: places, linkedTo: tasks)))),
            .send(action(.availableGoalsChanged(RoutineGoalSummary.summaries(from: goals)))),
            .send(action(.availableRelationshipTasksChanged(RoutineTaskRelationshipCandidate.from(tasks))))
        )
    }
}

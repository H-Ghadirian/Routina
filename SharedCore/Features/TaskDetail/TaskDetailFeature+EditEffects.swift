import ComposableArchitecture
import Foundation
import SwiftData

extension TaskDetailFeature {
    func handleEditSave(
        _ request: TaskDetailEditSaveRequest
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                switch try performEditSave(request) {
                case .missingTask:
                    return
                case .rejected(let task):
                    send(.editSaveRejected(task))
                case .saved(let task):
                    await refreshNotificationAfterEdit(for: task)
                    send(.onAppear)
                }
            } catch {
                RoutinaLog.error("Error saving routine edits: \(error)")
            }
        }
    }

    @MainActor
    private func performEditSave(
        _ request: TaskDetailEditSaveRequest
    ) throws -> TaskDetailEditSaveOutcome {
        let context = modelContext()
        let taskID = request.taskID
        guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else {
            return .missingTask
        }
        if try hasDuplicateRoutineName(request.name, in: context, excludingID: taskID) {
            return .rejected(task.detachedCopy())
        }

        let mutation = try prepareEditMutation(task: task, context: context)
        applyDescriptiveEdits(request, to: task)
        try synchronizeAttachments(request.attachments, for: taskID, context: context)
        try applyOrganizationEdits(request, to: mutation)
        applyScheduleEdits(request, to: task)
        applyHistoryAndScheduleAnchorEdits(request, to: mutation)
        try persistEditMutation(request, mutation: mutation)
        return .saved(task)
    }

    @MainActor
    private func prepareEditMutation(
        task: RoutineTask,
        context: ModelContext
    ) throws -> TaskDetailEditMutationContext {
        let allTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let relationshipCandidates = RoutineTaskRelationshipCandidate.from(
            allTasks,
            excluding: task.id,
            referenceDate: now,
            calendar: calendar
        )
        return TaskDetailEditMutationContext(
            modelContext: context,
            task: task,
            allTasks: allTasks,
            previousScheduleMode: task.scheduleMode,
            previousRecurrenceRule: task.recurrenceRule,
            previousRollingScheduleAnchor: task.scheduleAnchor ?? task.lastDone,
            previousTask: task.detachedCopy(),
            previousRelationships: RoutineTask.editableRelationships(
                for: task,
                within: relationshipCandidates
            ),
            previousActualDurationMinutes: task.actualDurationMinutes,
            previousCreatedAt: task.createdAt
        )
    }

    @MainActor
    private func synchronizeAttachments(
        _ attachments: [AttachmentItem],
        for taskID: UUID,
        context: ModelContext
    ) throws {
        let existingAttachments = try context.fetch(
            TaskDetailFetchDescriptors.attachments(for: taskID)
        )
        let newIDs = Set(attachments.map(\.id))
        for attachment in existingAttachments where !newIDs.contains(attachment.id) {
            context.delete(attachment)
        }

        let existingIDs = Set(existingAttachments.map(\.id))
        for item in attachments where !existingIDs.contains(item.id) {
            context.insert(
                RoutineAttachment(
                    id: item.id,
                    taskID: taskID,
                    fileName: item.fileName,
                    data: item.data
                )
            )
        }
    }

    @MainActor
    private func applyOrganizationEdits(
        _ request: TaskDetailEditSaveRequest,
        to mutation: TaskDetailEditMutationContext
    ) throws {
        let task = mutation.task
        task.placeIDs = RoutinePlaceIDStorage.sanitized(
            request.placeIDs.isEmpty ? request.placeID.map { [$0] } ?? [] : request.placeIDs
        )
        task.destinationAddress = RoutineTask.sanitizedDestinationAddress(
            request.destinationAddress
        )
        task.destinationCoordinate = request.destinationCoordinate
        task.tags = request.tags
        task.flags = request.flags
        task.goalIDs = try RoutineGoalPersistence.ensureGoals(
            request.goals,
            in: mutation.modelContext
        )
        task.eventIDs = RoutineEventIDStorage.sanitized(request.eventIDs)
        task.replaceRelationships(request.relationships)
        RoutineTask.removeInverseRelationships(targeting: task.id, from: mutation.allTasks)
        task.replaceSteps(request.steps)
    }

    private func applyScheduleEdits(
        _ request: TaskDetailEditSaveRequest,
        to task: RoutineTask
    ) {
        let scheduleMode = request.scheduleMode
        let recurrenceRule = request.recurrenceRule
        let cadenceEnabled = request.cadenceEnabled

        task.scheduleMode = scheduleMode
        task.deadline = scheduleMode.taskType == .todo ? request.deadline : nil
        task.isAllDay = request.isAllDay
        task.routineDurationMode =
            scheduleMode.taskType == .todo ? .oneDay : request.routineDurationMode
        let availabilityDateBounds = RoutineTask.normalizedAvailabilityDateBounds(
            startDate: request.availabilityStartDate,
            endDate: request.availabilityEndDate,
            calendar: calendar
        )
        task.availabilityStartDate =
            scheduleMode.taskType == .todo ? availabilityDateBounds.startDate : nil
        task.availabilityEndDate =
            scheduleMode.taskType == .todo ? availabilityDateBounds.endDate : nil
        task.plannedDate = RoutineTask.effectivePlannedDate(
            plannedDate: request.plannedDate,
            scheduleMode: scheduleMode,
            availabilityStartDate: availabilityDateBounds.startDate,
            availabilityEndDate: availabilityDateBounds.endDate,
            calendar: calendar
        )
        task.recurrenceRule = recurrenceRule
        task.recurrenceTimeRangeRole =
            recurrenceRule.timeRange == nil ? .availability : request.recurrenceTimeRangeRole
        task.replaceChecklistItems(request.checklistItems)
        if !task.usesOngoingLifecycle {
            task.activityState = .idle
            task.ongoingSince = nil
        }
        task.autoAssumeDailyDone =
            request.autoAssumeDailyDone
            && RoutineAssumedCompletion.canEnable(
                scheduleMode: scheduleMode,
                recurrenceRule: recurrenceRule,
                recurrenceTimeRangeRole: task.recurrenceTimeRangeRole,
                availabilityStartDate: task.availabilityStartDate,
                availabilityEndDate: task.availabilityEndDate,
                isAllDay: task.isAllDay,
                cadenceEnabled: cadenceEnabled,
                hasSequentialSteps: !request.steps.isEmpty,
                hasChecklistItems: !request.checklistItems.isEmpty
            )
        task.hidesAssumedDoneCalendarBlock =
            task.autoAssumeDailyDone && request.hidesAssumedDoneCalendarBlock
        task.autoAssumeDoneTimeOfDay =
            task.autoAssumeDailyDone
            ? (request.autoAssumeDoneTimeOfDay ?? RoutineAssumedCompletion.defaultDoneTimeOfDay)
            : nil
        task.estimatedDurationMinutes = RoutineTask.sanitizedEstimatedDurationMinutes(
            request.estimatedDurationMinutes
        )
        task.actualDurationMinutes =
            scheduleMode.taskType == .todo
            ? RoutineTask.sanitizedActualDurationMinutes(request.actualDurationMinutes)
            : nil
    }

    private func applyHistoryAndScheduleAnchorEdits(
        _ request: TaskDetailEditSaveRequest,
        to mutation: TaskDetailEditMutationContext
    ) {
        let task = mutation.task
        let scheduleMode = request.scheduleMode
        let recurrenceRule = request.recurrenceRule
        let cadenceEnabled = request.cadenceEnabled
        let scheduleChanged =
            mutation.previousScheduleMode != scheduleMode
            || mutation.previousRecurrenceRule != recurrenceRule

        task.createdAt = mutation.previousCreatedAt
        appendRelationshipChangeEntries(
            to: task,
            previousRelationships: mutation.previousRelationships,
            updatedRelationships: task.relationships
        )
        if mutation.previousActualDurationMinutes != task.actualDurationMinutes {
            task.appendChangeLogEntry(
                timeSpentChangeEntry(
                    previousDurationMinutes: mutation.previousActualDurationMinutes,
                    durationMinutes: task.actualDurationMinutes
                )
            )
        }
        task.storyPoints = RoutineTask.sanitizedStoryPoints(request.storyPoints)
        task.focusModeEnabled = request.focusModeEnabled
        task.cadenceEnabled = scheduleMode.taskType == .todo ? true : cadenceEnabled
        task.nudgesEnabled =
            scheduleMode.usesRoutineCadence ? cadenceEnabled && request.nudgesEnabled : true

        if scheduleChanged {
            task.lastSatisfiedScheduledOccurrenceAt = nil
        }
        guard scheduleMode.usesRoutineCadence, task.cadenceEnabled else {
            task.scheduleAnchor = task.lastDone
            task.interval = 1
            return
        }
        task.interval = Int16(clamping: recurrenceRule.approximateIntervalDays)
        if scheduleChanged {
            let canPreserveRollingAnchor =
                mutation.previousScheduleMode != .oneOff
                && mutation.previousRecurrenceRule.kind == .intervalDays
                && recurrenceRule.kind == .intervalDays
            let preservedAnchor =
                canPreserveRollingAnchor
                ? mutation.previousRollingScheduleAnchor
                : nil
            task.scheduleAnchor = preservedAnchor ?? now
        } else if task.scheduleAnchor == nil {
            task.scheduleAnchor = task.lastDone ?? task.createdAt
        }
    }

    @MainActor
    private func persistEditMutation(
        _ request: TaskDetailEditSaveRequest,
        mutation: TaskDetailEditMutationContext
    ) throws {
        let task = mutation.task
        _ = try DayPlanAutomaticBlockSync.rebaseAutomaticallyScheduledBlocks(
            from: mutation.previousTask,
            to: task,
            calendar: calendar,
            context: mutation.modelContext
        )
        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .task,
            entityID: task.id,
            entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
            in: mutation.modelContext
        )
        try mutation.modelContext.save()

        var organization = appSettingsClient.taskLadderOrganization()
        if organization.setTaskGroupEnabled(
            request.taskLadderGroupEnabled,
            taskID: task.id
        ) {
            appSettingsClient.setTaskLadderOrganization(organization)
        }
        NotificationCenter.default.postRoutineDidUpdate()
    }

    @MainActor
    private func refreshNotificationAfterEdit(for task: RoutineTask) async {
        guard
            NotificationCoordinator.shouldScheduleNotification(
                for: task,
                referenceDate: now,
                calendar: calendar
            )
        else {
            await notificationClient.cancel(task.id.uuidString)
            return
        }
        let payload = NotificationCoordinator.notificationPayload(
            for: task,
            referenceDate: now,
            calendar: calendar
        )
        await notificationClient.schedule(payload)
    }

    private func applyDescriptiveEdits(
        _ request: TaskDetailEditSaveRequest,
        to task: RoutineTask
    ) {
        task.name = request.name
        task.customTaskSectionID = request.customTaskSectionID
        task.emoji = request.emoji
        task.taskDescription = RoutineTask.sanitizedDescription(request.taskDescription)
        task.notes = CalendarTaskImportSupport.notesPreservingCalendarMarkers(
            visibleNotes: request.notes,
            existingNotes: task.notes
        )
        task.linkItems =
            request.linkItems.isEmpty
            ? (request.links.isEmpty
                ? request.link.map { [RoutineTaskLink(title: nil, url: $0)] } ?? []
                : request.links.map { RoutineTaskLink(title: nil, url: $0) })
            : request.linkItems
        task.reminderAt = request.reminderAt
        task.priority = request.priority
        task.importance = request.importance
        task.urgency = request.urgency
        task.pressure = request.pressure
        task.temporalWeightRule = RoutineTaskTemporalWeightResolver.sanitizedRule(
            request.temporalWeightRule,
            scheduleMode: request.scheduleMode,
            cadenceEnabled: request.scheduleMode.taskType == .todo
                ? true
                : request.cadenceEnabled,
            importance: request.importance,
            urgency: request.urgency,
            pressure: request.pressure,
            maximumBeforeDueDays: RoutineTaskTemporalWeightResolver.maximumBeforeDueDays(
                for: request.recurrenceRule
            )
        )
        task.taskLadderEntryWindow = RoutineTaskLadderEntryResolver.sanitizedWindow(
            request.taskLadderEntryWindow,
            scheduleMode: request.scheduleMode,
            cadenceEnabled: request.scheduleMode.taskType == .todo
                ? true
                : request.cadenceEnabled,
            hasDeadline: request.scheduleMode.taskType == .todo && request.deadline != nil,
            maximumBeforeDueDays: request.scheduleMode.taskType == .todo
                ? nil
                : RoutineTaskTemporalWeightResolver.maximumBeforeDueDays(
                    for: request.recurrenceRule
                )
        )
        task.thinkingNeeded = request.thinkingNeeded
        task.color = request.color
        task.imageData = request.imageData
        task.voiceNote = request.voiceNote
    }

}

private enum TaskDetailEditSaveOutcome {
    case missingTask
    case rejected(RoutineTask)
    case saved(RoutineTask)
}

private struct TaskDetailEditMutationContext {
    let modelContext: ModelContext
    let task: RoutineTask
    let allTasks: [RoutineTask]
    let previousScheduleMode: RoutineScheduleMode
    let previousRecurrenceRule: RoutineRecurrenceRule
    let previousRollingScheduleAnchor: Date?
    let previousTask: RoutineTask
    let previousRelationships: [RoutineTaskRelationship]
    let previousActualDurationMinutes: Int?
    let previousCreatedAt: Date?
}

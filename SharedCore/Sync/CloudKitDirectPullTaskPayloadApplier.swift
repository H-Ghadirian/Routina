import Foundation

enum CloudKitDirectPullTaskPayloadApplier {
    static func apply(
        _ payload: CloudKitDirectPullService.TaskPayload,
        to task: RoutineTask,
        updatesName: Bool
    ) {
        if updatesName {
            task.name = RoutineTask.trimmedName(payload.name)
        }
        task.emoji = payload.emoji
        task.notes = RoutineTask.sanitizedNotes(payload.notes)
        task.links = payload.links ?? payload.link.map { [$0] } ?? []
        task.imageData = payload.imageData
        task.voiceNoteData = payload.voiceNoteData
        task.voiceNoteDurationSeconds = payload.voiceNoteDurationSeconds
        task.voiceNoteCreatedAt = payload.voiceNoteCreatedAt
        task.placeIDs = payload.placeIDs ?? payload.placeID.map { [$0] } ?? []
        if let tags = payload.tags {
            task.tags = tags
        }
        if let goalIDs = payload.goalIDs {
            task.goalIDs = goalIDs
        }
        if let eventIDs = payload.eventIDs {
            task.eventIDs = eventIDs
        }
        if let steps = payload.steps {
            task.replaceSteps(steps)
        }
        if let checklistItems = payload.checklistItems {
            task.replaceChecklistItems(checklistItems)
        }
        if let scheduleMode = payload.scheduleMode {
            task.scheduleMode = scheduleMode
        }
        task.deadline = task.scheduleMode == .oneOff ? payload.deadline : nil
        if let isAllDay = payload.isAllDay {
            task.isAllDay = isAllDay
        }
        let availabilityDateBounds = RoutineTask.normalizedAvailabilityDateBounds(
            startDate: payload.availabilityStartDate,
            endDate: payload.availabilityEndDate
        )
        task.availabilityStartDate = task.scheduleMode == .oneOff ? availabilityDateBounds.startDate : nil
        task.availabilityEndDate = task.scheduleMode == .oneOff ? availabilityDateBounds.endDate : nil
        task.reminderAt = payload.reminderAt
        if let recurrenceRule = payload.recurrenceRule {
            task.recurrenceRule = recurrenceRule
        } else {
            task.recurrenceRule = .interval(days: max(Int(payload.interval), 1))
        }
        task.lastDone = payload.lastDone
        task.canceledAt = payload.canceledAt
        task.scheduleAnchor = payload.scheduleAnchor ?? payload.lastDone ?? task.scheduleAnchor
        task.pausedAt = payload.pausedAt
        task.snoozedUntil = payload.snoozedUntil
        task.pinnedAt = payload.pinnedAt
        task.completedStepCount = payload.completedStepCount
        task.sequenceStartedAt = payload.sequenceStartedAt
        if let createdAt = payload.createdAt {
            task.createdAt = createdAt
        }
        if let todoStateRawValue = payload.todoStateRawValue {
            task.todoStateRawValue = todoStateRawValue
        }
        if let activityStateRawValue = payload.activityStateRawValue {
            task.activityStateRawValue = activityStateRawValue
        }
        task.ongoingSince = payload.ongoingSince
        if let autoAssumeDailyDone = payload.autoAssumeDailyDone {
            task.autoAssumeDailyDone = autoAssumeDailyDone
        }
        if let estimatedDurationMinutes = payload.estimatedDurationMinutes {
            task.estimatedDurationMinutes = RoutineTask.sanitizedEstimatedDurationMinutes(estimatedDurationMinutes)
        }
        if let actualDurationMinutes = payload.actualDurationMinutes {
            task.actualDurationMinutes = RoutineTask.sanitizedActualDurationMinutes(actualDurationMinutes)
        }
        if let storyPoints = payload.storyPoints {
            task.storyPoints = RoutineTask.sanitizedStoryPoints(storyPoints)
        }
        if let pressure = payload.pressure {
            task.pressure = pressure
            task.pressureUpdatedAt = payload.pressureUpdatedAt
        }
        if let comments = payload.comments {
            task.comments = comments
        }
    }

    static func makeTask(from payload: CloudKitDirectPullService.TaskPayload) -> RoutineTask {
        RoutineTask(
            id: payload.id,
            name: RoutineTask.trimmedName(payload.name),
            emoji: payload.emoji,
            notes: payload.notes,
            link: payload.link,
            links: payload.links ?? payload.link.map { [$0] } ?? [],
            deadline: payload.deadline,
            isAllDay: payload.isAllDay ?? false,
            availabilityStartDate: payload.availabilityStartDate,
            availabilityEndDate: payload.availabilityEndDate,
            reminderAt: payload.reminderAt,
            pressure: payload.pressure ?? .none,
            pressureUpdatedAt: payload.pressureUpdatedAt,
            imageData: payload.imageData,
            voiceNoteData: payload.voiceNoteData,
            voiceNoteDurationSeconds: payload.voiceNoteDurationSeconds,
            voiceNoteCreatedAt: payload.voiceNoteCreatedAt,
            placeID: payload.placeID,
            placeIDs: payload.placeIDs ?? payload.placeID.map { [$0] } ?? [],
            tags: payload.tags ?? [],
            goalIDs: payload.goalIDs ?? [],
            eventIDs: payload.eventIDs ?? [],
            steps: payload.steps ?? [],
            checklistItems: payload.checklistItems ?? [],
            scheduleMode: payload.scheduleMode,
            interval: payload.interval,
            recurrenceRule: payload.recurrenceRule,
            lastDone: payload.lastDone,
            canceledAt: payload.canceledAt,
            scheduleAnchor: payload.scheduleAnchor,
            pausedAt: payload.pausedAt,
            snoozedUntil: payload.snoozedUntil,
            pinnedAt: payload.pinnedAt,
            completedStepCount: payload.completedStepCount,
            sequenceStartedAt: payload.sequenceStartedAt,
            createdAt: payload.createdAt,
            todoStateRawValue: payload.todoStateRawValue,
            activityStateRawValue: payload.activityStateRawValue,
            ongoingSince: payload.ongoingSince,
            autoAssumeDailyDone: payload.autoAssumeDailyDone ?? false,
            estimatedDurationMinutes: payload.estimatedDurationMinutes,
            actualDurationMinutes: payload.actualDurationMinutes,
            storyPoints: payload.storyPoints,
            comments: payload.comments ?? []
        )
    }
}

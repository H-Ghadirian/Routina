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
        task.link = RoutineTask.sanitizedLink(payload.link)
        task.imageData = payload.imageData
        task.placeID = payload.placeID
        if let tags = payload.tags {
            task.tags = tags
        }
        if let goalIDs = payload.goalIDs {
            task.goalIDs = goalIDs
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
        task.reminderAt = payload.reminderAt
        if let recurrenceRule = payload.recurrenceRule {
            task.recurrenceRule = recurrenceRule
        } else {
            task.interval = payload.interval
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
    }

    static func makeTask(from payload: CloudKitDirectPullService.TaskPayload) -> RoutineTask {
        RoutineTask(
            id: payload.id,
            name: RoutineTask.trimmedName(payload.name),
            emoji: payload.emoji,
            notes: payload.notes,
            link: payload.link,
            deadline: payload.deadline,
            reminderAt: payload.reminderAt,
            pressure: payload.pressure ?? .none,
            pressureUpdatedAt: payload.pressureUpdatedAt,
            imageData: payload.imageData,
            placeID: payload.placeID,
            tags: payload.tags ?? [],
            goalIDs: payload.goalIDs ?? [],
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
            storyPoints: payload.storyPoints
        )
    }
}

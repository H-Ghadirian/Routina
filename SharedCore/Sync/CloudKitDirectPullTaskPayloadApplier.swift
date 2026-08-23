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
        task.taskDescription = RoutineTask.sanitizedDescription(payload.taskDescription)
        task.notes = RoutineTask.sanitizedNotes(payload.notes)
        task.linkItems = payload.linkItems
            ?? payload.links?.map { RoutineTaskLink(title: nil, url: $0) }
            ?? payload.link.map { [RoutineTaskLink(title: nil, url: $0)] }
            ?? []
        task.imageData = payload.imageData
        task.voiceNoteData = payload.voiceNoteData
        task.voiceNoteDurationSeconds = payload.voiceNoteDurationSeconds
        task.voiceNoteCreatedAt = payload.voiceNoteCreatedAt
        task.placeIDs = payload.placeIDs ?? payload.placeID.map { [$0] } ?? []
        task.destinationAddress = RoutineTask.sanitizedDestinationAddress(payload.destinationAddress)
        let destinationCoordinate = RoutineTask.sanitizedDestinationCoordinate(
            latitude: payload.destinationLatitude,
            longitude: payload.destinationLongitude
        )
        task.destinationLatitude = destinationCoordinate?.latitude
        task.destinationLongitude = destinationCoordinate?.longitude
        if let tags = payload.tags {
            task.tags = tags
        }
        if let flags = payload.flags {
            task.flags = flags
        }
        if let goalIDs = payload.goalIDs {
            task.goalIDs = goalIDs
        }
        if let eventIDs = payload.eventIDs {
            task.eventIDs = eventIDs
        }
        if let relationships = payload.relationships {
            task.replaceRelationships(relationships)
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
        let availabilityDateBounds = RoutineTask.normalizedAvailabilityDateBounds(
            startDate: payload.availabilityStartDate,
            endDate: payload.availabilityEndDate
        )
        task.deadline = task.scheduleMode == .oneOff ? payload.deadline : nil
        task.plannedDate = RoutineTask.effectivePlannedDate(
            plannedDate: payload.plannedDate,
            scheduleMode: task.scheduleMode,
            availabilityStartDate: availabilityDateBounds.startDate,
            availabilityEndDate: availabilityDateBounds.endDate
        )
        if let isAllDay = payload.isAllDay {
            task.isAllDay = isAllDay
        }
        task.routineDurationMode = task.scheduleMode == .oneOff
            ? .oneDay
            : (payload.routineDurationMode ?? .oneDay)
        task.availabilityStartDate = task.scheduleMode == .oneOff ? availabilityDateBounds.startDate : nil
        task.availabilityEndDate = task.scheduleMode == .oneOff ? availabilityDateBounds.endDate : nil
        task.reminderAt = payload.reminderAt
        if let recurrenceRule = payload.recurrenceRule {
            task.recurrenceRule = recurrenceRule
        } else {
            task.recurrenceRule = .interval(days: max(Int(payload.interval), 1))
        }
        task.recurrenceTimeRangeRole = task.recurrenceRule.timeRange == nil
            ? .availability
            : (payload.recurrenceTimeRangeRole ?? .availability)
        task.lastDone = payload.lastDone
        task.lastSatisfiedScheduledOccurrenceAt = payload.lastSatisfiedScheduledOccurrenceAt
        task.canceledAt = payload.canceledAt
        task.scheduleAnchor = payload.scheduleAnchor ?? payload.lastDone ?? task.scheduleAnchor
        task.pausedAt = payload.pausedAt
        task.pauseUntil = payload.pauseUntil
        task.snoozedUntil = payload.snoozedUntil
        task.pinnedAt = payload.pinnedAt
        if let taskRankingOrderStorage = payload.taskRankingOrderStorage {
            task.taskRankingOrderStorage = taskRankingOrderStorage
        }
        if let temporalWeightRuleStorage = payload.temporalWeightRuleStorage {
            task.temporalWeightRuleStorage = temporalWeightRuleStorage
        }
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
            if !autoAssumeDailyDone {
                task.hidesAssumedDoneCalendarBlock = false
            }
        }
        if let hidesAssumedDoneCalendarBlock = payload.hidesAssumedDoneCalendarBlock {
            task.hidesAssumedDoneCalendarBlock = hidesAssumedDoneCalendarBlock
                && task.autoAssumeDailyDone
        }
        if payload.autoAssumeDoneTimeOfDayHour != nil || payload.autoAssumeDoneTimeOfDayMinute != nil {
            task.autoAssumeDoneTimeOfDay = RoutineTimeOfDay(
                hour: payload.autoAssumeDoneTimeOfDayHour ?? RoutineAssumedCompletion.defaultDoneTimeOfDay.hour,
                minute: payload.autoAssumeDoneTimeOfDayMinute ?? RoutineAssumedCompletion.defaultDoneTimeOfDay.minute
            )
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
        if let cadenceEnabled = payload.cadenceEnabled {
            task.cadenceEnabled = task.scheduleMode.taskType == .todo
                ? true
                : cadenceEnabled
        }
        if let nudgesEnabled = payload.nudgesEnabled {
            task.nudgesEnabled = task.scheduleMode.usesRoutineCadence
                ? task.cadenceEnabled && nudgesEnabled
                : true
        }
        if let autoPauseAfterCompletion = payload.autoPauseAfterCompletion {
            task.autoPauseAfterCompletion = task.scheduleMode.taskType != .todo
                && !task.cadenceEnabled
                && autoPauseAfterCompletion
        }
        if let pressure = payload.pressure {
            task.pressure = pressure
            task.pressureUpdatedAt = payload.pressureUpdatedAt
        }
        if let thinkingNeeded = payload.thinkingNeeded {
            task.thinkingNeeded = thinkingNeeded
        }
        if let comments = payload.comments {
            task.comments = comments
        }
    }

    static func makeTask(from payload: CloudKitDirectPullService.TaskPayload) -> RoutineTask {
        let resolvedCadenceEnabled = payload.cadenceEnabled ?? true
        let resolvedNudgesEnabled = payload.nudgesEnabled ?? true
        let resolvedAutoPauseAfterCompletion = payload.autoPauseAfterCompletion ?? false
        let resolvedAutoAssumeDoneTimeOfDay: RoutineTimeOfDay? = payload.autoAssumeDoneTimeOfDayHour != nil || payload.autoAssumeDoneTimeOfDayMinute != nil
            ? RoutineTimeOfDay(
                hour: payload.autoAssumeDoneTimeOfDayHour ?? RoutineAssumedCompletion.defaultDoneTimeOfDay.hour,
                minute: payload.autoAssumeDoneTimeOfDayMinute ?? RoutineAssumedCompletion.defaultDoneTimeOfDay.minute
            )
            : nil
        let task = RoutineTask(
            id: payload.id,
            name: RoutineTask.trimmedName(payload.name),
            emoji: payload.emoji,
            taskDescription: payload.taskDescription,
            notes: payload.notes,
            link: payload.link,
            links: payload.links ?? payload.link.map { [$0] } ?? [],
            deadline: payload.deadline,
            plannedDate: payload.plannedDate,
            isAllDay: payload.isAllDay ?? false,
            routineDurationMode: payload.scheduleMode == .oneOff
                ? .oneDay
                : (payload.routineDurationMode ?? .oneDay),
            availabilityStartDate: payload.availabilityStartDate,
            availabilityEndDate: payload.availabilityEndDate,
            reminderAt: payload.reminderAt,
            pressure: payload.pressure ?? .none,
            pressureUpdatedAt: payload.pressureUpdatedAt,
            thinkingNeeded: payload.thinkingNeeded ?? .none,
            imageData: payload.imageData,
            voiceNoteData: payload.voiceNoteData,
            voiceNoteDurationSeconds: payload.voiceNoteDurationSeconds,
            voiceNoteCreatedAt: payload.voiceNoteCreatedAt,
            placeID: payload.placeID,
            placeIDs: payload.placeIDs ?? payload.placeID.map { [$0] } ?? [],
            destinationAddress: payload.destinationAddress,
            destinationLatitude: payload.destinationLatitude,
            destinationLongitude: payload.destinationLongitude,
            tags: payload.tags ?? [],
            flags: payload.flags ?? [],
            goalIDs: payload.goalIDs ?? [],
            eventIDs: payload.eventIDs ?? [],
            relationships: payload.relationships ?? [],
            steps: payload.steps ?? [],
            checklistItems: payload.checklistItems ?? [],
            scheduleMode: payload.scheduleMode,
            interval: payload.interval,
            recurrenceRule: payload.recurrenceRule,
            recurrenceTimeRangeRole: payload.recurrenceTimeRangeRole ?? .availability,
            lastDone: payload.lastDone,
            lastSatisfiedScheduledOccurrenceAt: payload.lastSatisfiedScheduledOccurrenceAt,
            canceledAt: payload.canceledAt,
            scheduleAnchor: payload.scheduleAnchor,
            pausedAt: payload.pausedAt,
            pauseUntil: payload.pauseUntil,
            snoozedUntil: payload.snoozedUntil,
            pinnedAt: payload.pinnedAt,
            completedStepCount: payload.completedStepCount,
            sequenceStartedAt: payload.sequenceStartedAt,
            createdAt: payload.createdAt,
            todoStateRawValue: payload.todoStateRawValue,
            activityStateRawValue: payload.activityStateRawValue,
            ongoingSince: payload.ongoingSince,
            autoAssumeDailyDone: payload.autoAssumeDailyDone ?? false,
            hidesAssumedDoneCalendarBlock: payload.hidesAssumedDoneCalendarBlock ?? false,
            autoAssumeDoneTimeOfDay: resolvedAutoAssumeDoneTimeOfDay,
            estimatedDurationMinutes: payload.estimatedDurationMinutes,
            actualDurationMinutes: payload.actualDurationMinutes,
            storyPoints: payload.storyPoints,
            cadenceEnabled: resolvedCadenceEnabled,
            nudgesEnabled: resolvedNudgesEnabled,
            comments: payload.comments ?? []
        )
        task.autoPauseAfterCompletion = task.scheduleMode.taskType != .todo
            && !task.cadenceEnabled
            && resolvedAutoPauseAfterCompletion
        task.taskRankingOrderStorage = payload.taskRankingOrderStorage ?? ""
        task.temporalWeightRuleStorage = payload.temporalWeightRuleStorage ?? ""
        task.linkItems = payload.linkItems
            ?? payload.links?.map { RoutineTaskLink(title: nil, url: $0) }
            ?? payload.link.map { [RoutineTaskLink(title: nil, url: $0)] }
            ?? []
        return task
    }
}

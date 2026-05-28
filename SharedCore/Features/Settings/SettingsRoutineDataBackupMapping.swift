import Foundation

enum SettingsRoutineDataBackupMapping {
    typealias Backup = SettingsRoutineDataPersistence.Backup

    static func place(_ place: RoutinePlace) -> Backup.Place {
        Backup.Place(
            id: place.id,
            name: place.displayName,
            latitude: place.latitude,
            longitude: place.longitude,
            radiusMeters: place.radiusMeters,
            createdAt: place.createdAt
        )
    }

    static func goal(_ goal: RoutineGoal) -> Backup.Goal {
        Backup.Goal(
            id: goal.id,
            title: goal.displayTitle,
            emoji: goal.emoji,
            notes: goal.notes,
            targetDate: goal.targetDate,
            tags: goal.tags,
            status: goal.status,
            color: goal.color,
            parentGoalID: goal.parentGoalID,
            rejectedTaskSuggestionIDs: goal.rejectedTaskSuggestionIDs,
            createdAt: goal.createdAt,
            sortOrder: goal.sortOrder
        )
    }

    static func task(
        _ task: RoutineTask,
        imageData: Data?,
        imageAttachmentID: UUID?,
        voiceNoteData: Data?,
        voiceNoteAttachmentID: UUID?,
        includesPressure: Bool
    ) -> Backup.Task {
        Backup.Task(
            id: task.id,
            name: task.name,
            emoji: task.emoji,
            notes: task.notes,
            link: task.link,
            deadline: task.deadline,
            isAllDay: task.isAllDay,
            reminderAt: task.reminderAt,
            imageData: imageData,
            imageAttachmentID: imageAttachmentID,
            voiceNoteData: voiceNoteData,
            voiceNoteAttachmentID: voiceNoteAttachmentID,
            voiceNoteDurationSeconds: task.voiceNoteDurationSeconds,
            voiceNoteCreatedAt: task.voiceNoteCreatedAt,
            placeID: task.placeID,
            tags: task.tags,
            goalIDs: task.goalIDs,
            steps: task.steps,
            checklistItems: task.checklistItems,
            scheduleMode: task.scheduleMode,
            interval: max(Int(task.interval), 1),
            recurrenceRule: task.recurrenceRule,
            lastDone: task.lastDone,
            canceledAt: task.canceledAt,
            scheduleAnchor: task.scheduleAnchor,
            pausedAt: task.pausedAt,
            snoozedUntil: task.snoozedUntil,
            pinnedAt: task.pinnedAt,
            completedStepCount: task.completedSteps,
            sequenceStartedAt: task.sequenceStartedAt,
            createdAt: task.createdAt,
            todoStateRawValue: task.todoStateRawValue,
            activityStateRawValue: task.activityStateRawValue,
            ongoingSince: task.ongoingSince,
            autoAssumeDailyDone: task.autoAssumeDailyDone,
            estimatedDurationMinutes: task.estimatedDurationMinutes,
            actualDurationMinutes: task.actualDurationMinutes,
            storyPoints: task.storyPoints,
            pressure: includesPressure ? task.pressure : nil,
            pressureUpdatedAt: includesPressure ? task.pressureUpdatedAt : nil,
            comments: task.comments
        )
    }

    static func log(_ log: RoutineLog) -> Backup.Log {
        Backup.Log(
            id: log.id,
            timestamp: log.timestamp,
            taskID: log.taskID,
            kind: log.kind,
            actualDurationMinutes: log.actualDurationMinutes
        )
    }

    static func sleep(_ session: SleepSession) -> Backup.Sleep {
        Backup.Sleep(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            targetDurationMinutes: session.targetDurationMinutes,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt
        )
    }

    static func placeCheckIn(
        _ session: PlaceCheckInSession,
        imageData: Data?,
        imageAttachmentID: UUID?
    ) -> Backup.PlaceCheckIn {
        Backup.PlaceCheckIn(
            id: session.id,
            placeID: session.placeID,
            placeName: session.displayPlaceName,
            latitude: session.latitude,
            longitude: session.longitude,
            horizontalAccuracyMeters: session.horizontalAccuracyMeters,
            placeRadiusMeters: session.placeRadiusMeters,
            activity: session.activity,
            note: session.note,
            imageData: imageData,
            imageAttachmentID: imageAttachmentID,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt,
            captureMode: session.captureMode,
            confirmedAt: session.confirmedAt
        )
    }

    static func emotion(_ emotion: EmotionLog) -> Backup.Emotion {
        Backup.Emotion(
            id: emotion.id,
            family: emotion.family,
            label: emotion.primaryDisplayLabel,
            families: emotion.families,
            labels: emotion.displayLabels,
            valence: emotion.valence,
            arousal: emotion.arousal,
            intensity: emotion.clampedIntensity,
            bodyAreas: emotion.bodyAreas,
            reflection: emotion.reflection,
            linkedNoteID: emotion.linkedNoteID,
            linkedGoalID: emotion.linkedGoalID,
            linkedTaskID: emotion.linkedTaskID,
            linkedPlaceID: emotion.linkedPlaceID,
            linkedSleepSessionID: emotion.linkedSleepSessionID,
            createdAt: emotion.createdAt,
            updatedAt: emotion.updatedAt
        )
    }

    static func note(
        _ note: RoutineNote,
        imageData: Data?,
        imageAttachmentID: UUID?,
        voiceNoteData: Data?,
        voiceNoteAttachmentID: UUID?
    ) -> Backup.Note {
        Backup.Note(
            id: note.id,
            title: note.title,
            body: note.body,
            tags: note.tags,
            imageData: imageData,
            imageAttachmentID: imageAttachmentID,
            voiceNoteData: voiceNoteData,
            voiceNoteAttachmentID: voiceNoteAttachmentID,
            voiceNoteDurationSeconds: note.voiceNoteDurationSeconds,
            voiceNoteCreatedAt: note.voiceNoteCreatedAt,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt
        )
    }

    static func event(_ event: RoutineEvent) -> Backup.Event {
        Backup.Event(
            id: event.id,
            title: event.title,
            notes: event.notes,
            emoji: event.emoji,
            tags: event.tags,
            isAllDay: event.isAllDay,
            startedAt: event.startedAt,
            endedAt: event.endedAt,
            createdAt: event.createdAt,
            updatedAt: event.updatedAt
        )
    }
}

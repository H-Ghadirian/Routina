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
            status: goal.status,
            color: goal.color,
            createdAt: goal.createdAt,
            sortOrder: goal.sortOrder
        )
    }

    static func task(
        _ task: RoutineTask,
        imageData: Data?,
        imageAttachmentID: UUID?,
        includesPressure: Bool
    ) -> Backup.Task {
        Backup.Task(
            id: task.id,
            name: task.name,
            emoji: task.emoji,
            notes: task.notes,
            link: task.link,
            deadline: task.deadline,
            reminderAt: task.reminderAt,
            imageData: imageData,
            imageAttachmentID: imageAttachmentID,
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
            pressureUpdatedAt: includesPressure ? task.pressureUpdatedAt : nil
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
}

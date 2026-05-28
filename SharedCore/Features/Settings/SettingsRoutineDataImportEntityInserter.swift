import Foundation
import SwiftData

enum SettingsRoutineDataImportEntityInserter {
    typealias Backup = SettingsRoutineDataPersistence.Backup
    typealias ImportSummary = SettingsRoutineDataPersistence.ImportSummary

    @MainActor
    static func insertBackup(
        _ backup: Backup,
        attachmentData: (String) throws -> Data?,
        in context: ModelContext,
        importDate: Date
    ) throws -> ImportSummary {
        let places = insertPlaces(from: backup, in: context, importDate: importDate)
        let goals = insertGoals(from: backup, in: context, importDate: importDate)
        let tasks = try insertTasks(
            from: backup,
            attachmentData: attachmentData,
            importedPlaceIDs: places.ids,
            importedGoalIDs: goals.ids,
            in: context,
            importDate: importDate
        )
        let taskAttachmentCount = try insertFileAttachments(
            from: backup,
            attachmentData: attachmentData,
            importedTaskIDs: tasks.ids,
            in: context,
            importDate: importDate
        )
        let logCount = insertLogs(
            from: backup,
            importedTaskIDs: tasks.ids,
            in: context
        )
        let sleepSessions = insertSleepSessions(from: backup, in: context)
        let placeCheckInCount = try insertPlaceCheckInSessions(
            from: backup,
            attachmentData: attachmentData,
            importedPlaceIDs: places.ids,
            in: context
        )
        let notes = try insertNotes(
            from: backup,
            attachmentData: attachmentData,
            in: context,
            importDate: importDate
        )
        let eventCount = insertEvents(
            from: backup,
            in: context,
            importDate: importDate
        )
        let emotionLogCount = insertEmotionLogs(
            from: backup,
            importedNoteIDs: notes.ids,
            importedGoalIDs: goals.ids,
            importedTaskIDs: tasks.ids,
            importedPlaceIDs: places.ids,
            importedSleepSessionIDs: sleepSessions.ids,
            in: context
        )
        let noteAttachmentCount = try insertNoteFileAttachments(
            from: backup,
            attachmentData: attachmentData,
            importedNoteIDs: notes.ids,
            in: context,
            importDate: importDate
        )

        return ImportSummary(
            places: places.count,
            goals: goals.count,
            tasks: tasks.count,
            logs: logCount,
            sleepSessions: sleepSessions.count,
            placeCheckInSessions: placeCheckInCount,
            emotionLogs: emotionLogCount,
            notes: notes.count,
            events: eventCount,
            attachments: taskAttachmentCount + noteAttachmentCount
        )
    }

    @MainActor
    private static func insertPlaces(
        from backup: Backup,
        in context: ModelContext,
        importDate: Date
    ) -> (ids: Set<UUID>, count: Int) {
        var importedIDs = Set<UUID>()
        var importedCount = 0
        for place in backup.places ?? [] {
            guard importedIDs.insert(place.id).inserted else { continue }

            let importedPlace = RoutinePlace(
                id: place.id,
                name: place.name,
                latitude: place.latitude,
                longitude: place.longitude,
                radiusMeters: place.radiusMeters,
                createdAt: place.createdAt ?? importDate
            )
            context.insert(importedPlace)
            importedCount += 1
        }
        return (importedIDs, importedCount)
    }

    @MainActor
    private static func insertGoals(
        from backup: Backup,
        in context: ModelContext,
        importDate: Date
    ) -> (ids: Set<UUID>, count: Int) {
        let validGoalIDs = Set(
            (backup.goals ?? [])
                .filter { RoutineGoal.cleanedTitle($0.title) != nil }
                .map(\.id)
        )
        var importedIDs = Set<UUID>()
        var importedCount = 0
        var importedGoals: [RoutineGoal] = []
        for goal in backup.goals ?? [] {
            guard RoutineGoal.cleanedTitle(goal.title) != nil else { continue }
            guard importedIDs.insert(goal.id).inserted else { continue }
            let parentGoalID = goal.parentGoalID.flatMap { parentID in
                validGoalIDs.contains(parentID) && parentID != goal.id ? parentID : nil
            }

            let importedGoal = RoutineGoal(
                id: goal.id,
                title: goal.title,
                emoji: goal.emoji,
                notes: goal.notes,
                targetDate: goal.targetDate,
                tags: goal.tags ?? [],
                status: goal.status ?? .active,
                color: goal.color ?? .none,
                parentGoalID: parentGoalID,
                rejectedTaskSuggestionIDs: goal.rejectedTaskSuggestionIDs ?? [],
                createdAt: goal.createdAt ?? importDate,
                sortOrder: goal.sortOrder ?? importedCount
            )
            context.insert(importedGoal)
            importedGoals.append(importedGoal)
            importedCount += 1
        }
        for goal in importedGoals where goal.parentGoalID != nil {
            goal.parentGoalID = RoutineGoalHierarchy.sanitizedParentGoalID(
                goal.parentGoalID,
                for: goal.id,
                in: importedGoals,
                id: { $0.id },
                parentGoalID: { $0.parentGoalID }
            )
        }
        return (importedIDs, importedCount)
    }

    @MainActor
    private static func insertTasks(
        from backup: Backup,
        attachmentData: (String) throws -> Data?,
        importedPlaceIDs: Set<UUID>,
        importedGoalIDs: Set<UUID>,
        in context: ModelContext,
        importDate: Date
    ) throws -> (ids: Set<UUID>, count: Int) {
        var importedIDs = Set<UUID>()
        var importedCount = 0
        var attachmentManifestsByID: [UUID: Backup.Attachment] = [:]
        for attachment in backup.attachments ?? [] {
            attachmentManifestsByID[attachment.id] = attachment
        }

        for task in backup.tasks {
            guard importedIDs.insert(task.id).inserted else { continue }

            let imageData = try importedImageData(
                for: task,
                attachmentManifestsByID: attachmentManifestsByID,
                attachmentData: attachmentData
            )
            let voiceNoteData = try importedVoiceNoteData(
                for: task,
                attachmentManifestsByID: attachmentManifestsByID,
                attachmentData: attachmentData
            )

            let importedTask = RoutineTask(
                id: task.id,
                name: task.name,
                emoji: task.emoji,
                notes: task.notes,
                link: task.link,
                deadline: task.deadline,
                isAllDay: task.isAllDay ?? false,
                reminderAt: task.reminderAt,
                pressure: task.pressure ?? .none,
                pressureUpdatedAt: task.pressureUpdatedAt,
                imageData: imageData,
                voiceNoteData: voiceNoteData,
                voiceNoteDurationSeconds: task.voiceNoteDurationSeconds,
                voiceNoteCreatedAt: task.voiceNoteCreatedAt,
                placeID: task.placeID.flatMap { importedPlaceIDs.contains($0) ? $0 : nil },
                tags: task.tags ?? [],
                goalIDs: (task.goalIDs ?? []).filter { importedGoalIDs.contains($0) },
                steps: task.steps ?? [],
                checklistItems: task.checklistItems ?? [],
                scheduleMode: task.scheduleMode,
                interval: Int16(clampedInterval(task.interval)),
                recurrenceRule: task.recurrenceRule,
                lastDone: task.lastDone,
                canceledAt: task.canceledAt,
                scheduleAnchor: task.scheduleAnchor,
                pausedAt: task.pausedAt,
                snoozedUntil: task.snoozedUntil,
                pinnedAt: task.pinnedAt,
                completedStepCount: Int16(clamping: task.completedStepCount ?? 0),
                sequenceStartedAt: task.sequenceStartedAt,
                createdAt: task.createdAt,
                todoStateRawValue: task.todoStateRawValue,
                activityStateRawValue: task.activityStateRawValue,
                ongoingSince: task.ongoingSince,
                autoAssumeDailyDone: task.autoAssumeDailyDone ?? false,
                estimatedDurationMinutes: task.estimatedDurationMinutes,
                actualDurationMinutes: task.actualDurationMinutes,
                storyPoints: task.storyPoints,
                comments: task.comments ?? []
            )
            context.insert(importedTask)
            importedCount += 1
        }
        return (importedIDs, importedCount)
    }

    private static func importedImageData(
        for task: Backup.Task,
        attachmentManifestsByID: [UUID: Backup.Attachment],
        attachmentData: (String) throws -> Data?
    ) throws -> Data? {
        guard let imageAttachmentID = task.imageAttachmentID,
              let imageAttachment = attachmentManifestsByID[imageAttachmentID] else {
            return task.imageData
        }

        guard let data = try attachmentData(imageAttachment.fileName) else {
            throw SettingsRoutineDataPersistence.Error.missingAttachment(imageAttachment.fileName)
        }
        return data
    }

    private static func importedVoiceNoteData(
        for task: Backup.Task,
        attachmentManifestsByID: [UUID: Backup.Attachment],
        attachmentData: (String) throws -> Data?
    ) throws -> Data? {
        guard let voiceNoteAttachmentID = task.voiceNoteAttachmentID,
              let voiceNoteAttachment = attachmentManifestsByID[voiceNoteAttachmentID] else {
            return task.voiceNoteData
        }

        guard let data = try attachmentData(voiceNoteAttachment.fileName) else {
            throw SettingsRoutineDataPersistence.Error.missingAttachment(voiceNoteAttachment.fileName)
        }
        return data
    }

    @MainActor
    private static func insertFileAttachments(
        from backup: Backup,
        attachmentData: (String) throws -> Data?,
        importedTaskIDs: Set<UUID>,
        in context: ModelContext,
        importDate: Date
    ) throws -> Int {
        var importedIDs = Set<UUID>()
        var importedCount = 0
        for attachment in backup.attachments ?? [] where attachment.role == .fileAttachment {
            guard let taskID = attachment.taskID,
                  importedTaskIDs.contains(taskID)
            else { continue }
            guard importedIDs.insert(attachment.id).inserted else { continue }
            guard let data = try attachmentData(attachment.fileName) else {
                if backup.schemaVersion >= SettingsRoutineDataPersistence.currentSchemaVersion {
                    throw SettingsRoutineDataPersistence.Error.missingAttachment(attachment.fileName)
                }
                continue
            }

            let importedAttachment = RoutineAttachment(
                id: attachment.id,
                taskID: taskID,
                fileName: attachment.originalFileName ?? attachment.fileName,
                data: data,
                createdAt: attachment.createdAt ?? importDate
            )
            context.insert(importedAttachment)
            importedCount += 1
        }
        return importedCount
    }

    @MainActor
    private static func insertLogs(
        from backup: Backup,
        importedTaskIDs: Set<UUID>,
        in context: ModelContext
    ) -> Int {
        var importedIDs = Set<UUID>()
        var importedCount = 0
        for log in backup.logs {
            guard importedTaskIDs.contains(log.taskID) else { continue }
            guard importedIDs.insert(log.id).inserted else { continue }

            let importedLog = RoutineLog(
                id: log.id,
                timestamp: log.timestamp,
                taskID: log.taskID,
                kind: log.kind ?? .completed,
                actualDurationMinutes: log.actualDurationMinutes
            )
            context.insert(importedLog)
            importedCount += 1
        }
        return importedCount
    }

    @MainActor
    private static func insertSleepSessions(
        from backup: Backup,
        in context: ModelContext
    ) -> (ids: Set<UUID>, count: Int) {
        var importedIDs = Set<UUID>()
        var importedCount = 0
        for sleepSession in backup.sleepSessions ?? [] {
            guard importedIDs.insert(sleepSession.id).inserted else { continue }

            let importedSession = SleepSession(
                id: sleepSession.id,
                startedAt: sleepSession.startedAt,
                endedAt: sleepSession.endedAt,
                targetDurationMinutes: sleepSession.targetDurationMinutes ?? 8 * 60,
                createdAt: sleepSession.createdAt,
                updatedAt: sleepSession.updatedAt
            )
            context.insert(importedSession)
            importedCount += 1
        }
        return (importedIDs, importedCount)
    }

    @MainActor
    private static func insertPlaceCheckInSessions(
        from backup: Backup,
        attachmentData: (String) throws -> Data?,
        importedPlaceIDs: Set<UUID>,
        in context: ModelContext
    ) throws -> Int {
        var importedIDs = Set<UUID>()
        var importedCount = 0
        var attachmentManifestsByID: [UUID: Backup.Attachment] = [:]
        for attachment in backup.attachments ?? [] {
            attachmentManifestsByID[attachment.id] = attachment
        }

        for session in backup.placeCheckInSessions ?? [] {
            guard importedIDs.insert(session.id).inserted else { continue }

            let imageData = try importedPlaceCheckInImageData(
                for: session,
                backupSchemaVersion: backup.schemaVersion,
                attachmentManifestsByID: attachmentManifestsByID,
                attachmentData: attachmentData
            )

            let importedSession = PlaceCheckInSession(
                id: session.id,
                placeID: session.placeID.flatMap { importedPlaceIDs.contains($0) ? $0 : nil },
                placeName: session.placeName,
                latitude: session.latitude,
                longitude: session.longitude,
                horizontalAccuracyMeters: session.horizontalAccuracyMeters,
                placeRadiusMeters: session.placeRadiusMeters,
                activity: session.activity,
                note: session.note,
                imageData: imageData,
                startedAt: session.startedAt,
                endedAt: session.endedAt,
                createdAt: session.createdAt,
                updatedAt: session.updatedAt,
                captureMode: session.captureMode ?? .manual,
                confirmedAt: session.confirmedAt
            )
            context.insert(importedSession)
            importedCount += 1
        }
        return importedCount
    }

    private static func importedPlaceCheckInImageData(
        for session: Backup.PlaceCheckIn,
        backupSchemaVersion: Int,
        attachmentManifestsByID: [UUID: Backup.Attachment],
        attachmentData: (String) throws -> Data?
    ) throws -> Data? {
        guard let imageAttachmentID = session.imageAttachmentID,
              let imageAttachment = attachmentManifestsByID[imageAttachmentID] else {
            return session.imageData
        }

        guard let data = try attachmentData(imageAttachment.fileName) else {
            if backupSchemaVersion >= SettingsRoutineDataPersistence.currentSchemaVersion {
                throw SettingsRoutineDataPersistence.Error.missingAttachment(imageAttachment.fileName)
            }
            return session.imageData
        }
        return data
    }

    @MainActor
    private static func insertEmotionLogs(
        from backup: Backup,
        importedNoteIDs: Set<UUID>,
        importedGoalIDs: Set<UUID>,
        importedTaskIDs: Set<UUID>,
        importedPlaceIDs: Set<UUID>,
        importedSleepSessionIDs: Set<UUID>,
        in context: ModelContext
    ) -> Int {
        var importedIDs = Set<UUID>()
        var importedCount = 0

        for emotion in backup.emotionLogs ?? [] {
            guard importedIDs.insert(emotion.id).inserted else { continue }

            let importedEmotion = EmotionLog(
                id: emotion.id,
                families: emotion.families ?? [emotion.family],
                labels: emotion.labels ?? [emotion.label],
                valence: emotion.valence,
                arousal: emotion.arousal,
                intensity: emotion.intensity,
                bodyAreas: emotion.bodyAreas ?? [],
                reflection: emotion.reflection,
                linkedNoteID: emotion.linkedNoteID.flatMap { importedNoteIDs.contains($0) ? $0 : nil },
                linkedGoalID: emotion.linkedGoalID.flatMap { importedGoalIDs.contains($0) ? $0 : nil },
                linkedTaskID: emotion.linkedTaskID.flatMap { importedTaskIDs.contains($0) ? $0 : nil },
                linkedPlaceID: emotion.linkedPlaceID.flatMap { importedPlaceIDs.contains($0) ? $0 : nil },
                linkedSleepSessionID: emotion.linkedSleepSessionID.flatMap { importedSleepSessionIDs.contains($0) ? $0 : nil },
                createdAt: emotion.createdAt,
                updatedAt: emotion.updatedAt
            )
            context.insert(importedEmotion)
            importedCount += 1
        }

        return importedCount
    }

    @MainActor
    private static func insertNotes(
        from backup: Backup,
        attachmentData: (String) throws -> Data?,
        in context: ModelContext,
        importDate: Date
    ) throws -> (ids: Set<UUID>, count: Int) {
        var importedIDs = Set<UUID>()
        var importedCount = 0
        var attachmentManifestsByID: [UUID: Backup.Attachment] = [:]
        for attachment in backup.attachments ?? [] {
            attachmentManifestsByID[attachment.id] = attachment
        }

        for note in backup.notes ?? [] {
            guard importedIDs.insert(note.id).inserted else { continue }

            let imageData = try importedNoteImageData(
                for: note,
                backupSchemaVersion: backup.schemaVersion,
                attachmentManifestsByID: attachmentManifestsByID,
                attachmentData: attachmentData
            )
            let voiceNoteData = try importedNoteVoiceNoteData(
                for: note,
                backupSchemaVersion: backup.schemaVersion,
                attachmentManifestsByID: attachmentManifestsByID,
                attachmentData: attachmentData
            )

            let importedNote = RoutineNote(
                id: note.id,
                title: note.title,
                body: note.body,
                tags: note.tags ?? [],
                imageData: imageData,
                voiceNoteData: voiceNoteData,
                voiceNoteDurationSeconds: note.voiceNoteDurationSeconds,
                voiceNoteCreatedAt: note.voiceNoteCreatedAt,
                createdAt: note.createdAt ?? importDate,
                updatedAt: note.updatedAt ?? note.createdAt ?? importDate
            )
            context.insert(importedNote)
            importedCount += 1
        }

        return (importedIDs, importedCount)
    }

    private static func importedNoteImageData(
        for note: Backup.Note,
        backupSchemaVersion: Int,
        attachmentManifestsByID: [UUID: Backup.Attachment],
        attachmentData: (String) throws -> Data?
    ) throws -> Data? {
        guard let imageAttachmentID = note.imageAttachmentID,
              let imageAttachment = attachmentManifestsByID[imageAttachmentID] else {
            return note.imageData
        }

        guard let data = try attachmentData(imageAttachment.fileName) else {
            if backupSchemaVersion >= SettingsRoutineDataPersistence.currentSchemaVersion {
                throw SettingsRoutineDataPersistence.Error.missingAttachment(imageAttachment.fileName)
            }
            return note.imageData
        }
        return data
    }

    private static func importedNoteVoiceNoteData(
        for note: Backup.Note,
        backupSchemaVersion: Int,
        attachmentManifestsByID: [UUID: Backup.Attachment],
        attachmentData: (String) throws -> Data?
    ) throws -> Data? {
        guard let voiceNoteAttachmentID = note.voiceNoteAttachmentID,
              let voiceNoteAttachment = attachmentManifestsByID[voiceNoteAttachmentID] else {
            return note.voiceNoteData
        }

        guard let data = try attachmentData(voiceNoteAttachment.fileName) else {
            if backupSchemaVersion >= SettingsRoutineDataPersistence.currentSchemaVersion {
                throw SettingsRoutineDataPersistence.Error.missingAttachment(voiceNoteAttachment.fileName)
            }
            return note.voiceNoteData
        }
        return data
    }

    @MainActor
    private static func insertEvents(
        from backup: Backup,
        in context: ModelContext,
        importDate: Date
    ) -> Int {
        var importedIDs = Set<UUID>()
        var importedCount = 0

        for event in backup.events ?? [] {
            guard importedIDs.insert(event.id).inserted else { continue }

            let importedEvent = RoutineEvent(
                id: event.id,
                title: event.title,
                notes: event.notes,
                emoji: event.emoji,
                tags: event.tags ?? [],
                isAllDay: event.isAllDay ?? true,
                startedAt: event.startedAt,
                endedAt: event.endedAt,
                createdAt: event.createdAt ?? importDate,
                updatedAt: event.updatedAt ?? event.createdAt ?? importDate
            )
            context.insert(importedEvent)
            importedCount += 1
        }

        return importedCount
    }

    @MainActor
    private static func insertNoteFileAttachments(
        from backup: Backup,
        attachmentData: (String) throws -> Data?,
        importedNoteIDs: Set<UUID>,
        in context: ModelContext,
        importDate: Date
    ) throws -> Int {
        var importedIDs = Set<UUID>()
        var importedCount = 0
        for attachment in backup.attachments ?? [] where attachment.role == .noteFileAttachment {
            guard let noteID = attachment.noteID,
                  importedNoteIDs.contains(noteID)
            else { continue }
            guard importedIDs.insert(attachment.id).inserted else { continue }
            guard let data = try attachmentData(attachment.fileName) else {
                if backup.schemaVersion >= SettingsRoutineDataPersistence.currentSchemaVersion {
                    throw SettingsRoutineDataPersistence.Error.missingAttachment(attachment.fileName)
                }
                continue
            }

            let importedAttachment = RoutineNoteAttachment(
                id: attachment.id,
                noteID: noteID,
                fileName: attachment.originalFileName ?? attachment.fileName,
                data: data,
                createdAt: attachment.createdAt ?? importDate
            )
            context.insert(importedAttachment)
            importedCount += 1
        }
        return importedCount
    }

    private static func clampedInterval(_ interval: Int) -> Int {
        min(max(interval, 1), Int(Int16.max))
    }
}

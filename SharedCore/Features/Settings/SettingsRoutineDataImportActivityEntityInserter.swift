import Foundation
import SwiftData

extension SettingsRoutineDataImportEntityInserter {
    @MainActor
    static func insertLogs(
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
                scheduledOccurrenceAt: log.scheduledOccurrenceAt,
                taskID: log.taskID,
                kind: log.kind ?? .completed,
                actualDurationMinutes: log.actualDurationMinutes,
                hasSpecificWorkTime: log.hasSpecificWorkTime,
                sourceTaskID: log.sourceTaskID.flatMap { importedTaskIDs.contains($0) ? $0 : nil },
                isConfirmedAssumedDone: log.isConfirmedAssumedDone ?? false
            )
            context.insert(importedLog)
            importedCount += 1
        }
        return importedCount
    }

    @MainActor
    static func insertFocusSessions(
        from backup: Backup,
        importedTaskIDs: Set<UUID>,
        in context: ModelContext
    ) -> Int {
        var importedIDs = Set<UUID>()
        var importedCount = 0

        for session in backup.focusSessions ?? [] {
            let taskID = session.taskID
            guard taskID == FocusSession.unassignedTaskID || importedTaskIDs.contains(taskID) else { continue }
            guard importedIDs.insert(session.id).inserted else { continue }

            let importedSession = FocusSession(
                id: session.id,
                taskID: taskID,
                startedAt: session.startedAt,
                plannedDurationSeconds: session.plannedDurationSeconds,
                completedAt: session.completedAt,
                abandonedAt: session.abandonedAt,
                pausedAt: session.pausedAt,
                accumulatedPausedSeconds: session.accumulatedPausedSeconds ?? 0,
                tagName: session.tagName
            )
            context.insert(importedSession)
            importedCount += 1
        }

        return importedCount
    }

    @MainActor
    static func insertSleepSessions(
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
    static func insertAwaySessions(
        from backup: Backup,
        in context: ModelContext
    ) -> (ids: Set<UUID>, count: Int) {
        var importedIDs = Set<UUID>()
        var importedCount = 0
        for awaySession in backup.awaySessions ?? [] {
            guard importedIDs.insert(awaySession.id).inserted else { continue }

            let importedSession = AwaySession(
                id: awaySession.id,
                preset: awaySession.preset ?? .custom,
                title: awaySession.title,
                linkedTaskID: awaySession.linkedTaskID,
                startedAt: awaySession.startedAt,
                plannedDurationSeconds: awaySession.plannedDurationSeconds ?? 20 * 60,
                completedAt: awaySession.completedAt,
                endedEarlyAt: awaySession.endedEarlyAt,
                extensionCount: awaySession.extensionCount ?? 0,
                createdAt: awaySession.createdAt,
                updatedAt: awaySession.updatedAt
            )
            context.insert(importedSession)
            importedCount += 1
        }
        return (importedIDs, importedCount)
    }

    @MainActor
    static func insertPlaceCheckInSessions(
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
            let imageAttachment = attachmentManifestsByID[imageAttachmentID]
        else {
            return session.imageData
        }

        guard let data = try attachmentData(imageAttachment.fileName) else {
            if SettingsRoutineDataPersistence.requiresExternalAttachmentFiles(schemaVersion: backupSchemaVersion) {
                throw SettingsRoutineDataPersistence.Error.missingAttachment(imageAttachment.fileName)
            }
            return session.imageData
        }
        return data
    }

    @MainActor
    static func insertEmotionLogs(
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
    static func insertNotes(
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
            let imageAttachment = attachmentManifestsByID[imageAttachmentID]
        else {
            return note.imageData
        }

        guard let data = try attachmentData(imageAttachment.fileName) else {
            if SettingsRoutineDataPersistence.requiresExternalAttachmentFiles(schemaVersion: backupSchemaVersion) {
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
            let voiceNoteAttachment = attachmentManifestsByID[voiceNoteAttachmentID]
        else {
            return note.voiceNoteData
        }

        guard let data = try attachmentData(voiceNoteAttachment.fileName) else {
            if SettingsRoutineDataPersistence.requiresExternalAttachmentFiles(schemaVersion: backupSchemaVersion) {
                throw SettingsRoutineDataPersistence.Error.missingAttachment(voiceNoteAttachment.fileName)
            }
            return note.voiceNoteData
        }
        return data
    }

    @MainActor
    static func insertEvents(
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
                reminderAt: event.reminderAt,
                createdAt: event.createdAt ?? importDate,
                updatedAt: event.updatedAt ?? event.createdAt ?? importDate
            )
            context.insert(importedEvent)
            importedCount += 1
        }

        return importedCount
    }

    @MainActor
    static func insertNoteFileAttachments(
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
                if SettingsRoutineDataPersistence.requiresExternalAttachmentFiles(schemaVersion: backup.schemaVersion) {
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

}

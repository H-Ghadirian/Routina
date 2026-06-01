import Foundation
import SwiftData

enum SettingsRoutineDataBackupPackageBuilder {
    typealias Backup = SettingsRoutineDataPersistence.Backup

    @MainActor
    static func buildPackage(
        from context: ModelContext,
        exportedAt: Date = Date()
    ) throws -> (manifestData: Data, attachmentFiles: [String: Data]) {
        var files: [String: Data] = [:]
        let manifestData = try buildManifestData(
            from: context,
            writeAttachment: { fileName, data in
                files[fileName] = data
            },
            exportedAt: exportedAt
        )
        return (manifestData, files)
    }

    @MainActor
    static func buildManifestData(
        from context: ModelContext,
        attachmentsDirectoryURL: URL,
        exportedAt: Date
    ) throws -> Data {
        try buildManifestData(
            from: context,
            writeAttachment: { fileName, data in
                try data.write(to: attachmentsDirectoryURL.appendingPathComponent(fileName), options: .atomic)
            },
            exportedAt: exportedAt
        )
    }

    @MainActor
    static func buildManifestData(
        from context: ModelContext,
        writeAttachment: (String, Data) throws -> Void,
        exportedAt: Date
    ) throws -> Data {
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let sleepSessions = try context.fetch(FetchDescriptor<SleepSession>())
        let awaySessions = try context.fetch(FetchDescriptor<AwaySession>())
        let placeCheckInSessions = try context.fetch(FetchDescriptor<PlaceCheckInSession>())
        let emotionLogs = try context.fetch(FetchDescriptor<EmotionLog>())
        let notes = try context.fetch(FetchDescriptor<RoutineNote>())
        let events = try context.fetch(FetchDescriptor<RoutineEvent>())
        let storedAttachments = try context.fetch(FetchDescriptor<RoutineAttachment>())
        let storedNoteAttachments = try context.fetch(FetchDescriptor<RoutineNoteAttachment>())

        var attachmentManifests: [Backup.Attachment] = []
        var taskImageAttachmentIDs: [UUID: UUID] = [:]
        var taskVoiceNoteAttachmentIDs: [UUID: UUID] = [:]
        var placeCheckInImageAttachmentIDs: [UUID: UUID] = [:]
        var noteImageAttachmentIDs: [UUID: UUID] = [:]
        var noteVoiceNoteAttachmentIDs: [UUID: UUID] = [:]

        for task in tasks {
            guard let imageData = task.imageData, !imageData.isEmpty else { continue }
            let attachmentID = UUID()
            let fileName = "\(attachmentID.uuidString).task-image"
            try writeAttachment(fileName, imageData)
            taskImageAttachmentIDs[task.id] = attachmentID
            attachmentManifests.append(
                .init(
                    id: attachmentID,
                    taskID: task.id,
                    placeCheckInSessionID: nil,
                    noteID: nil,
                    role: .taskImage,
                    fileName: fileName,
                    originalFileName: "task-image",
                    createdAt: task.createdAt ?? exportedAt
                )
            )
        }

        for task in tasks {
            guard let voiceNoteData = task.voiceNoteData, !voiceNoteData.isEmpty else { continue }
            let attachmentID = UUID()
            let fileName = "\(attachmentID.uuidString).task-voice.\(RoutineVoiceNote.fileExtension)"
            try writeAttachment(fileName, voiceNoteData)
            taskVoiceNoteAttachmentIDs[task.id] = attachmentID
            attachmentManifests.append(
                .init(
                    id: attachmentID,
                    taskID: task.id,
                    placeCheckInSessionID: nil,
                    noteID: nil,
                    role: .taskVoiceNote,
                    fileName: fileName,
                    originalFileName: RoutineVoiceNote.defaultFileName,
                    createdAt: task.voiceNoteCreatedAt ?? task.createdAt ?? exportedAt
                )
            )
        }

        for session in placeCheckInSessions {
            guard let imageData = session.imageData, !imageData.isEmpty else { continue }
            let attachmentID = UUID()
            let fileName = "\(attachmentID.uuidString).place-check-in-image"
            try writeAttachment(fileName, imageData)
            placeCheckInImageAttachmentIDs[session.id] = attachmentID
            attachmentManifests.append(
                .init(
                    id: attachmentID,
                    taskID: nil,
                    placeCheckInSessionID: session.id,
                    noteID: nil,
                    role: .placeCheckInImage,
                    fileName: fileName,
                    originalFileName: "place-check-in-image",
                    createdAt: session.createdAt ?? exportedAt
                )
            )
        }

        for note in notes {
            guard let imageData = note.imageData, !imageData.isEmpty else { continue }
            let attachmentID = UUID()
            let fileName = "\(attachmentID.uuidString).note-image"
            try writeAttachment(fileName, imageData)
            noteImageAttachmentIDs[note.id] = attachmentID
            attachmentManifests.append(
                .init(
                    id: attachmentID,
                    taskID: nil,
                    placeCheckInSessionID: nil,
                    noteID: note.id,
                    role: .noteImage,
                    fileName: fileName,
                    originalFileName: "note-image",
                    createdAt: note.createdAt ?? exportedAt
                )
            )
        }

        for note in notes {
            guard let voiceNoteData = note.voiceNoteData, !voiceNoteData.isEmpty else { continue }
            let attachmentID = UUID()
            let fileName = "\(attachmentID.uuidString).note-voice.\(RoutineVoiceNote.fileExtension)"
            try writeAttachment(fileName, voiceNoteData)
            noteVoiceNoteAttachmentIDs[note.id] = attachmentID
            attachmentManifests.append(
                .init(
                    id: attachmentID,
                    taskID: nil,
                    placeCheckInSessionID: nil,
                    noteID: note.id,
                    role: .noteVoiceNote,
                    fileName: fileName,
                    originalFileName: RoutineVoiceNote.defaultFileName,
                    createdAt: note.voiceNoteCreatedAt ?? note.createdAt ?? exportedAt
                )
            )
        }

        for attachment in storedAttachments {
            guard !attachment.data.isEmpty else { continue }
            let fileName = SettingsRoutineDataBackupFileNaming.packageAttachmentFileName(for: attachment)
            try writeAttachment(fileName, attachment.data)
            attachmentManifests.append(
                .init(
                    id: attachment.id,
                    taskID: attachment.taskID,
                    placeCheckInSessionID: nil,
                    noteID: nil,
                    role: .fileAttachment,
                    fileName: fileName,
                    originalFileName: attachment.fileName,
                    createdAt: attachment.createdAt
                )
            )
        }

        for attachment in storedNoteAttachments {
            guard !attachment.data.isEmpty else { continue }
            let fileName = SettingsRoutineDataBackupFileNaming.packageAttachmentFileName(for: attachment)
            try writeAttachment(fileName, attachment.data)
            attachmentManifests.append(
                .init(
                    id: attachment.id,
                    taskID: nil,
                    placeCheckInSessionID: nil,
                    noteID: attachment.noteID,
                    role: .noteFileAttachment,
                    fileName: fileName,
                    originalFileName: attachment.fileName,
                    createdAt: attachment.createdAt
                )
            )
        }

        let backup = Backup(
            schemaVersion: SettingsRoutineDataPersistence.currentSchemaVersion,
            exportedAt: exportedAt,
            places: places.map(SettingsRoutineDataBackupMapping.place),
            goals: goals.map(SettingsRoutineDataBackupMapping.goal),
            tasks: tasks.map {
                SettingsRoutineDataBackupMapping.task(
                    $0,
                    imageData: nil,
                    imageAttachmentID: taskImageAttachmentIDs[$0.id],
                    voiceNoteData: nil,
                    voiceNoteAttachmentID: taskVoiceNoteAttachmentIDs[$0.id],
                    includesPressure: false
                )
            },
            logs: logs.map(SettingsRoutineDataBackupMapping.log),
            sleepSessions: sleepSessions.map(SettingsRoutineDataBackupMapping.sleep),
            awaySessions: awaySessions.map(SettingsRoutineDataBackupMapping.away),
            placeCheckInSessions: placeCheckInSessions.map {
                SettingsRoutineDataBackupMapping.placeCheckIn(
                    $0,
                    imageData: nil,
                    imageAttachmentID: placeCheckInImageAttachmentIDs[$0.id]
                )
            },
            emotionLogs: emotionLogs.map(SettingsRoutineDataBackupMapping.emotion),
            notes: notes.map {
                SettingsRoutineDataBackupMapping.note(
                    $0,
                    imageData: nil,
                    imageAttachmentID: noteImageAttachmentIDs[$0.id],
                    voiceNoteData: nil,
                    voiceNoteAttachmentID: noteVoiceNoteAttachmentIDs[$0.id]
                )
            },
            events: events.map(SettingsRoutineDataBackupMapping.event),
            attachments: attachmentManifests
        )

        return try SettingsRoutineDataBackupCoding.encode(backup)
    }
}

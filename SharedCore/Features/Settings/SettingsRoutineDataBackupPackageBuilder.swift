import Foundation
import SwiftData

enum SettingsRoutineDataBackupPackageBuilder {
    typealias Backup = SettingsRoutineDataPersistence.Backup

    private struct PreparedAttachments {
        var manifests: [Backup.Attachment] = []
        var taskImageIDs: [UUID: UUID] = [:]
        var taskVoiceNoteIDs: [UUID: UUID] = [:]
        var placeCheckInImageIDs: [UUID: UUID] = [:]
        var noteImageIDs: [UUID: UUID] = [:]
        var noteVoiceNoteIDs: [UUID: UUID] = [:]
    }

    @MainActor
    static func buildPackage(
        from context: ModelContext,
        exportedAt: Date = Date(),
        mirrorsUserDefaults: Bool = true
    ) throws -> (manifestData: Data, attachmentFiles: [String: Data]) {
        var files: [String: Data] = [:]
        let manifestData = try buildManifestData(
            from: context,
            writeAttachment: { fileName, data in
                files[fileName] = data
            },
            exportedAt: exportedAt,
            mirrorsUserDefaults: mirrorsUserDefaults
        )
        return (manifestData, files)
    }

    @MainActor
    static func buildManifestData(
        from context: ModelContext,
        attachmentsDirectoryURL: URL,
        exportedAt: Date,
        mirrorsUserDefaults: Bool = true
    ) throws -> Data {
        try buildManifestData(
            from: context,
            writeAttachment: { fileName, data in
                try data.write(to: attachmentsDirectoryURL.appendingPathComponent(fileName), options: .atomic)
            },
            exportedAt: exportedAt,
            mirrorsUserDefaults: mirrorsUserDefaults
        )
    }

    @MainActor
    static func buildManifestData(
        from context: ModelContext,
        writeAttachment: (String, Data) throws -> Void,
        exportedAt: Date,
        mirrorsUserDefaults: Bool = true
    ) throws -> Data {
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let focusSessions = try context.fetch(FetchDescriptor<FocusSession>())
        let sleepSessions = try context.fetch(FetchDescriptor<SleepSession>())
        let awaySessions = try context.fetch(FetchDescriptor<AwaySession>())
        let placeCheckInSessions = try context.fetch(FetchDescriptor<PlaceCheckInSession>())
        let emotionLogs = try context.fetch(FetchDescriptor<EmotionLog>())
        let notes = try context.fetch(FetchDescriptor<RoutineNote>())
        let events = try context.fetch(FetchDescriptor<RoutineEvent>())
        let storedAttachments = try context.fetch(FetchDescriptor<RoutineAttachment>())
        let storedNoteAttachments = try context.fetch(FetchDescriptor<RoutineNoteAttachment>())
        let dayPlanBlocks = try context.fetch(FetchDescriptor<DayPlanBlockRecord>())
        let boardSprints = try context.fetch(FetchDescriptor<BoardSprintRecord>())
        let sprintAssignments = try context.fetch(FetchDescriptor<SprintAssignmentRecord>())
        let boardBacklogs = try context.fetch(FetchDescriptor<BoardBacklogRecord>())
        let backlogAssignments = try context.fetch(FetchDescriptor<BacklogAssignmentRecord>())
        let sprintFocusSessions = try context.fetch(FetchDescriptor<SprintFocusSessionRecord>())
        let sprintFocusAllocations = try context.fetch(FetchDescriptor<SprintFocusAllocationRecord>())
        let deviceSessions = try context.fetch(FetchDescriptor<RoutinaDeviceSession>())
        let deviceActionLogs = try context.fetch(FetchDescriptor<RoutinaDeviceActionLog>())
        if mirrorsUserDefaults {
            RoutinaUserPreferencesStore.mirrorDefaultsToStore(in: context)
        }
        let userPreferences = try context.fetch(FetchDescriptor<RoutinaUserPreferences>()).first

        let preparedAttachments = try prepareAttachments(
            tasks: tasks,
            placeCheckInSessions: placeCheckInSessions,
            notes: notes,
            storedAttachments: storedAttachments,
            storedNoteAttachments: storedNoteAttachments,
            exportedAt: exportedAt,
            writeAttachment: writeAttachment
        )

        let backup = Backup(
            schemaVersion: SettingsRoutineDataPersistence.currentSchemaVersion,
            exportedAt: exportedAt,
            places: places.map(SettingsRoutineDataBackupMapping.place),
            goals: goals.map(SettingsRoutineDataBackupMapping.goal),
            tasks: tasks.map {
                SettingsRoutineDataBackupMapping.task(
                    $0,
                    imageData: nil,
                    imageAttachmentID: preparedAttachments.taskImageIDs[$0.id],
                    voiceNoteData: nil,
                    voiceNoteAttachmentID: preparedAttachments.taskVoiceNoteIDs[$0.id],
                    includesPressure: true
                )
            },
            logs: logs.map(SettingsRoutineDataBackupMapping.log),
            sleepSessions: sleepSessions.map(SettingsRoutineDataBackupMapping.sleep),
            awaySessions: awaySessions.map(SettingsRoutineDataBackupMapping.away),
            placeCheckInSessions: placeCheckInSessions.map {
                SettingsRoutineDataBackupMapping.placeCheckIn(
                    $0,
                    imageData: nil,
                    imageAttachmentID: preparedAttachments.placeCheckInImageIDs[$0.id]
                )
            },
            emotionLogs: emotionLogs.map(SettingsRoutineDataBackupMapping.emotion),
            notes: notes.map {
                SettingsRoutineDataBackupMapping.note(
                    $0,
                    imageData: nil,
                    imageAttachmentID: preparedAttachments.noteImageIDs[$0.id],
                    voiceNoteData: nil,
                    voiceNoteAttachmentID: preparedAttachments.noteVoiceNoteIDs[$0.id]
                )
            },
            events: events.map(SettingsRoutineDataBackupMapping.event),
            attachments: preparedAttachments.manifests,
            focusSessions: focusSessions.map(SettingsRoutineDataBackupMapping.focus),
            dayPlanBlocks: dayPlanBlocks.map(SettingsRoutineDataBackupMapping.dayPlanBlock),
            boardSprints: boardSprints.map(SettingsRoutineDataBackupMapping.boardSprint),
            sprintAssignments: sprintAssignments.map(SettingsRoutineDataBackupMapping.sprintAssignment),
            boardBacklogs: boardBacklogs.map(SettingsRoutineDataBackupMapping.boardBacklog),
            backlogAssignments: backlogAssignments.map(SettingsRoutineDataBackupMapping.backlogAssignment),
            sprintFocusSessions: sprintFocusSessions.map(SettingsRoutineDataBackupMapping.sprintFocus),
            sprintFocusAllocations: sprintFocusAllocations.map(SettingsRoutineDataBackupMapping.sprintFocusAllocation),
            deviceSessions: deviceSessions.map(SettingsRoutineDataBackupMapping.deviceSession),
            deviceActionLogs: deviceActionLogs.map(SettingsRoutineDataBackupMapping.deviceActionLog),
            userPreferences: userPreferences.map(SettingsRoutineDataBackupMapping.userPreferences),
            verificationReceiptVersion: SettingsRoutineDataBackupVerification.currentReceiptVersion
        )

        return try SettingsRoutineDataBackupCoding.encode(backup)
    }

    @MainActor
    private static func prepareAttachments(
        tasks: [RoutineTask],
        placeCheckInSessions: [PlaceCheckInSession],
        notes: [RoutineNote],
        storedAttachments: [RoutineAttachment],
        storedNoteAttachments: [RoutineNoteAttachment],
        exportedAt: Date,
        writeAttachment: (String, Data) throws -> Void
    ) throws -> PreparedAttachments {
        var result = PreparedAttachments()
        try appendTaskAttachments(
            from: tasks,
            exportedAt: exportedAt,
            writeAttachment: writeAttachment,
            to: &result
        )
        try appendPlaceAndNoteAttachments(
            placeCheckInSessions: placeCheckInSessions,
            notes: notes,
            exportedAt: exportedAt,
            writeAttachment: writeAttachment,
            to: &result
        )
        try appendStoredAttachments(
            storedAttachments,
            noteAttachments: storedNoteAttachments,
            writeAttachment: writeAttachment,
            to: &result
        )
        return result
    }

    @MainActor
    private static func appendTaskAttachments(
        from tasks: [RoutineTask],
        exportedAt: Date,
        writeAttachment: (String, Data) throws -> Void,
        to result: inout PreparedAttachments
    ) throws {
        for task in tasks {
            guard let imageData = task.imageData, !imageData.isEmpty else { continue }
            let attachmentID = UUID()
            let fileName = "\(attachmentID.uuidString).task-image"
            try writeAttachment(fileName, imageData)
            result.taskImageIDs[task.id] = attachmentID
            result.manifests.append(
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
            result.taskVoiceNoteIDs[task.id] = attachmentID
            result.manifests.append(
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
    }

    @MainActor
    private static func appendPlaceAndNoteAttachments(
        placeCheckInSessions: [PlaceCheckInSession],
        notes: [RoutineNote],
        exportedAt: Date,
        writeAttachment: (String, Data) throws -> Void,
        to result: inout PreparedAttachments
    ) throws {
        for session in placeCheckInSessions {
            guard let imageData = session.imageData, !imageData.isEmpty else { continue }
            let attachmentID = UUID()
            let fileName = "\(attachmentID.uuidString).place-check-in-image"
            try writeAttachment(fileName, imageData)
            result.placeCheckInImageIDs[session.id] = attachmentID
            result.manifests.append(
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
            result.noteImageIDs[note.id] = attachmentID
            result.manifests.append(
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
            result.noteVoiceNoteIDs[note.id] = attachmentID
            result.manifests.append(
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
    }

    @MainActor
    private static func appendStoredAttachments(
        _ attachments: [RoutineAttachment],
        noteAttachments: [RoutineNoteAttachment],
        writeAttachment: (String, Data) throws -> Void,
        to result: inout PreparedAttachments
    ) throws {
        for attachment in attachments {
            guard !attachment.data.isEmpty else { continue }
            let fileName = SettingsRoutineDataBackupFileNaming.packageAttachmentFileName(for: attachment)
            try writeAttachment(fileName, attachment.data)
            result.manifests.append(
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

        for attachment in noteAttachments {
            guard !attachment.data.isEmpty else { continue }
            let fileName = SettingsRoutineDataBackupFileNaming.packageAttachmentFileName(for: attachment)
            try writeAttachment(fileName, attachment.data)
            result.manifests.append(
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
    }
}

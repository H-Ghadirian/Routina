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
        let placeCheckInSessions = try context.fetch(FetchDescriptor<PlaceCheckInSession>())
        let storedAttachments = try context.fetch(FetchDescriptor<RoutineAttachment>())

        var attachmentManifests: [Backup.Attachment] = []
        var taskImageAttachmentIDs: [UUID: UUID] = [:]

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
                    role: .taskImage,
                    fileName: fileName,
                    originalFileName: "task-image",
                    createdAt: task.createdAt ?? exportedAt
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
                    role: .fileAttachment,
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
                    includesPressure: false
                )
            },
            logs: logs.map(SettingsRoutineDataBackupMapping.log),
            sleepSessions: sleepSessions.map(SettingsRoutineDataBackupMapping.sleep),
            placeCheckInSessions: placeCheckInSessions.map(SettingsRoutineDataBackupMapping.placeCheckIn),
            attachments: attachmentManifests
        )

        return try SettingsRoutineDataBackupCoding.encode(backup)
    }
}

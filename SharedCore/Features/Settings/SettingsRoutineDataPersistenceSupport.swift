import Foundation
import SwiftData

enum SettingsRoutineDataPersistence {
    static let currentSchemaVersion = 17
    static let legacyJSONSchemaVersion = 14
    static let backupPackageExtension = "routinabackup"
    static let manifestFileName = "manifest.json"
    static let attachmentsDirectoryName = "attachments"

    static func defaultBackupFileName(now: Date = Date()) -> String {
        SettingsRoutineDataBackupFileNaming.defaultBackupFileName(
            now: now,
            fileExtension: backupPackageExtension
        )
    }

    @MainActor
    static func buildBackupJSON(
        from context: ModelContext,
        exportedAt: Date = Date()
    ) throws -> Data {
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        let backup = Backup(
            schemaVersion: legacyJSONSchemaVersion,
            exportedAt: exportedAt,
            places: places.map(SettingsRoutineDataBackupMapping.place),
            goals: goals.map(SettingsRoutineDataBackupMapping.goal),
            tasks: tasks.map {
                SettingsRoutineDataBackupMapping.task(
                    $0,
                    imageData: $0.imageData,
                    imageAttachmentID: nil,
                    includesPressure: true
                )
            },
            logs: logs.map(SettingsRoutineDataBackupMapping.log),
            sleepSessions: nil,
            attachments: nil
        )

        return try SettingsRoutineDataBackupCoding.encode(backup)
    }

    @MainActor
    static func writeBackupPackage(
        to packageURL: URL,
        from context: ModelContext,
        exportedAt: Date = Date()
    ) throws {
        let fileManager = FileManager.default
        let attachmentsURL = packageURL.appendingPathComponent(attachmentsDirectoryName, isDirectory: true)

        if fileManager.fileExists(atPath: packageURL.path) {
            try fileManager.removeItem(at: packageURL)
        }
        try fileManager.createDirectory(at: attachmentsURL, withIntermediateDirectories: true)

        let manifestData = try SettingsRoutineDataBackupPackageBuilder.buildManifestData(
            from: context,
            attachmentsDirectoryURL: attachmentsURL,
            exportedAt: exportedAt
        )
        try manifestData.write(to: packageURL.appendingPathComponent(manifestFileName), options: .atomic)
    }

    @MainActor
    static func buildBackupPackage(
        from context: ModelContext,
        exportedAt: Date = Date()
    ) throws -> (manifestData: Data, attachmentFiles: [String: Data]) {
        try SettingsRoutineDataBackupPackageBuilder.buildPackage(
            from: context,
            exportedAt: exportedAt
        )
    }

    @MainActor
    static func replaceAllRoutineData(
        with jsonData: Data,
        in context: ModelContext,
        importDate: Date = Date()
    ) throws -> ImportSummary {
        let backup = try SettingsRoutineDataBackupCoding.decodeBackup(from: jsonData)

        return try replaceAllRoutineData(
            with: backup,
            attachmentData: { _ in nil },
            in: context,
            importDate: importDate
        )
    }

    @MainActor
    static func replaceAllRoutineData(
        withBackupPackageAt packageURL: URL,
        in context: ModelContext,
        importDate: Date = Date()
    ) throws -> ImportSummary {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: packageURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw Error.invalidBackupPackage(packageURL)
        }

        let manifestURL = packageURL.appendingPathComponent(manifestFileName)
        let attachmentsURL = packageURL.appendingPathComponent(attachmentsDirectoryName, isDirectory: true)
        let manifestData = try Data(contentsOf: manifestURL)
        let backup = try SettingsRoutineDataBackupCoding.decodeBackup(from: manifestData)

        return try replaceAllRoutineData(
            with: backup,
            attachmentData: { fileName in
                let fileURL = attachmentsURL.appendingPathComponent(fileName)
                guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
                return try Data(contentsOf: fileURL)
            },
            in: context,
            importDate: importDate
        )
    }

    @MainActor
    private static func replaceAllRoutineData(
        with backup: Backup,
        attachmentData: (String) throws -> Data?,
        in context: ModelContext,
        importDate: Date
    ) throws -> ImportSummary {
        guard (1...currentSchemaVersion).contains(backup.schemaVersion) else {
            throw Error.unsupportedSchema(backup.schemaVersion)
        }

        do {
            try SettingsRoutineDataImportStoreResetter.deleteExistingData(in: context)

            let summary = try SettingsRoutineDataImportEntityInserter.insertBackup(
                backup,
                attachmentData: attachmentData,
                in: context,
                importDate: importDate
            )
            try context.save()
            return summary
        } catch {
            context.rollback()
            throw error
        }
    }

}

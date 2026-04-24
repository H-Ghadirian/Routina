import Foundation
import SwiftData

struct SettingsRoutineDataTransferExportResult {
    var destinationFileName: String
}

struct SettingsRoutineDataTransferImportResult {
    var importedSummary: SettingsRoutineDataPersistence.ImportSummary
    var cloudUsageEstimate: CloudUsageEstimate
}

enum SettingsRoutineDataTransferExecution {
    @MainActor
    static func exportData(
        routineDataTransferClient: RoutineDataTransferClient,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) async throws -> SettingsRoutineDataTransferExportResult? {
        guard let destinationURL = await routineDataTransferClient.selectExportURL(
            SettingsRoutineDataPersistence.defaultBackupFileName()
        ) else {
            return nil
        }

        let context = modelContext()
        if context.hasChanges {
            try context.save()
        }

        try SettingsExecutionSupport.withSecurityScopedAccess(to: destinationURL) {
            try SettingsRoutineDataPersistence.writeBackupPackage(
                to: destinationURL,
                from: context
            )
        }

        return SettingsRoutineDataTransferExportResult(
            destinationFileName: destinationURL.lastPathComponent
        )
    }

    @MainActor
    static func importData(
        routineDataTransferClient: RoutineDataTransferClient,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        appSettingsClient: @escaping @MainActor @Sendable () -> AppSettingsClient,
        notificationClient: @escaping @MainActor @Sendable () -> NotificationClient
    ) async throws -> SettingsRoutineDataTransferImportResult? {
        guard let sourceURL = await routineDataTransferClient.selectImportURL() else {
            return nil
        }

        let context = modelContext()
        let importedSummary = try SettingsExecutionSupport.withSecurityScopedAccess(to: sourceURL) {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return try SettingsRoutineDataPersistence.replaceAllRoutineData(
                    withBackupPackageAt: sourceURL,
                    in: context
                )
            }

            let jsonData = try Data(contentsOf: sourceURL)
            return try SettingsRoutineDataPersistence.replaceAllRoutineData(
                with: jsonData,
                in: context
            )
        }
        try await SettingsExecutionSupport.rescheduleNotificationsAfterImport(
            in: context,
            appSettingsClient: appSettingsClient(),
            notificationClient: notificationClient()
        )

        return SettingsRoutineDataTransferImportResult(
            importedSummary: importedSummary,
            cloudUsageEstimate: SettingsDataQueries.loadCloudUsageEstimate(in: context)
        )
    }
}

import Foundation
import SwiftData

struct SettingsRoutineDataTransferExportResult {
    var destinationFileName: String
    var verification: SettingsRoutineDataBackupVerification.Report?
}

struct SettingsRoutineDataTransferImportResult {
    var importedSummary: SettingsRoutineDataPersistence.ImportSummary
    var cloudUsageEstimate: CloudUsageEstimate
    var verification: SettingsRoutineDataBackupVerification.Report
    var recoveryPoint: SettingsRoutineDataRecoveryPoint?
    var recoveryPoints: [SettingsRoutineDataRecoveryPoint]
    var notificationWarning: String?
}

struct SettingsRoutineDataTransferVerificationResult {
    var verification: SettingsRoutineDataBackupVerification.Report
    var comparison: RoutinaBackupAudit.ComparisonReport
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

        return try await exportData(
            to: destinationURL,
            modelContext: modelContext
        )
    }

    @MainActor
    static func exportData(
        to destinationURL: URL,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) async throws -> SettingsRoutineDataTransferExportResult {
        let context = modelContext()
        if context.hasChanges {
            try context.save()
        }

        let verification: SettingsRoutineDataBackupVerification.Report? = try SettingsExecutionSupport.withSecurityScopedAccess(to: destinationURL) {
            if SettingsRoutineDataPersistence.isLegacyJSONBackupURL(destinationURL) {
                try SettingsRoutineDataPersistence.writeBackup(
                    to: destinationURL,
                    from: context
                )
                return nil
            }
            return try SettingsRoutineDataPersistence.writeVerifiedBackupPackage(
                to: destinationURL,
                from: context
            )
        }

        return SettingsRoutineDataTransferExportResult(
            destinationFileName: destinationURL.lastPathComponent,
            verification: verification
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

        return try await importData(
            from: sourceURL,
            modelContext: modelContext,
            appSettingsClient: appSettingsClient,
            notificationClient: notificationClient,
            recoveryDirectoryURL: routineDataTransferClient.recoveryDirectoryURL
        )
    }

    @MainActor
    static func importData(
        from sourceURL: URL,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        appSettingsClient: @escaping @MainActor @Sendable () -> AppSettingsClient,
        notificationClient: @escaping @MainActor @Sendable () -> NotificationClient,
        recoveryDirectoryURL: @escaping @MainActor @Sendable () throws -> URL? = { nil }
    ) async throws -> SettingsRoutineDataTransferImportResult {
        let context = modelContext()
        if context.hasChanges {
            try context.save()
        }

        let verification = try verifyImportCandidate(at: sourceURL)
        let recoveryDirectory = try recoveryDirectoryURL()
        let recoveryPoint = try recoveryDirectory.map {
            try SettingsRoutineDataRecoveryStore.createPreRestoreRecoveryPoint(
                from: context,
                in: $0,
                preserving: sourceURL
            )
        }
        let importedSummary = try importData(from: sourceURL, into: context)
        if let recoveryDirectory {
            SettingsRoutineDataRecoveryStore.enforceRetention(in: recoveryDirectory)
        }
        let notificationWarning: String?
        do {
            try await SettingsExecutionSupport.rescheduleNotificationsAfterImport(
                in: context,
                appSettingsClient: appSettingsClient(),
                notificationClient: notificationClient()
            )
            notificationWarning = nil
        } catch {
            notificationWarning = error.localizedDescription
        }

        return SettingsRoutineDataTransferImportResult(
            importedSummary: importedSummary,
            cloudUsageEstimate: SettingsDataQueries.loadCloudUsageEstimate(in: context),
            verification: verification,
            recoveryPoint: recoveryPoint,
            recoveryPoints: recoveryDirectory.map {
                SettingsRoutineDataRecoveryStore.recoveryPoints(in: $0)
            } ?? [],
            notificationWarning: notificationWarning
        )
    }

    @MainActor
    static func verifyData(
        routineDataTransferClient: RoutineDataTransferClient,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) async throws -> SettingsRoutineDataTransferVerificationResult? {
        guard let sourceURL = await routineDataTransferClient.selectImportURL() else {
            return nil
        }
        return try verifyData(from: sourceURL, modelContext: modelContext)
    }

    @MainActor
    static func verifyData(
        from sourceURL: URL,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) throws -> SettingsRoutineDataTransferVerificationResult {
        let context = modelContext()
        if context.hasChanges {
            try context.save()
        }
        return try SettingsExecutionSupport.withSecurityScopedAccess(to: sourceURL) {
            guard isPackage(at: sourceURL) else {
                throw SettingsRoutineDataPersistence.Error.invalidBackupPackage(sourceURL)
            }
            let result = try SettingsRoutineDataBackupVerification.compareWithLiveData(
                packageAt: sourceURL,
                in: context
            )
            return SettingsRoutineDataTransferVerificationResult(
                verification: result.verification,
                comparison: result.comparison
            )
        }
    }

    @MainActor
    static func recoveryPoints(
        routineDataTransferClient: RoutineDataTransferClient
    ) -> [SettingsRoutineDataRecoveryPoint] {
        let directoryURL: URL
        do {
            guard let resolvedURL = try routineDataTransferClient.recoveryDirectoryURL() else {
                return []
            }
            directoryURL = resolvedURL
        } catch {
            return []
        }
        return SettingsRoutineDataRecoveryStore.recoveryPoints(in: directoryURL)
    }

    @MainActor
    private static func importData(
        from sourceURL: URL,
        into context: ModelContext
    ) throws -> SettingsRoutineDataPersistence.ImportSummary {
        try SettingsExecutionSupport.withSecurityScopedAccess(to: sourceURL) {
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
    }

    @MainActor
    private static func verifyImportCandidate(
        at sourceURL: URL
    ) throws -> SettingsRoutineDataBackupVerification.Report {
        try SettingsExecutionSupport.withSecurityScopedAccess(to: sourceURL) {
            if isPackage(at: sourceURL) {
                return try SettingsRoutineDataBackupVerification.verifyForRestore(
                    packageAt: sourceURL
                )
            }

            let jsonData = try Data(contentsOf: sourceURL)
            let audit = try RoutinaBackupAudit.audit(legacyJSONData: jsonData)
            return SettingsRoutineDataBackupVerification.Report(
                audit: audit,
                assurance: .isolatedRestoreOnly
            )
        }
    }

    private static func isPackage(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}

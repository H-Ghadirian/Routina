import Foundation
import SwiftData

struct SettingsRoutineDataRecoveryPoint: Equatable, Identifiable, Sendable {
    var id: String { packageURL.lastPathComponent }
    var packageURL: URL
    var createdAt: Date
    var totalRecordCount: Int
    var attachmentCount: Int
    var semanticFingerprint: String
}

enum SettingsRoutineDataRecoveryStore {
    static let maximumRetainedRecoveryPoints = 10
    static let recoveryDirectoryName = "Recovery Backups"

    static func defaultDirectoryURL() throws -> URL {
        let applicationSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return applicationSupportDirectory
            .appendingPathComponent("RoutinaData", isDirectory: true)
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
    }

    @MainActor
    static func createPreRestoreRecoveryPoint(
        from context: ModelContext,
        in directoryURL: URL,
        preserving preservedPackageURL: URL? = nil,
        now: Date = Date()
    ) throws -> SettingsRoutineDataRecoveryPoint {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let packageURL = directoryURL
            .appendingPathComponent(fileName(for: now))
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        let verification = try SettingsRoutineDataPersistence.writeVerifiedBackupPackage(
            to: packageURL,
            from: context,
            exportedAt: now,
            verifiedAt: now,
            purpose: .preRestoreRecovery
        )
        let point = SettingsRoutineDataRecoveryPoint(
            packageURL: packageURL,
            createdAt: now,
            totalRecordCount: verification.audit.totalRecordCount,
            attachmentCount: verification.audit.attachmentCount,
            semanticFingerprint: verification.audit.semanticFingerprint
        )
        try pruneRecoveryPoints(
            in: directoryURL,
            preserving: preservedPackageURL
        )
        return point
    }

    static func recoveryPoints(
        in directoryURL: URL
    ) -> [SettingsRoutineDataRecoveryPoint] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.compactMap { packageURL in
            guard packageURL.pathExtension.localizedCaseInsensitiveCompare(
                SettingsRoutineDataPersistence.backupPackageExtension
            ) == .orderedSame,
            let receipt = SettingsRoutineDataBackupVerification.loadReceiptIfPresent(
                packageAt: packageURL
            ),
            receipt.receiptVersion == SettingsRoutineDataBackupVerification.currentReceiptVersion,
            receipt.purpose == .preRestoreRecovery
            else {
                return nil
            }
            return SettingsRoutineDataRecoveryPoint(
                packageURL: packageURL,
                createdAt: receipt.verifiedAt,
                totalRecordCount: receipt.recordCounts.values.reduce(0, +),
                attachmentCount: receipt.attachmentCount,
                semanticFingerprint: receipt.semanticFingerprint
            )
        }
        .sorted { left, right in
            if left.createdAt != right.createdAt {
                return left.createdAt > right.createdAt
            }
            return left.id > right.id
        }
    }

    static func enforceRetention(in directoryURL: URL) {
        try? pruneRecoveryPoints(in: directoryURL, preserving: nil)
    }

    private static func pruneRecoveryPoints(
        in directoryURL: URL,
        preserving preservedPackageURL: URL?
    ) throws {
        let points = recoveryPoints(in: directoryURL)
        guard points.count > maximumRetainedRecoveryPoints else { return }
        let preservedURL = preservedPackageURL?.standardizedFileURL
        var keptPoints = Array(points.prefix(maximumRetainedRecoveryPoints))
        if let preservedPoint = points.first(where: {
            $0.packageURL.standardizedFileURL == preservedURL
        }), !keptPoints.contains(where: { $0.id == preservedPoint.id }) {
            keptPoints.removeLast()
            keptPoints.append(preservedPoint)
        }
        let keptIDs = Set(keptPoints.map(\.id))
        for point in points where !keptIDs.contains(point.id) {
            try FileManager.default.removeItem(at: point.packageURL)
        }
    }

    private static func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "Routina-Pre-Restore-\(formatter.string(from: date))-\(UUID().uuidString)"
    }
}

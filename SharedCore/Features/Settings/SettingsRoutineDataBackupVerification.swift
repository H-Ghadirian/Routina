import CryptoKit
import Foundation
import SwiftData

enum SettingsRoutineDataBackupVerification {
    static let receiptFileName = "verification.json"
    static let currentReceiptVersion = 1

    enum Purpose: String, Codable, Equatable, Sendable {
        case userExport
        case preRestoreRecovery
    }

    struct AttachmentDigest: Codable, Equatable, Sendable {
        var fileName: String
        var byteCount: Int
        var sha256: String
    }

    struct Receipt: Codable, Equatable, Sendable {
        var receiptVersion: Int
        var purpose: Purpose
        var verifiedAt: Date
        var backupSchemaVersion: Int
        var backupExportedAt: Date
        var semanticFingerprint: String
        var manifestSHA256: String
        var recordCounts: [String: Int]
        var attachmentCount: Int
        var attachmentBytes: Int
        var attachments: [AttachmentDigest]
    }

    enum Assurance: Equatable, Sendable {
        case sourceVerified(Receipt)
        case isolatedRestoreOnly

        var isSourceVerified: Bool {
            if case .sourceVerified = self { return true }
            return false
        }
    }

    struct Report: Equatable, Sendable {
        var audit: RoutinaBackupAudit.Report
        var assurance: Assurance
    }

    enum VerificationError: LocalizedError, Equatable, Sendable {
        case unsupportedReceiptVersion(Int)
        case missingRequiredReceipt
        case invalidReceipt
        case receiptSchemaMismatch
        case manifestDigestMismatch
        case semanticFingerprintMismatch
        case recordCountsMismatch
        case attachmentInventoryMismatch
        case attachmentDigestMismatch(String)
        case liveSourceMismatch(String)

        var errorDescription: String? {
            switch self {
            case let .unsupportedReceiptVersion(version):
                return "Unsupported backup verification receipt version: \(version)."
            case .missingRequiredReceipt:
                return "This verified backup is missing its verification receipt."
            case .invalidReceipt:
                return "The backup verification receipt is invalid."
            case .receiptSchemaMismatch:
                return "The backup manifest does not match its verification receipt."
            case .manifestDigestMismatch:
                return "The backup manifest changed after it was verified."
            case .semanticFingerprintMismatch:
                return "The restored backup does not match the data verified on the source device."
            case .recordCountsMismatch:
                return "The backup record inventory changed after it was verified."
            case .attachmentInventoryMismatch:
                return "The backup attachment inventory changed after it was verified."
            case let .attachmentDigestMismatch(fileName):
                return "Backup attachment changed after verification: \(fileName)."
            case let .liveSourceMismatch(path):
                return "The backup does not match the current device data at \(path)."
            }
        }
    }

    @MainActor
    static func createReceipt(
        forPackageAt packageURL: URL,
        matchingLiveDataIn context: ModelContext,
        purpose: Purpose,
        verifiedAt: Date = Date()
    ) throws -> Report {
        let comparison = try RoutinaBackupAudit.compare(
            packageAt: packageURL,
            withLiveDataIn: context
        )
        guard comparison.matchesLiveData else {
            throw VerificationError.liveSourceMismatch(
                comparison.firstDifferencePath ?? "$"
            )
        }

        let manifestData = try Data(contentsOf: manifestURL(for: packageURL))
        let backup = try SettingsRoutineDataBackupCoding.decodeBackup(from: manifestData)
        let attachmentDigests = try makeAttachmentDigests(
            for: backup,
            packageURL: packageURL
        )
        let receipt = Receipt(
            receiptVersion: currentReceiptVersion,
            purpose: purpose,
            verifiedAt: verifiedAt,
            backupSchemaVersion: backup.schemaVersion,
            backupExportedAt: backup.exportedAt,
            semanticFingerprint: comparison.packageReport.semanticFingerprint,
            manifestSHA256: sha256Hex(manifestData),
            recordCounts: comparison.packageReport.recordCounts,
            attachmentCount: comparison.packageReport.attachmentCount,
            attachmentBytes: comparison.packageReport.attachmentBytes,
            attachments: attachmentDigests
        )
        try encode(receipt).write(
            to: packageURL.appendingPathComponent(receiptFileName),
            options: .atomic
        )
        return Report(
            audit: comparison.packageReport,
            assurance: .sourceVerified(receipt)
        )
    }

    @MainActor
    static func verifyForRestore(packageAt packageURL: URL) throws -> Report {
        let audit = try RoutinaBackupAudit.audit(packageAt: packageURL)
        let manifestData = try Data(contentsOf: manifestURL(for: packageURL))
        let backup = try SettingsRoutineDataBackupCoding.decodeBackup(from: manifestData)
        let receiptURL = packageURL.appendingPathComponent(receiptFileName)
        guard FileManager.default.fileExists(atPath: receiptURL.path) else {
            if backup.schemaVersion >= SettingsRoutineDataPersistence
                .verificationReceiptRequiredSchemaVersion {
                throw VerificationError.missingRequiredReceipt
            }
            return Report(audit: audit, assurance: .isolatedRestoreOnly)
        }

        let receipt: Receipt
        do {
            receipt = try decode(Data(contentsOf: receiptURL))
        } catch {
            throw VerificationError.invalidReceipt
        }
        guard receipt.receiptVersion == currentReceiptVersion else {
            throw VerificationError.unsupportedReceiptVersion(receipt.receiptVersion)
        }
        guard backup.verificationReceiptVersion == receipt.receiptVersion else {
            throw VerificationError.receiptSchemaMismatch
        }
        guard receipt.backupSchemaVersion == audit.sourceSchemaVersion else {
            throw VerificationError.receiptSchemaMismatch
        }

        guard sha256Hex(manifestData) == receipt.manifestSHA256 else {
            throw VerificationError.manifestDigestMismatch
        }
        guard audit.semanticFingerprint == receipt.semanticFingerprint else {
            throw VerificationError.semanticFingerprintMismatch
        }
        guard audit.recordCounts == receipt.recordCounts else {
            throw VerificationError.recordCountsMismatch
        }
        guard audit.attachmentCount == receipt.attachmentCount,
              audit.attachmentBytes == receipt.attachmentBytes
        else {
            throw VerificationError.attachmentInventoryMismatch
        }

        let attachmentDigests = try makeAttachmentDigests(
            for: backup,
            packageURL: packageURL
        )
        guard Set(receipt.attachments.map(\.fileName)).count == receipt.attachments.count else {
            throw VerificationError.attachmentInventoryMismatch
        }
        let expectedByName = Dictionary(
            uniqueKeysWithValues: receipt.attachments.map { ($0.fileName, $0) }
        )
        let actualByName = Dictionary(
            uniqueKeysWithValues: attachmentDigests.map { ($0.fileName, $0) }
        )
        guard expectedByName.keys == actualByName.keys else {
            throw VerificationError.attachmentInventoryMismatch
        }
        for fileName in expectedByName.keys.sorted() {
            guard expectedByName[fileName] == actualByName[fileName] else {
                throw VerificationError.attachmentDigestMismatch(fileName)
            }
        }

        return Report(audit: audit, assurance: .sourceVerified(receipt))
    }

    @MainActor
    static func compareWithLiveData(
        packageAt packageURL: URL,
        in context: ModelContext
    ) throws -> (verification: Report, comparison: RoutinaBackupAudit.ComparisonReport) {
        let verification = try verifyForRestore(packageAt: packageURL)
        let comparison = try RoutinaBackupAudit.compare(
            packageAt: packageURL,
            withLiveDataIn: context
        )
        return (verification, comparison)
    }

    static func loadReceiptIfPresent(packageAt packageURL: URL) -> Receipt? {
        let receiptURL = packageURL.appendingPathComponent(receiptFileName)
        guard let data = try? Data(contentsOf: receiptURL) else { return nil }
        return try? decode(data)
    }

    private static func makeAttachmentDigests(
        for backup: SettingsRoutineDataPersistence.Backup,
        packageURL: URL
    ) throws -> [AttachmentDigest] {
        let attachmentsURL = packageURL.appendingPathComponent(
            SettingsRoutineDataPersistence.attachmentsDirectoryName,
            isDirectory: true
        )
        return try (backup.attachments ?? []).map { attachment in
            let data = try Data(
                contentsOf: attachmentsURL.appendingPathComponent(attachment.fileName),
                options: .mappedIfSafe
            )
            return AttachmentDigest(
                fileName: attachment.fileName,
                byteCount: data.count,
                sha256: sha256Hex(data)
            )
        }
        .sorted { $0.fileName < $1.fileName }
    }

    private static func manifestURL(for packageURL: URL) -> URL {
        packageURL.appendingPathComponent(SettingsRoutineDataPersistence.manifestFileName)
    }

    private static func encode(_ receipt: Receipt) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(receipt)
    }

    private static func decode(_ data: Data) throws -> Receipt {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Receipt.self, from: data)
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

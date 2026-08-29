import CryptoKit
import Foundation
import SwiftData

@MainActor
public enum RoutinaBackupAudit {
    public struct Report: Equatable, Sendable {
        public let sourceSchemaVersion: Int
        public let currentSchemaVersion: Int
        public let recordCounts: [String: Int]
        public let attachmentCount: Int
        public let attachmentBytes: Int
        public let semanticFingerprint: String
        public let comparedSourceDirectly: Bool

        public var totalRecordCount: Int {
            recordCounts.values.reduce(0, +)
        }
    }

    public struct ComparisonReport: Equatable, Sendable {
        public let packageReport: Report
        public let liveRecordCounts: [String: Int]
        public let liveSemanticFingerprint: String
        public let matchesLiveData: Bool
        public let firstDifferencePath: String?
    }

    public struct PortableVerificationReport: Equatable, Sendable {
        public let audit: Report
        public let sourceReceiptVerified: Bool
        public let sourceVerifiedAt: Date?
    }

    public enum AuditError: LocalizedError, Equatable, Sendable {
        case invalidPackage(String)
        case unsupportedSchema(found: Int, supported: ClosedRange<Int>)
        case unsafeAttachmentFileName(String)
        case duplicateAttachmentID(String)
        case duplicateAttachmentFileName(String)
        case missingAttachment(String)
        case invalidAttachmentFile(String)
        case danglingAttachmentReference(String)
        case semanticMismatch(stage: String, path: String)

        public var errorDescription: String? {
            switch self {
            case let .invalidPackage(reason):
                return "Invalid Routina backup package: \(reason)"
            case let .unsupportedSchema(found, supported):
                return "Unsupported backup schema \(found); this build supports \(supported.lowerBound)...\(supported.upperBound)."
            case let .unsafeAttachmentFileName(fileName):
                return "Backup attachment uses an unsafe file name: \(fileName)"
            case let .duplicateAttachmentID(id):
                return "Backup declares the attachment ID more than once: \(id)"
            case let .duplicateAttachmentFileName(fileName):
                return "Backup declares the attachment file more than once: \(fileName)"
            case let .missingAttachment(fileName):
                return "Backup is missing attachment file: \(fileName)"
            case let .invalidAttachmentFile(fileName):
                return "Backup attachment is not a regular file: \(fileName)"
            case let .danglingAttachmentReference(id):
                return "Backup data references an attachment that is not declared: \(id)"
            case let .semanticMismatch(stage, path):
                return "Backup round-trip changed data during \(stage) at \(path)."
            }
        }
    }

    public static func audit(packageAt sourcePackageURL: URL) throws -> Report {
        let source = try PackageSnapshot(packageURL: sourcePackageURL)
        let supportedSchemas = 1...SettingsRoutineDataPersistence.currentSchemaVersion
        guard supportedSchemas.contains(source.backup.schemaVersion) else {
            throw AuditError.unsupportedSchema(
                found: source.backup.schemaVersion,
                supported: supportedSchemas
            )
        }

        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoutinaBackupAudit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        let firstContainer = try PersistenceController.makeLocalOnlyContainer(inMemory: true)
        _ = try SettingsRoutineDataPersistence.replaceAllRoutineDataForAudit(
            withBackupPackageAt: sourcePackageURL,
            in: firstContainer.mainContext,
            importDate: source.backup.exportedAt
        )

        let firstPackageURL = temporaryRoot
            .appendingPathComponent("first-restore")
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        try SettingsRoutineDataPersistence.writeBackupPackage(
            to: firstPackageURL,
            from: firstContainer.mainContext,
            exportedAt: source.backup.exportedAt,
            mirrorsUserDefaults: false
        )
        let firstRestore = try PackageSnapshot(packageURL: firstPackageURL)

        let comparesSourceDirectly =
            source.backup.schemaVersion == SettingsRoutineDataPersistence.currentSchemaVersion
        if comparesSourceDirectly {
            try compare(
                source,
                firstRestore,
                stage: "source-to-isolated-restore"
            )
        }

        let secondContainer = try PersistenceController.makeLocalOnlyContainer(inMemory: true)
        _ = try SettingsRoutineDataPersistence.replaceAllRoutineDataForAudit(
            withBackupPackageAt: firstPackageURL,
            in: secondContainer.mainContext,
            importDate: source.backup.exportedAt
        )

        let secondPackageURL = temporaryRoot
            .appendingPathComponent("second-restore")
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        try SettingsRoutineDataPersistence.writeBackupPackage(
            to: secondPackageURL,
            from: secondContainer.mainContext,
            exportedAt: source.backup.exportedAt,
            mirrorsUserDefaults: false
        )
        let secondRestore = try PackageSnapshot(packageURL: secondPackageURL)
        try compare(
            firstRestore,
            secondRestore,
            stage: "isolated-second-round-trip"
        )

        return Report(
            sourceSchemaVersion: source.backup.schemaVersion,
            currentSchemaVersion: SettingsRoutineDataPersistence.currentSchemaVersion,
            recordCounts: source.recordCounts,
            attachmentCount: source.attachmentCount,
            attachmentBytes: source.attachmentBytes,
            semanticFingerprint: firstRestore.semanticFingerprint,
            comparedSourceDirectly: comparesSourceDirectly
        )
    }

    public static func compare(
        packageAt sourcePackageURL: URL,
        withLiveDataIn context: ModelContext
    ) throws -> ComparisonReport {
        let packageReport = try audit(packageAt: sourcePackageURL)
        let packageSnapshot = try PackageSnapshot(packageURL: sourcePackageURL)

        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoutinaBackupLiveComparison-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        let livePackageURL = temporaryRoot
            .appendingPathComponent("live-source")
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        try SettingsRoutineDataPersistence.writeBackupPackage(
            to: livePackageURL,
            from: context,
            exportedAt: packageSnapshot.backup.exportedAt,
            mirrorsUserDefaults: false
        )
        let liveSnapshot = try PackageSnapshot(packageURL: livePackageURL)
        let differencePath = firstDifferencePath(
            packageSnapshot.canonicalObject,
            liveSnapshot.canonicalObject,
            path: "$"
        )

        return ComparisonReport(
            packageReport: packageReport,
            liveRecordCounts: liveSnapshot.recordCounts,
            liveSemanticFingerprint: liveSnapshot.semanticFingerprint,
            matchesLiveData: differencePath == nil,
            firstDifferencePath: differencePath
        )
    }

    public static func audit(
        packageAt sourcePackageURL: URL,
        matchingLiveDataIn context: ModelContext
    ) throws -> Report {
        let comparison = try compare(
            packageAt: sourcePackageURL,
            withLiveDataIn: context
        )
        guard comparison.matchesLiveData else {
            throw AuditError.semanticMismatch(
                stage: "live-source-to-backup",
                path: comparison.firstDifferencePath ?? "$"
            )
        }
        return comparison.packageReport
    }

    public static func audit(legacyJSONData: Data) throws -> Report {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoutinaLegacyBackupAudit-\(UUID().uuidString)", isDirectory: true)
        let packageURL = temporaryRoot
            .appendingPathComponent("legacy")
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        let attachmentsURL = packageURL.appendingPathComponent(
            SettingsRoutineDataPersistence.attachmentsDirectoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: attachmentsURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        try legacyJSONData.write(
            to: packageURL.appendingPathComponent(SettingsRoutineDataPersistence.manifestFileName),
            options: .atomic
        )
        return try audit(packageAt: packageURL)
    }

    public static func verifyPortableBackup(
        packageAt sourcePackageURL: URL
    ) throws -> PortableVerificationReport {
        let verification = try SettingsRoutineDataBackupVerification.verifyForRestore(
            packageAt: sourcePackageURL
        )
        switch verification.assurance {
        case let .sourceVerified(receipt):
            return PortableVerificationReport(
                audit: verification.audit,
                sourceReceiptVerified: true,
                sourceVerifiedAt: receipt.verifiedAt
            )
        case .isolatedRestoreOnly:
            return PortableVerificationReport(
                audit: verification.audit,
                sourceReceiptVerified: false,
                sourceVerifiedAt: nil
            )
        }
    }

    private static func compare(
        _ left: PackageSnapshot,
        _ right: PackageSnapshot,
        stage: String
    ) throws {
        guard left.canonicalData != right.canonicalData else { return }
        throw AuditError.semanticMismatch(
            stage: stage,
            path: firstDifferencePath(
                left.canonicalObject,
                right.canonicalObject,
                path: "$"
            ) ?? "$"
        )
    }
}

private extension RoutinaBackupAudit {
    struct PackageSnapshot {
        let backup: SettingsRoutineDataPersistence.Backup
        let canonicalObject: Any
        let canonicalData: Data
        let recordCounts: [String: Int]
        let attachmentCount: Int
        let attachmentBytes: Int
        let semanticFingerprint: String

        init(packageURL: URL) throws {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(
                atPath: packageURL.path,
                isDirectory: &isDirectory
            ), isDirectory.boolValue else {
                throw AuditError.invalidPackage("\(packageURL.lastPathComponent) is not a directory package.")
            }

            let manifestURL = packageURL.appendingPathComponent(
                SettingsRoutineDataPersistence.manifestFileName
            )
            guard FileManager.default.fileExists(atPath: manifestURL.path) else {
                throw AuditError.invalidPackage("manifest.json is missing.")
            }

            let manifestData = try Data(contentsOf: manifestURL)
            backup = try SettingsRoutineDataBackupCoding.decodeBackup(from: manifestData)

            let json = try JSONSerialization.jsonObject(with: manifestData)
            guard var root = json as? [String: Any] else {
                throw AuditError.invalidPackage("manifest.json does not contain an object.")
            }

            let attachmentsURL = packageURL.appendingPathComponent(
                SettingsRoutineDataPersistence.attachmentsDirectoryName,
                isDirectory: true
            )
            let attachmentResult = try Self.normalizeAttachments(
                in: &root,
                attachmentsURL: attachmentsURL
            )
            root.removeValue(forKey: "exportedAt")
            Self.sortTopLevelCollections(in: &root)

            canonicalObject = root
            canonicalData = try JSONSerialization.data(
                withJSONObject: root,
                options: [.sortedKeys, .withoutEscapingSlashes]
            )
            recordCounts = Self.recordCounts(for: backup)
            attachmentCount = attachmentResult.count
            attachmentBytes = attachmentResult.bytes
            semanticFingerprint = Self.sha256Hex(canonicalData)
        }

        private static func normalizeAttachments(
            in root: inout [String: Any],
            attachmentsURL: URL
        ) throws -> (count: Int, bytes: Int) {
            let rawAttachments = root["attachments"] as? [Any] ?? []
            var attachments: [[String: Any]] = []
            var declaredIDs: Set<String> = []
            var declaredFileNames: Set<String> = []
            var volatileReplacements: [String: String] = [:]
            var totalBytes = 0

            for rawAttachment in rawAttachments {
                guard var attachment = rawAttachment as? [String: Any],
                      let id = attachment["id"] as? String,
                      let role = attachment["role"] as? String,
                      let fileName = attachment["fileName"] as? String
                else {
                    throw AuditError.invalidPackage("an attachment manifest is malformed.")
                }

                guard declaredIDs.insert(id).inserted else {
                    throw AuditError.duplicateAttachmentID(id)
                }
                guard declaredFileNames.insert(fileName).inserted else {
                    throw AuditError.duplicateAttachmentFileName(fileName)
                }
                guard isSafeAttachmentFileName(fileName) else {
                    throw AuditError.unsafeAttachmentFileName(fileName)
                }

                let fileURL = attachmentsURL.appendingPathComponent(fileName)
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    throw AuditError.missingAttachment(fileName)
                }
                let resourceValues = try fileURL.resourceValues(
                    forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
                )
                guard resourceValues.isRegularFile == true,
                      resourceValues.isSymbolicLink != true
                else {
                    throw AuditError.invalidAttachmentFile(fileName)
                }

                let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
                totalBytes += data.count
                let contentHash = sha256Hex(data)
                attachment["contentSHA256"] = contentHash

                if volatileAttachmentRoles.contains(role) {
                    let owner = (attachment["taskID"] as? String)
                        ?? (attachment["placeCheckInSessionID"] as? String)
                        ?? (attachment["noteID"] as? String)
                        ?? "unowned"
                    let originalFileName = attachment["originalFileName"] as? String ?? ""
                    let stableIdentity = [role, owner, originalFileName, contentHash]
                        .joined(separator: "|")
                    let stableToken = "audit-media-\(sha256Hex(Data(stableIdentity.utf8)))"
                    volatileReplacements[id] = stableToken
                    volatileReplacements[fileName] = stableToken
                    attachment["id"] = stableToken
                    attachment["fileName"] = stableToken
                }

                attachments.append(attachment)
            }

            try validateAttachmentReferences(in: root, declaredIDs: declaredIDs)
            root["attachments"] = attachments
            root = replacingStrings(in: root, using: volatileReplacements) as? [String: Any] ?? root
            return (attachments.count, totalBytes)
        }

        private static let volatileAttachmentRoles: Set<String> = [
            "taskImage",
            "taskVoiceNote",
            "placeCheckInImage",
            "noteImage",
            "noteVoiceNote",
        ]

        private static func validateAttachmentReferences(
            in value: Any,
            declaredIDs: Set<String>
        ) throws {
            if let dictionary = value as? [String: Any] {
                for (key, child) in dictionary {
                    if key.hasSuffix("AttachmentID"), let id = child as? String,
                       !declaredIDs.contains(id) {
                        throw AuditError.danglingAttachmentReference(id)
                    }
                    try validateAttachmentReferences(in: child, declaredIDs: declaredIDs)
                }
                return
            }
            if let array = value as? [Any] {
                for child in array {
                    try validateAttachmentReferences(in: child, declaredIDs: declaredIDs)
                }
            }
        }

        private static func isSafeAttachmentFileName(_ fileName: String) -> Bool {
            !fileName.isEmpty
                && !fileName.contains("/")
                && URL(fileURLWithPath: fileName).lastPathComponent == fileName
        }

        private static func replacingStrings(
            in value: Any,
            using replacements: [String: String]
        ) -> Any {
            if let string = value as? String {
                return replacements[string] ?? string
            }
            if let dictionary = value as? [String: Any] {
                return dictionary.mapValues { replacingStrings(in: $0, using: replacements) }
            }
            if let array = value as? [Any] {
                return array.map { replacingStrings(in: $0, using: replacements) }
            }
            return value
        }

        private static func sortTopLevelCollections(in root: inout [String: Any]) {
            for (key, value) in root {
                guard let array = value as? [Any] else { continue }
                root[key] = array.sorted {
                    canonicalSortData(for: $0).lexicographicallyPrecedes(
                        canonicalSortData(for: $1)
                    )
                }
            }
        }

        fileprivate static func canonicalSortData(for value: Any) -> Data {
            (try? JSONSerialization.data(
                withJSONObject: value,
                options: [.sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
            )) ?? Data()
        }

        private static func recordCounts(
            for backup: SettingsRoutineDataPersistence.Backup
        ) -> [String: Int] {
            [
                "Away sessions": backup.awaySessions?.count ?? 0,
                "Backlog assignments": backup.backlogAssignments?.count ?? 0,
                "Backlogs": backup.boardBacklogs?.count ?? 0,
                "Device action logs": backup.deviceActionLogs?.count ?? 0,
                "Device sessions": backup.deviceSessions?.count ?? 0,
                "Emotions": backup.emotionLogs?.count ?? 0,
                "Events": backup.events?.count ?? 0,
                "Focus sessions": backup.focusSessions?.count ?? 0,
                "Goals": backup.goals?.count ?? 0,
                "Logs": backup.logs.count,
                "Notes": backup.notes?.count ?? 0,
                "Place check-ins": backup.placeCheckInSessions?.count ?? 0,
                "Places": backup.places?.count ?? 0,
                "Planner blocks": backup.dayPlanBlocks?.count ?? 0,
                "Sleep sessions": backup.sleepSessions?.count ?? 0,
                "Sprint assignments": backup.sprintAssignments?.count ?? 0,
                "Sprint focus allocations": backup.sprintFocusAllocations?.count ?? 0,
                "Sprint focus sessions": backup.sprintFocusSessions?.count ?? 0,
                "Sprints": backup.boardSprints?.count ?? 0,
                "Tasks": backup.tasks.count,
                "User preferences": backup.userPreferences == nil ? 0 : 1,
            ]
        }

        private static func sha256Hex(_ data: Data) -> String {
            SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
    }

    static func firstDifferencePath(
        _ left: Any,
        _ right: Any,
        path: String
    ) -> String? {
        if let leftDictionary = left as? [String: Any],
           let rightDictionary = right as? [String: Any] {
            let keys = Set(leftDictionary.keys).union(rightDictionary.keys).sorted()
            for key in keys {
                guard let leftValue = leftDictionary[key],
                      let rightValue = rightDictionary[key]
                else {
                    return "\(path).\(key)"
                }
                if let difference = firstDifferencePath(
                    leftValue,
                    rightValue,
                    path: "\(path).\(key)"
                ) {
                    return difference
                }
            }
            return nil
        }

        if let leftArray = left as? [Any], let rightArray = right as? [Any] {
            guard leftArray.count == rightArray.count else {
                return "\(path).count"
            }
            for index in leftArray.indices {
                if let difference = firstDifferencePath(
                    leftArray[index],
                    rightArray[index],
                    path: "\(path)[\(index)]"
                ) {
                    return difference
                }
            }
            return nil
        }

        let leftData = PackageSnapshot.canonicalSortData(for: left)
        let rightData = PackageSnapshot.canonicalSortData(for: right)
        return leftData == rightData ? nil : path
    }
}

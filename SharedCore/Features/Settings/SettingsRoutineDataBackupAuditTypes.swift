import Foundation

public extension RoutinaBackupAudit {
    struct Report: Equatable, Sendable {
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

    struct ComparisonReport: Equatable, Sendable {
        public let packageReport: Report
        public let liveRecordCounts: [String: Int]
        public let liveSemanticFingerprint: String
        public let matchesLiveData: Bool
        public let firstDifferencePath: String?
    }

    struct PortableVerificationReport: Equatable, Sendable {
        public let audit: Report
        public let sourceReceiptVerified: Bool
        public let sourceVerifiedAt: Date?
    }

    enum AuditError: LocalizedError, Equatable, Sendable {
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
}

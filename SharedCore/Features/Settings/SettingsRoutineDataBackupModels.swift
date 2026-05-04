import Foundation

extension SettingsRoutineDataPersistence {
    struct Backup: Codable {
        var schemaVersion: Int
        var exportedAt: Date
        var places: [Place]?
        var goals: [Goal]?
        var tasks: [Task]
        var logs: [Log]
        var attachments: [Attachment]?

        struct Place: Codable {
            var id: UUID
            var name: String
            var latitude: Double
            var longitude: Double
            var radiusMeters: Double
            var createdAt: Date?
        }

        struct Goal: Codable {
            var id: UUID
            var title: String
            var emoji: String?
            var notes: String?
            var targetDate: Date?
            var status: RoutineGoalStatus?
            var color: RoutineTaskColor?
            var createdAt: Date?
            var sortOrder: Int?
        }

        struct Task: Codable {
            var id: UUID
            var name: String?
            var emoji: String?
            var notes: String?
            var link: String?
            var deadline: Date?
            var reminderAt: Date?
            var imageData: Data?
            var imageAttachmentID: UUID?
            var placeID: UUID?
            var tags: [String]?
            var goalIDs: [UUID]?
            var steps: [RoutineStep]?
            var checklistItems: [RoutineChecklistItem]?
            var scheduleMode: RoutineScheduleMode?
            var interval: Int
            var recurrenceRule: RoutineRecurrenceRule?
            var lastDone: Date?
            var canceledAt: Date?
            var scheduleAnchor: Date?
            var pausedAt: Date?
            var snoozedUntil: Date?
            var pinnedAt: Date?
            var completedStepCount: Int?
            var sequenceStartedAt: Date?
            var createdAt: Date?
            var todoStateRawValue: String?
            var activityStateRawValue: String?
            var ongoingSince: Date?
            var autoAssumeDailyDone: Bool?
            var estimatedDurationMinutes: Int?
            var actualDurationMinutes: Int?
            var storyPoints: Int?
            var pressure: RoutineTaskPressure?
            var pressureUpdatedAt: Date?
        }

        struct Log: Codable {
            var id: UUID
            var timestamp: Date?
            var taskID: UUID
            var kind: RoutineLogKind?
            var actualDurationMinutes: Int?
        }

        struct Attachment: Codable {
            enum Role: String, Codable {
                case taskImage
                case fileAttachment
            }

            var id: UUID
            var taskID: UUID
            var role: Role
            var fileName: String
            var originalFileName: String?
            var createdAt: Date?
        }
    }

    struct ImportSummary {
        var places: Int
        var goals: Int
        var tasks: Int
        var logs: Int
        var attachments: Int
    }

    enum Error: LocalizedError {
        case unsupportedSchema(Int)
        case invalidBackupPackage(URL)
        case missingAttachment(String)

        var errorDescription: String? {
            switch self {
            case let .unsupportedSchema(version):
                return "Unsupported backup format version: \(version)."
            case let .invalidBackupPackage(url):
                return "Invalid Routina backup package: \(url.lastPathComponent)."
            case let .missingAttachment(fileName):
                return "Backup is missing attachment file: \(fileName)."
            }
        }
    }
}

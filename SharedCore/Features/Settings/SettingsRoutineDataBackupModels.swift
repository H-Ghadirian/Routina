import Foundation

extension SettingsRoutineDataPersistence {
    struct Backup: Codable {
        var schemaVersion: Int
        var exportedAt: Date
        var places: [Place]?
        var goals: [Goal]?
        var tasks: [Task]
        var logs: [Log]
        var sleepSessions: [Sleep]?
        var placeCheckInSessions: [PlaceCheckIn]?
        var emotionLogs: [Emotion]?
        var notes: [Note]?
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
            var tags: [String]?
            var status: RoutineGoalStatus?
            var color: RoutineTaskColor?
            var parentGoalID: UUID?
            var rejectedTaskSuggestionIDs: [UUID]?
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
            var voiceNoteData: Data?
            var voiceNoteAttachmentID: UUID?
            var voiceNoteDurationSeconds: Double?
            var voiceNoteCreatedAt: Date?
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
            var comments: [RoutineTaskComment]? = nil
        }

        struct Log: Codable {
            var id: UUID
            var timestamp: Date?
            var taskID: UUID
            var kind: RoutineLogKind?
            var actualDurationMinutes: Int?
        }

        struct Sleep: Codable {
            var id: UUID
            var startedAt: Date?
            var endedAt: Date?
            var targetDurationMinutes: Int?
            var createdAt: Date?
            var updatedAt: Date?
        }

        struct PlaceCheckIn: Codable {
            var id: UUID
            var placeID: UUID?
            var placeName: String
            var latitude: Double?
            var longitude: Double?
            var horizontalAccuracyMeters: Double?
            var placeRadiusMeters: Double?
            var activity: PlaceCheckInActivity?
            var note: String?
            var imageData: Data?
            var imageAttachmentID: UUID?
            var startedAt: Date?
            var endedAt: Date?
            var createdAt: Date?
            var updatedAt: Date?
            var captureMode: PlaceCheckInCaptureMode?
            var confirmedAt: Date?
        }

        struct Emotion: Codable {
            var id: UUID
            var family: EmotionFamily
            var label: String
            var valence: Double
            var arousal: Double
            var intensity: Int
            var bodyAreas: [EmotionBodyArea]?
            var reflection: String?
            var linkedNoteID: UUID?
            var linkedGoalID: UUID?
            var linkedTaskID: UUID?
            var linkedPlaceID: UUID?
            var linkedSleepSessionID: UUID?
            var createdAt: Date?
            var updatedAt: Date?
        }

        struct Note: Codable {
            var id: UUID
            var title: String?
            var body: String?
            var tags: [String]?
            var imageData: Data?
            var imageAttachmentID: UUID?
            var voiceNoteData: Data?
            var voiceNoteAttachmentID: UUID?
            var voiceNoteDurationSeconds: Double?
            var voiceNoteCreatedAt: Date?
            var createdAt: Date?
            var updatedAt: Date?
        }

        struct Attachment: Codable {
            enum Role: String, Codable {
                case taskImage
                case taskVoiceNote
                case placeCheckInImage
                case fileAttachment
                case noteImage
                case noteVoiceNote
                case noteFileAttachment
            }

            var id: UUID
            var taskID: UUID?
            var placeCheckInSessionID: UUID?
            var noteID: UUID?
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
        var sleepSessions: Int = 0
        var placeCheckInSessions: Int = 0
        var emotionLogs: Int = 0
        var notes: Int = 0
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

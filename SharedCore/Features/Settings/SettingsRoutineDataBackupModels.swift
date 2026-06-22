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
        var awaySessions: [Away]?
        var placeCheckInSessions: [PlaceCheckIn]?
        var emotionLogs: [Emotion]?
        var notes: [Note]?
        var events: [Event]?
        var attachments: [Attachment]?
        var focusSessions: [Focus]? = nil
        var dayPlanBlocks: [DayPlanBlock]? = nil
        var boardSprints: [BoardSprint]? = nil
        var sprintAssignments: [SprintAssignment]? = nil
        var boardBacklogs: [BoardBacklog]? = nil
        var backlogAssignments: [BacklogAssignment]? = nil
        var sprintFocusSessions: [SprintFocus]? = nil
        var sprintFocusAllocations: [SprintFocusAllocation]? = nil
        var deviceSessions: [DeviceSession]? = nil
        var deviceActionLogs: [DeviceActionLog]? = nil
        var userPreferences: UserPreferences? = nil

        struct Place: Codable {
            var id: UUID
            var name: String
            var kind: String?
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
            var links: [String]?
            var linkItems: [RoutineTaskLink]?
            var deadline: Date?
            var plannedDate: Date?
            var isAllDay: Bool?
            var routineDurationMode: RoutineDurationMode?
            var availabilityStartDate: Date?
            var availabilityEndDate: Date?
            var reminderAt: Date?
            var imageData: Data?
            var imageAttachmentID: UUID?
            var voiceNoteData: Data?
            var voiceNoteAttachmentID: UUID?
            var voiceNoteDurationSeconds: Double?
            var voiceNoteCreatedAt: Date?
            var placeID: UUID?
            var placeIDs: [UUID]?
            var tags: [String]?
            var goalIDs: [UUID]?
            var eventIDs: [UUID]?
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
            var autoAssumeDoneTimeOfDay: RoutineTimeOfDay?
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

        struct Away: Codable {
            var id: UUID
            var preset: AwaySessionPreset?
            var title: String?
            var linkedTaskID: UUID?
            var startedAt: Date?
            var plannedDurationSeconds: TimeInterval?
            var completedAt: Date?
            var endedEarlyAt: Date?
            var extensionCount: Int?
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
            var families: [EmotionFamily]?
            var labels: [String]?
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

        struct Event: Codable {
            var id: UUID
            var title: String?
            var notes: String?
            var emoji: String?
            var tags: [String]?
            var isAllDay: Bool?
            var startedAt: Date?
            var endedAt: Date?
            var reminderAt: Date?
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

        struct Focus: Codable {
            var id: UUID
            var taskID: UUID
            var tagName: String?
            var startedAt: Date?
            var plannedDurationSeconds: TimeInterval
            var completedAt: Date?
            var abandonedAt: Date?
            var pausedAt: Date?
            var accumulatedPausedSeconds: TimeInterval?
        }

        struct DayPlanBlock: Codable {
            var id: UUID
            var taskID: UUID
            var dayKey: String
            var startMinute: Int
            var durationMinutes: Int
            var titleSnapshot: String
            var emojiSnapshot: String?
            var createdAt: Date
            var updatedAt: Date
        }

        struct BoardSprint: Codable {
            var id: UUID
            var title: String
            var status: SprintStatus
            var createdAt: Date
            var startedAt: Date?
            var finishedAt: Date?
        }

        struct SprintAssignment: Codable {
            var todoID: UUID
            var sprintID: UUID
            var sortOrder: Int?
        }

        struct BoardBacklog: Codable {
            var id: UUID
            var title: String
            var createdAt: Date
            var routingTags: [String]?
        }

        struct BacklogAssignment: Codable {
            var todoID: UUID
            var backlogID: UUID
            var sortOrder: Int?
        }

        struct SprintFocus: Codable {
            var id: UUID
            var sprintID: UUID
            var startedAt: Date
            var stoppedAt: Date?
            var pausedAt: Date?
            var accumulatedPausedSeconds: TimeInterval?
        }

        struct SprintFocusAllocation: Codable {
            var id: UUID
            var sessionID: UUID
            var taskID: UUID
            var minutes: Int
            var sortOrder: Int?
        }

        struct DeviceSession: Codable {
            var id: UUID
            var installationID: String
            var displayName: String
            var platform: RoutinaDevicePlatform
            var modelName: String
            var systemName: String
            var systemVersion: String
            var appVersion: String
            var bundleIdentifier: String
            var firstSeenAt: Date
            var lastSeenAt: Date
            var lastActiveAt: Date
            var lastMutationAt: Date?
        }

        struct DeviceActionLog: Codable {
            var id: UUID
            var timestamp: Date
            var action: RoutinaDeviceActionKind
            var entity: RoutinaDeviceActionEntity
            var entityID: String
            var entityTitle: String?
            var deviceInstallationID: String
            var deviceDisplayName: String
            var devicePlatform: RoutinaDevicePlatform
            var deviceModelName: String
            var systemName: String
            var systemVersion: String
            var appVersion: String
            var details: String?
        }

        struct UserPreferences: Codable {
            var id: String
            var selectedAppIcon: String?
            var appColorScheme: String?
            var routineListSectioningMode: String?
            var tagCounterDisplayMode: String?
            var homeTaskRowHiddenFields: String?
            var relatedTagRules: String?
            var tagColors: String?
            var fastFilterTags: String?
            var iOSStatsDashboardHiddenItemIDs: String?
            var iOSStatsDashboardItemOrderIDs: String?
            var iOSStatsSummaryDisplayMode: String?
            var macStatsDashboardHiddenItemIDs: String?
            var macStatsDashboardItemOrderIDs: String?
            var macStatsSummaryDisplayMode: String?
            var hiddenDayPlanTimelineActivityIDs: String?
            var protectionBlockingEnabledModes: String?
            var blockingWebsiteDomains: String?
            var focusShieldSelection: String?
            var macFocusBlockedApps: String?
            var macFormSectionOrder: String?
            var macQuickAddShortcut: String?
            var macAdventureOwnedItemIDs: String?
            var macAdventureUnlockedWorldIDs: String?
            var macAdventureUnlockedStageIDs: String?
            var notificationsEnabled: Bool?
            var hideUnavailableRoutines: Bool?
            var appLockEnabled: Bool?
            var gitFeaturesEnabled: Bool?
            var taskSharingEnabled: Bool?
            var taskRelationshipVisualizerEnabled: Bool?
            var showPersianDates: Bool?
            var batteryRoutineMonitoringEnabled: Bool?
            var sleepHomeActionEnabled: Bool?
            var sleepHomeMenuEnabled: Bool?
            var shakeToStartSleepEnabled: Bool?
            var focusShieldEnabled: Bool?
            var macFocusAppBlockingEnabled: Bool?
            var automaticPlaceCheckInEnabled: Bool?
            var showTimelineTasksInDayPlanner: Bool?
            var separateDailyRoutinesInTaskList: Bool?
            var notificationReminderHour: Int?
            var notificationReminderMinute: Int?
            var batteryRoutineThresholdPercent: Int?
            var updatedAt: Date?
        }
    }

    struct ImportSummary {
        var places: Int
        var goals: Int
        var tasks: Int
        var logs: Int
        var sleepSessions: Int = 0
        var awaySessions: Int = 0
        var placeCheckInSessions: Int = 0
        var emotionLogs: Int = 0
        var notes: Int = 0
        var events: Int = 0
        var attachments: Int
        var focusSessions: Int = 0
        var dayPlanBlocks: Int = 0
        var boardSprints: Int = 0
        var sprintAssignments: Int = 0
        var boardBacklogs: Int = 0
        var backlogAssignments: Int = 0
        var sprintFocusSessions: Int = 0
        var sprintFocusAllocations: Int = 0
        var deviceSessions: Int = 0
        var deviceActionLogs: Int = 0
        var userPreferences: Int = 0
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

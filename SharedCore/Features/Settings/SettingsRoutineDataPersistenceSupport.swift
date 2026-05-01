import Foundation
import SwiftData

enum SettingsRoutineDataPersistence {
    static let currentSchemaVersion = 16
    static let legacyJSONSchemaVersion = 14
    static let backupPackageExtension = "routinabackup"
    static let manifestFileName = "manifest.json"
    static let attachmentsDirectoryName = "attachments"

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

    static func defaultBackupFileName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "routina-backup-\(formatter.string(from: now)).\(backupPackageExtension)"
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
            places: places.map {
                .init(
                    id: $0.id,
                    name: $0.displayName,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    radiusMeters: $0.radiusMeters,
                    createdAt: $0.createdAt
                )
            },
            goals: goals.map {
                .init(
                    id: $0.id,
                    title: $0.displayTitle,
                    emoji: $0.emoji,
                    notes: $0.notes,
                    targetDate: $0.targetDate,
                    status: $0.status,
                    color: $0.color,
                    createdAt: $0.createdAt,
                    sortOrder: $0.sortOrder
                )
            },
            tasks: tasks.map {
                .init(
                    id: $0.id,
                    name: $0.name,
                    emoji: $0.emoji,
                    notes: $0.notes,
                    link: $0.link,
                    deadline: $0.deadline,
                    reminderAt: $0.reminderAt,
                    imageData: $0.imageData,
                    imageAttachmentID: nil,
                    placeID: $0.placeID,
                    tags: $0.tags,
                    goalIDs: $0.goalIDs,
                    steps: $0.steps,
                    checklistItems: $0.checklistItems,
                    scheduleMode: $0.scheduleMode,
                    interval: max(Int($0.interval), 1),
                    recurrenceRule: $0.recurrenceRule,
                    lastDone: $0.lastDone,
                    canceledAt: $0.canceledAt,
                    scheduleAnchor: $0.scheduleAnchor,
                    pausedAt: $0.pausedAt,
                    snoozedUntil: $0.snoozedUntil,
                    pinnedAt: $0.pinnedAt,
                    completedStepCount: $0.completedSteps,
                    sequenceStartedAt: $0.sequenceStartedAt,
                    createdAt: $0.createdAt,
                    todoStateRawValue: $0.todoStateRawValue,
                    activityStateRawValue: $0.activityStateRawValue,
                    ongoingSince: $0.ongoingSince,
                    autoAssumeDailyDone: $0.autoAssumeDailyDone,
                    estimatedDurationMinutes: $0.estimatedDurationMinutes,
                    actualDurationMinutes: $0.actualDurationMinutes,
                    storyPoints: $0.storyPoints,
                    pressure: $0.pressure,
                    pressureUpdatedAt: $0.pressureUpdatedAt
                )
            },
            logs: logs.map {
                .init(
                    id: $0.id,
                    timestamp: $0.timestamp,
                    taskID: $0.taskID,
                    kind: $0.kind,
                    actualDurationMinutes: $0.actualDurationMinutes
                )
            },
            attachments: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
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

        let manifestData = try buildBackupManifestData(
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
        var files: [String: Data] = [:]
        let manifestData = try buildBackupManifestData(
            from: context,
            writeAttachment: { fileName, data in
                files[fileName] = data
            },
            exportedAt: exportedAt
        )
        return (manifestData, files)
    }

    @MainActor
    private static func buildBackupManifestData(
        from context: ModelContext,
        attachmentsDirectoryURL: URL,
        exportedAt: Date
    ) throws -> Data {
        try buildBackupManifestData(
            from: context,
            writeAttachment: { fileName, data in
                try data.write(to: attachmentsDirectoryURL.appendingPathComponent(fileName), options: .atomic)
            },
            exportedAt: exportedAt
        )
    }

    @MainActor
    private static func buildBackupManifestData(
        from context: ModelContext,
        writeAttachment: (String, Data) throws -> Void,
        exportedAt: Date
    ) throws -> Data {
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let storedAttachments = try context.fetch(FetchDescriptor<RoutineAttachment>())

        var attachmentManifests: [Backup.Attachment] = []
        var taskImageAttachmentIDs: [UUID: UUID] = [:]

        for task in tasks {
            guard let imageData = task.imageData, !imageData.isEmpty else { continue }
            let attachmentID = UUID()
            let fileName = "\(attachmentID.uuidString).task-image"
            try writeAttachment(fileName, imageData)
            taskImageAttachmentIDs[task.id] = attachmentID
            attachmentManifests.append(
                .init(
                    id: attachmentID,
                    taskID: task.id,
                    role: .taskImage,
                    fileName: fileName,
                    originalFileName: "task-image",
                    createdAt: task.createdAt ?? exportedAt
                )
            )
        }

        for attachment in storedAttachments {
            guard !attachment.data.isEmpty else { continue }
            let fileName = packageAttachmentFileName(for: attachment)
            try writeAttachment(fileName, attachment.data)
            attachmentManifests.append(
                .init(
                    id: attachment.id,
                    taskID: attachment.taskID,
                    role: .fileAttachment,
                    fileName: fileName,
                    originalFileName: attachment.fileName,
                    createdAt: attachment.createdAt
                )
            )
        }

        let backup = Backup(
            schemaVersion: currentSchemaVersion,
            exportedAt: exportedAt,
            places: places.map {
                .init(
                    id: $0.id,
                    name: $0.displayName,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    radiusMeters: $0.radiusMeters,
                    createdAt: $0.createdAt
                )
            },
            goals: goals.map {
                .init(
                    id: $0.id,
                    title: $0.displayTitle,
                    emoji: $0.emoji,
                    notes: $0.notes,
                    targetDate: $0.targetDate,
                    status: $0.status,
                    color: $0.color,
                    createdAt: $0.createdAt,
                    sortOrder: $0.sortOrder
                )
            },
            tasks: tasks.map {
                .init(
                    id: $0.id,
                    name: $0.name,
                    emoji: $0.emoji,
                    notes: $0.notes,
                    link: $0.link,
                    deadline: $0.deadline,
                    reminderAt: $0.reminderAt,
                    imageData: nil,
                    imageAttachmentID: taskImageAttachmentIDs[$0.id],
                    placeID: $0.placeID,
                    tags: $0.tags,
                    goalIDs: $0.goalIDs,
                    steps: $0.steps,
                    checklistItems: $0.checklistItems,
                    scheduleMode: $0.scheduleMode,
                    interval: max(Int($0.interval), 1),
                    recurrenceRule: $0.recurrenceRule,
                    lastDone: $0.lastDone,
                    canceledAt: $0.canceledAt,
                    scheduleAnchor: $0.scheduleAnchor,
                    pausedAt: $0.pausedAt,
                    snoozedUntil: $0.snoozedUntil,
                    pinnedAt: $0.pinnedAt,
                    completedStepCount: $0.completedSteps,
                    sequenceStartedAt: $0.sequenceStartedAt,
                    createdAt: $0.createdAt,
                    todoStateRawValue: $0.todoStateRawValue,
                    activityStateRawValue: $0.activityStateRawValue,
                    ongoingSince: $0.ongoingSince,
                    autoAssumeDailyDone: $0.autoAssumeDailyDone,
                    estimatedDurationMinutes: $0.estimatedDurationMinutes,
                    actualDurationMinutes: $0.actualDurationMinutes,
                    storyPoints: $0.storyPoints
                )
            },
            logs: logs.map {
                .init(
                    id: $0.id,
                    timestamp: $0.timestamp,
                    taskID: $0.taskID,
                    kind: $0.kind,
                    actualDurationMinutes: $0.actualDurationMinutes
                )
            },
            attachments: attachmentManifests
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    @MainActor
    static func replaceAllRoutineData(
        with jsonData: Data,
        in context: ModelContext,
        importDate: Date = Date()
    ) throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: jsonData)

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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: manifestData)

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
            let existingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
            for log in existingLogs {
                context.delete(log)
            }

            let existingAttachments = try context.fetch(FetchDescriptor<RoutineAttachment>())
            for attachment in existingAttachments {
                context.delete(attachment)
            }

            let existingTasks = try context.fetch(FetchDescriptor<RoutineTask>())
            for task in existingTasks {
                context.delete(task)
            }

            let existingGoals = try context.fetch(FetchDescriptor<RoutineGoal>())
            for goal in existingGoals {
                context.delete(goal)
            }

            let existingPlaces = try context.fetch(FetchDescriptor<RoutinePlace>())
            for place in existingPlaces {
                context.delete(place)
            }

            var importedPlaceIDs = Set<UUID>()
            var importedPlaceCount = 0
            for place in backup.places ?? [] {
                guard importedPlaceIDs.insert(place.id).inserted else { continue }

                let importedPlace = RoutinePlace(
                    id: place.id,
                    name: place.name,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    radiusMeters: place.radiusMeters,
                    createdAt: place.createdAt ?? importDate
                )
                context.insert(importedPlace)
                importedPlaceCount += 1
            }

            var importedGoalIDs = Set<UUID>()
            var importedGoalCount = 0
            for goal in backup.goals ?? [] {
                guard importedGoalIDs.insert(goal.id).inserted else { continue }
                guard RoutineGoal.cleanedTitle(goal.title) != nil else { continue }

                let importedGoal = RoutineGoal(
                    id: goal.id,
                    title: goal.title,
                    emoji: goal.emoji,
                    notes: goal.notes,
                    targetDate: goal.targetDate,
                    status: goal.status ?? .active,
                    color: goal.color ?? .none,
                    createdAt: goal.createdAt ?? importDate,
                    sortOrder: goal.sortOrder ?? importedGoalCount
                )
                context.insert(importedGoal)
                importedGoalCount += 1
            }

            var importedTaskIDs = Set<UUID>()
            var importedTaskCount = 0
            var attachmentManifestsByID: [UUID: Backup.Attachment] = [:]
            for attachment in backup.attachments ?? [] {
                attachmentManifestsByID[attachment.id] = attachment
            }
            for task in backup.tasks {
                guard importedTaskIDs.insert(task.id).inserted else { continue }

                let clampedInterval = min(max(task.interval, 1), Int(Int16.max))
                let imageData: Data?
                if let imageAttachmentID = task.imageAttachmentID,
                   let imageAttachment = attachmentManifestsByID[imageAttachmentID] {
                    imageData = try attachmentData(imageAttachment.fileName)
                    if imageData == nil {
                        throw Error.missingAttachment(imageAttachment.fileName)
                    }
                } else {
                    imageData = task.imageData
                }

                let importedTask = RoutineTask(
                    id: task.id,
                    name: task.name,
                    emoji: task.emoji,
                    notes: task.notes,
                    link: task.link,
                    deadline: task.deadline,
                    reminderAt: task.reminderAt,
                    pressure: task.pressure ?? .none,
                    pressureUpdatedAt: task.pressureUpdatedAt,
                    imageData: imageData,
                    placeID: task.placeID.flatMap { importedPlaceIDs.contains($0) ? $0 : nil },
                    tags: task.tags ?? [],
                    goalIDs: (task.goalIDs ?? []).filter { importedGoalIDs.contains($0) },
                    steps: task.steps ?? [],
                    checklistItems: task.checklistItems ?? [],
                    scheduleMode: task.scheduleMode,
                    interval: Int16(clampedInterval),
                    recurrenceRule: task.recurrenceRule,
                    lastDone: task.lastDone,
                    canceledAt: task.canceledAt,
                    scheduleAnchor: task.scheduleAnchor,
                    pausedAt: task.pausedAt,
                    snoozedUntil: task.snoozedUntil,
                    pinnedAt: task.pinnedAt,
                    completedStepCount: Int16(clamping: task.completedStepCount ?? 0),
                    sequenceStartedAt: task.sequenceStartedAt,
                    createdAt: task.createdAt,
                    todoStateRawValue: task.todoStateRawValue,
                    activityStateRawValue: task.activityStateRawValue,
                    ongoingSince: task.ongoingSince,
                    autoAssumeDailyDone: task.autoAssumeDailyDone ?? false,
                    estimatedDurationMinutes: task.estimatedDurationMinutes,
                    actualDurationMinutes: task.actualDurationMinutes,
                    storyPoints: task.storyPoints
                )
                context.insert(importedTask)
                importedTaskCount += 1
            }

            var importedAttachmentIDs = Set<UUID>()
            var importedAttachmentCount = 0
            for attachment in backup.attachments ?? [] where attachment.role == .fileAttachment {
                guard importedTaskIDs.contains(attachment.taskID) else { continue }
                guard importedAttachmentIDs.insert(attachment.id).inserted else { continue }
                guard let data = try attachmentData(attachment.fileName) else {
                    if backup.schemaVersion >= currentSchemaVersion {
                        throw Error.missingAttachment(attachment.fileName)
                    }
                    continue
                }

                let importedAttachment = RoutineAttachment(
                    id: attachment.id,
                    taskID: attachment.taskID,
                    fileName: attachment.originalFileName ?? attachment.fileName,
                    data: data,
                    createdAt: attachment.createdAt ?? importDate
                )
                context.insert(importedAttachment)
                importedAttachmentCount += 1
            }

            var importedLogIDs = Set<UUID>()
            var importedLogCount = 0
            for log in backup.logs {
                guard importedTaskIDs.contains(log.taskID) else { continue }
                guard importedLogIDs.insert(log.id).inserted else { continue }

                let importedLog = RoutineLog(
                    id: log.id,
                    timestamp: log.timestamp,
                    taskID: log.taskID,
                    kind: log.kind ?? .completed,
                    actualDurationMinutes: log.actualDurationMinutes
                )
                context.insert(importedLog)
                importedLogCount += 1
            }

            try context.save()
            return ImportSummary(
                places: importedPlaceCount,
                goals: importedGoalCount,
                tasks: importedTaskCount,
                logs: importedLogCount,
                attachments: importedAttachmentCount
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func packageAttachmentFileName(for attachment: RoutineAttachment) -> String {
        "\(attachment.id.uuidString)-\(sanitizedFileName(attachment.fileName, fallback: "attachment"))"
    }

    private static func sanitizedFileName(_ fileName: String, fallback: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:")
            .union(.newlines)
            .union(.controlCharacters)
        let cleaned = fileName
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fallback : cleaned
    }
}

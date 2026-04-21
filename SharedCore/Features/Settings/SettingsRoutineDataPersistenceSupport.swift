import Foundation
import SwiftData

enum SettingsRoutineDataPersistence {
    struct Backup: Codable {
        var schemaVersion: Int
        var exportedAt: Date
        var places: [Place]?
        var tasks: [Task]
        var logs: [Log]

        struct Place: Codable {
            var id: UUID
            var name: String
            var latitude: Double
            var longitude: Double
            var radiusMeters: Double
            var createdAt: Date?
        }

        struct Task: Codable {
            var id: UUID
            var name: String?
            var emoji: String?
            var notes: String?
            var link: String?
            var deadline: Date?
            var imageData: Data?
            var placeID: UUID?
            var tags: [String]?
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
            var autoAssumeDailyDone: Bool?
            var estimatedDurationMinutes: Int?
            var storyPoints: Int?
        }

        struct Log: Codable {
            var id: UUID
            var timestamp: Date?
            var taskID: UUID
            var kind: RoutineLogKind?
        }
    }

    struct ImportSummary {
        var places: Int
        var tasks: Int
        var logs: Int
    }

    enum Error: LocalizedError {
        case unsupportedSchema(Int)

        var errorDescription: String? {
            switch self {
            case let .unsupportedSchema(version):
                return "Unsupported backup format version: \(version)."
            }
        }
    }

    static func defaultBackupFileName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "routina-backup-\(formatter.string(from: now)).json"
    }

    @MainActor
    static func buildBackupJSON(
        from context: ModelContext,
        exportedAt: Date = Date()
    ) throws -> Data {
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        let backup = Backup(
            schemaVersion: 12,
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
            tasks: tasks.map {
                .init(
                    id: $0.id,
                    name: $0.name,
                    emoji: $0.emoji,
                    notes: $0.notes,
                    link: $0.link,
                    deadline: $0.deadline,
                    imageData: $0.imageData,
                    placeID: $0.placeID,
                    tags: $0.tags,
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
                    autoAssumeDailyDone: $0.autoAssumeDailyDone,
                    estimatedDurationMinutes: $0.estimatedDurationMinutes,
                    storyPoints: $0.storyPoints
                )
            },
            logs: logs.map {
                .init(
                    id: $0.id,
                    timestamp: $0.timestamp,
                    taskID: $0.taskID,
                    kind: $0.kind
                )
            }
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

        guard (1...12).contains(backup.schemaVersion) else {
            throw Error.unsupportedSchema(backup.schemaVersion)
        }

        do {
            let existingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
            for log in existingLogs {
                context.delete(log)
            }

            let existingTasks = try context.fetch(FetchDescriptor<RoutineTask>())
            for task in existingTasks {
                context.delete(task)
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

            var importedTaskIDs = Set<UUID>()
            var importedTaskCount = 0
            for task in backup.tasks {
                guard importedTaskIDs.insert(task.id).inserted else { continue }

                let clampedInterval = min(max(task.interval, 1), Int(Int16.max))
                let importedTask = RoutineTask(
                    id: task.id,
                    name: task.name,
                    emoji: task.emoji,
                    notes: task.notes,
                    link: task.link,
                    deadline: task.deadline,
                    imageData: task.imageData,
                    placeID: task.placeID.flatMap { importedPlaceIDs.contains($0) ? $0 : nil },
                    tags: task.tags ?? [],
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
                    autoAssumeDailyDone: task.autoAssumeDailyDone ?? false,
                    estimatedDurationMinutes: task.estimatedDurationMinutes,
                    storyPoints: task.storyPoints
                )
                context.insert(importedTask)
                importedTaskCount += 1
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
                    kind: log.kind ?? .completed
                )
                context.insert(importedLog)
                importedLogCount += 1
            }

            try context.save()
            return ImportSummary(
                places: importedPlaceCount,
                tasks: importedTaskCount,
                logs: importedLogCount
            )
        } catch {
            context.rollback()
            throw error
        }
    }
}

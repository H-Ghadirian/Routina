import Foundation
import SwiftData

struct CloudUsageEstimate: Equatable, Sendable {
    var taskCount: Int
    var logCount: Int
    var placeCount: Int
    var imageCount: Int
    var taskPayloadBytes: Int64
    var logPayloadBytes: Int64
    var placePayloadBytes: Int64
    var imagePayloadBytes: Int64

    static let zero = CloudUsageEstimate(
        taskCount: 0,
        logCount: 0,
        placeCount: 0,
        imageCount: 0,
        taskPayloadBytes: 0,
        logPayloadBytes: 0,
        placePayloadBytes: 0,
        imagePayloadBytes: 0
    )

    var totalPayloadBytes: Int64 {
        taskPayloadBytes + logPayloadBytes + placePayloadBytes + imagePayloadBytes
    }

    var totalRecordCount: Int {
        taskCount + logCount + placeCount
    }

    @MainActor
    static func estimate(in context: ModelContext) throws -> CloudUsageEstimate {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let encoder = JSONEncoder()

        let taskPayloadBytes = tasks.reduce(into: Int64.zero) { total, task in
            total += encodedByteCount(TaskPayload(task: task), encoder: encoder)
        }
        let logPayloadBytes = logs.reduce(into: Int64.zero) { total, log in
            total += encodedByteCount(LogPayload(log: log), encoder: encoder)
        }
        let placePayloadBytes = places.reduce(into: Int64.zero) { total, place in
            total += encodedByteCount(PlacePayload(place: place), encoder: encoder)
        }
        let imagePayloadBytes = tasks.reduce(into: Int64.zero) { total, task in
            total += Int64(task.imageData?.count ?? 0)
        }

        return CloudUsageEstimate(
            taskCount: tasks.count,
            logCount: logs.count,
            placeCount: places.count,
            imageCount: tasks.reduce(into: 0) { count, task in
                if task.imageData?.isEmpty == false {
                    count += 1
                }
            },
            taskPayloadBytes: taskPayloadBytes,
            logPayloadBytes: logPayloadBytes,
            placePayloadBytes: placePayloadBytes,
            imagePayloadBytes: imagePayloadBytes
        )
    }

    private static func encodedByteCount<T: Encodable>(_ value: T, encoder: JSONEncoder) -> Int64 {
        Int64((try? encoder.encode(value).count) ?? 0)
    }

    private struct TaskPayload: Encodable {
        var id: UUID
        var name: String?
        var emoji: String?
        var notes: String?
        var link: String?
        var deadline: Date?
        var priorityRawValue: String
        var importanceRawValue: String
        var urgencyRawValue: String
        var hasImage: Bool
        var placeID: UUID?
        var tagsStorage: String
        var stepsStorage: String
        var checklistItemsStorage: String
        var completedChecklistItemIDsStorage: String
        var relationshipsStorage: String
        var scheduleModeRawValue: String
        var recurrenceRuleStorage: String
        var interval: Int16
        var lastDone: Date?
        var canceledAt: Date?
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var pinnedAt: Date?
        var completedStepCount: Int16
        var sequenceStartedAt: Date?
        var estimatedDurationMinutes: Int?
        var storyPoints: Int?

        init(task: RoutineTask) {
            id = task.id
            name = task.name
            emoji = task.emoji
            notes = task.notes
            link = task.link
            deadline = task.deadline
            priorityRawValue = task.priorityRawValue
            importanceRawValue = task.importanceRawValue
            urgencyRawValue = task.urgencyRawValue
            hasImage = task.hasImage
            placeID = task.placeID
            tagsStorage = task.tagsStorage
            stepsStorage = task.stepsStorage
            checklistItemsStorage = task.checklistItemsStorage
            completedChecklistItemIDsStorage = task.completedChecklistItemIDsStorage
            relationshipsStorage = task.relationshipsStorage
            scheduleModeRawValue = task.scheduleModeRawValue
            recurrenceRuleStorage = task.recurrenceRuleStorage
            interval = task.interval
            lastDone = task.lastDone
            canceledAt = task.canceledAt
            scheduleAnchor = task.scheduleAnchor
            pausedAt = task.pausedAt
            pinnedAt = task.pinnedAt
            completedStepCount = task.completedStepCount
            sequenceStartedAt = task.sequenceStartedAt
            estimatedDurationMinutes = task.estimatedDurationMinutes
            storyPoints = task.storyPoints
        }
    }

    private struct LogPayload: Encodable {
        var id: UUID
        var timestamp: Date?
        var taskID: UUID

        init(log: RoutineLog) {
            id = log.id
            timestamp = log.timestamp
            taskID = log.taskID
        }
    }

    private struct PlacePayload: Encodable {
        var id: UUID
        var name: String
        var latitude: Double
        var longitude: Double
        var radiusMeters: Double
        var createdAt: Date

        init(place: RoutinePlace) {
            id = place.id
            name = place.name
            latitude = place.latitude
            longitude = place.longitude
            radiusMeters = place.radiusMeters
            createdAt = place.createdAt
        }
    }
}

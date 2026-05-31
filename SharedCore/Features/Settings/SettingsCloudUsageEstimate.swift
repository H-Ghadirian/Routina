import Foundation
import SwiftData

struct CloudUsageEstimate: Equatable, Sendable {
    var taskCount: Int
    var logCount: Int
    var placeCount: Int
    var goalCount: Int
    var emotionLogCount: Int
    var noteCount: Int
    var eventCount: Int
    var imageCount: Int
    var voiceNoteCount: Int
    var taskPayloadBytes: Int64
    var logPayloadBytes: Int64
    var placePayloadBytes: Int64
    var goalPayloadBytes: Int64
    var emotionLogPayloadBytes: Int64
    var notePayloadBytes: Int64
    var eventPayloadBytes: Int64
    var imagePayloadBytes: Int64
    var voiceNotePayloadBytes: Int64

    static let zero = CloudUsageEstimate(
        taskCount: 0,
        logCount: 0,
        placeCount: 0,
        goalCount: 0,
        emotionLogCount: 0,
        noteCount: 0,
        eventCount: 0,
        imageCount: 0,
        voiceNoteCount: 0,
        taskPayloadBytes: 0,
        logPayloadBytes: 0,
        placePayloadBytes: 0,
        goalPayloadBytes: 0,
        emotionLogPayloadBytes: 0,
        notePayloadBytes: 0,
        eventPayloadBytes: 0,
        imagePayloadBytes: 0,
        voiceNotePayloadBytes: 0
    )

    var totalPayloadBytes: Int64 {
        taskPayloadBytes + logPayloadBytes + placePayloadBytes + goalPayloadBytes + emotionLogPayloadBytes + notePayloadBytes + eventPayloadBytes + imagePayloadBytes + voiceNotePayloadBytes
    }

    var totalRecordCount: Int {
        taskCount + logCount + placeCount + goalCount + emotionLogCount + noteCount + eventCount
    }

    @MainActor
    static func estimate(in context: ModelContext) throws -> CloudUsageEstimate {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let emotionLogs = try context.fetch(FetchDescriptor<EmotionLog>())
        let notes = try context.fetch(FetchDescriptor<RoutineNote>())
        let events = try context.fetch(FetchDescriptor<RoutineEvent>())
        let placeCheckInSessions = try context.fetch(FetchDescriptor<PlaceCheckInSession>())
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
        let goalPayloadBytes = goals.reduce(into: Int64.zero) { total, goal in
            total += encodedByteCount(GoalPayload(goal: goal), encoder: encoder)
        }
        let emotionLogPayloadBytes = emotionLogs.reduce(into: Int64.zero) { total, emotion in
            total += encodedByteCount(EmotionPayload(emotion: emotion), encoder: encoder)
        }
        let notePayloadBytes = notes.reduce(into: Int64.zero) { total, note in
            total += encodedByteCount(NotePayload(note: note), encoder: encoder)
        }
        let eventPayloadBytes = events.reduce(into: Int64.zero) { total, event in
            total += encodedByteCount(EventPayload(event: event), encoder: encoder)
        }
        var imagePayloadBytes = tasks.reduce(into: Int64.zero) { total, task in
            total += Int64(task.imageData?.count ?? 0)
        }
        imagePayloadBytes += placeCheckInSessions.reduce(into: Int64.zero) { total, session in
            total += Int64(session.imageData?.count ?? 0)
        }
        imagePayloadBytes += notes.reduce(into: Int64.zero) { total, note in
            total += Int64(note.imageData?.count ?? 0)
        }
        var voiceNotePayloadBytes = tasks.reduce(into: Int64.zero) { total, task in
            total += Int64(task.voiceNoteData?.count ?? 0)
        }
        voiceNotePayloadBytes += notes.reduce(into: Int64.zero) { total, note in
            total += Int64(note.voiceNoteData?.count ?? 0)
        }

        return CloudUsageEstimate(
            taskCount: tasks.count,
            logCount: logs.count,
            placeCount: places.count,
            goalCount: goals.count,
            emotionLogCount: emotionLogs.count,
            noteCount: notes.count,
            eventCount: events.count,
            imageCount: tasks.reduce(into: 0) { count, task in
                if task.imageData?.isEmpty == false {
                    count += 1
                }
            } + placeCheckInSessions.reduce(into: 0) { count, session in
                if session.imageData?.isEmpty == false {
                    count += 1
                }
            } + notes.reduce(into: 0) { count, note in
                if note.imageData?.isEmpty == false {
                    count += 1
                }
            },
            voiceNoteCount: tasks.reduce(into: 0) { count, task in
                if task.voiceNoteData?.isEmpty == false {
                    count += 1
                }
            } + notes.reduce(into: 0) { count, note in
                if note.voiceNoteData?.isEmpty == false {
                    count += 1
                }
            },
            taskPayloadBytes: taskPayloadBytes,
            logPayloadBytes: logPayloadBytes,
            placePayloadBytes: placePayloadBytes,
            goalPayloadBytes: goalPayloadBytes,
            emotionLogPayloadBytes: emotionLogPayloadBytes,
            notePayloadBytes: notePayloadBytes,
            eventPayloadBytes: eventPayloadBytes,
            imagePayloadBytes: imagePayloadBytes,
            voiceNotePayloadBytes: voiceNotePayloadBytes
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
        var linksStorage: String
        var deadline: Date?
        var isAllDay: Bool
        var reminderAt: Date?
        var priorityRawValue: String
        var importanceRawValue: String
        var urgencyRawValue: String
        var hasImage: Bool
        var hasVoiceNote: Bool
        var placeID: UUID?
        var tagsStorage: String
        var goalIDsStorage: String
        var stepsStorage: String
        var checklistItemsStorage: String
        var completedChecklistItemIDsStorage: String
        var relationshipsStorage: String
        var scheduleModeRawValue: String
        var recurrenceStorageVersion: Int16
        var recurrenceKindRawValue: String
        var recurrenceTimeOfDayHour: Int?
        var recurrenceTimeOfDayMinute: Int?
        var recurrenceTimeRangeStartHour: Int?
        var recurrenceTimeRangeStartMinute: Int?
        var recurrenceTimeRangeEndHour: Int?
        var recurrenceTimeRangeEndMinute: Int?
        var recurrenceWeekday: Int?
        var recurrenceDayOfMonth: Int?
        var interval: Int16
        var lastDone: Date?
        var canceledAt: Date?
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var pinnedAt: Date?
        var completedStepCount: Int16
        var sequenceStartedAt: Date?
        var estimatedDurationMinutes: Int?
        var actualDurationMinutes: Int?
        var storyPoints: Int?

        init(task: RoutineTask) {
            id = task.id
            name = task.name
            emoji = task.emoji
            notes = task.notes
            link = task.link
            linksStorage = task.linksStorage
            deadline = task.deadline
            isAllDay = task.isAllDay
            reminderAt = task.reminderAt
            priorityRawValue = task.priorityRawValue
            importanceRawValue = task.importanceRawValue
            urgencyRawValue = task.urgencyRawValue
            hasImage = task.hasImage
            hasVoiceNote = task.hasVoiceNote
            placeID = task.placeID
            tagsStorage = task.tagsStorage
            goalIDsStorage = task.goalIDsStorage
            stepsStorage = task.stepsStorage
            checklistItemsStorage = task.checklistItemsStorage
            completedChecklistItemIDsStorage = task.completedChecklistItemIDsStorage
            relationshipsStorage = task.relationshipsStorage
            scheduleModeRawValue = task.scheduleModeRawValue
            recurrenceStorageVersion = task.recurrenceStorageVersion
            recurrenceKindRawValue = task.recurrenceKindRawValue
            recurrenceTimeOfDayHour = task.recurrenceTimeOfDayHour
            recurrenceTimeOfDayMinute = task.recurrenceTimeOfDayMinute
            recurrenceTimeRangeStartHour = task.recurrenceTimeRangeStartHour
            recurrenceTimeRangeStartMinute = task.recurrenceTimeRangeStartMinute
            recurrenceTimeRangeEndHour = task.recurrenceTimeRangeEndHour
            recurrenceTimeRangeEndMinute = task.recurrenceTimeRangeEndMinute
            recurrenceWeekday = task.recurrenceWeekday
            recurrenceDayOfMonth = task.recurrenceDayOfMonth
            interval = task.interval
            lastDone = task.lastDone
            canceledAt = task.canceledAt
            scheduleAnchor = task.scheduleAnchor
            pausedAt = task.pausedAt
            pinnedAt = task.pinnedAt
            completedStepCount = task.completedStepCount
            sequenceStartedAt = task.sequenceStartedAt
            estimatedDurationMinutes = task.estimatedDurationMinutes
            actualDurationMinutes = task.actualDurationMinutes
            storyPoints = task.storyPoints
        }
    }

    private struct LogPayload: Encodable {
        var id: UUID
        var timestamp: Date?
        var taskID: UUID
        var actualDurationMinutes: Int?

        init(log: RoutineLog) {
            id = log.id
            timestamp = log.timestamp
            taskID = log.taskID
            actualDurationMinutes = log.actualDurationMinutes
        }
    }

    private struct NotePayload: Encodable {
        var id: UUID
        var title: String?
        var body: String?
        var tagsStorage: String
        var hasImage: Bool
        var hasVoiceNote: Bool
        var createdAt: Date?
        var updatedAt: Date?

        init(note: RoutineNote) {
            id = note.id
            title = note.title
            body = note.body
            tagsStorage = note.tagsStorage
            hasImage = note.hasImage
            hasVoiceNote = note.hasVoiceNote
            createdAt = note.createdAt
            updatedAt = note.updatedAt
        }
    }

    private struct EventPayload: Encodable {
        var id: UUID
        var title: String?
        var notes: String?
        var emoji: String?
        var tagsStorage: String
        var isAllDay: Bool
        var startedAt: Date?
        var endedAt: Date?
        var createdAt: Date?
        var updatedAt: Date?

        init(event: RoutineEvent) {
            id = event.id
            title = event.title
            notes = event.notes
            emoji = event.emoji
            tagsStorage = event.tagsStorage
            isAllDay = event.isAllDay
            startedAt = event.startedAt
            endedAt = event.endedAt
            createdAt = event.createdAt
            updatedAt = event.updatedAt
        }
    }

    private struct EmotionPayload: Encodable {
        var id: UUID
        var familyRawValue: String
        var familyRawValuesStorage: String
        var label: String
        var labelsStorage: String
        var valence: Double
        var arousal: Double
        var intensity: Int
        var bodyAreasStorage: String
        var reflection: String?
        var linkedNoteID: UUID?
        var linkedGoalID: UUID?
        var linkedTaskID: UUID?
        var linkedPlaceID: UUID?
        var linkedSleepSessionID: UUID?
        var createdAt: Date?
        var updatedAt: Date?

        init(emotion: EmotionLog) {
            id = emotion.id
            familyRawValue = emotion.familyRawValue
            familyRawValuesStorage = emotion.familyRawValuesStorage
            label = emotion.label
            labelsStorage = emotion.labelsStorage
            valence = emotion.valence
            arousal = emotion.arousal
            intensity = emotion.intensity
            bodyAreasStorage = emotion.bodyAreasStorage
            reflection = emotion.reflection
            linkedNoteID = emotion.linkedNoteID
            linkedGoalID = emotion.linkedGoalID
            linkedTaskID = emotion.linkedTaskID
            linkedPlaceID = emotion.linkedPlaceID
            linkedSleepSessionID = emotion.linkedSleepSessionID
            createdAt = emotion.createdAt
            updatedAt = emotion.updatedAt
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

    private struct GoalPayload: Encodable {
        var id: UUID
        var title: String
        var emoji: String?
        var notes: String?
        var targetDate: Date?
        var tagsStorage: String
        var statusRawValue: String
        var colorRawValue: String
        var parentGoalID: UUID?
        var createdAt: Date?
        var sortOrder: Int

        init(goal: RoutineGoal) {
            id = goal.id
            title = goal.title
            emoji = goal.emoji
            notes = goal.notes
            targetDate = goal.targetDate
            tagsStorage = goal.tagsStorage
            statusRawValue = goal.statusRawValue
            colorRawValue = goal.colorRawValue
            parentGoalID = goal.parentGoalID
            createdAt = goal.createdAt
            sortOrder = goal.sortOrder
        }
    }
}

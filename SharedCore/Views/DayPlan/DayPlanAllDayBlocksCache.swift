import SwiftUI

@MainActor
final class DayPlanAllDayBlocksCache: ObservableObject {
    private var cachedReuseSignature: DayPlanAllDayBlocksReuseSignature?
    private var cachedFastSignature: DayPlanAllDayBlocksFastSignature?
    private var cachedKey: DayPlanAllDayBlocksCacheKey?
    private var cachedBlocks: [DayPlanAllDayBlock] = []
    private var requiresFullValidation = false

    func blocks(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        events: [RoutineEvent],
        calendar: Calendar
    ) -> [DayPlanAllDayBlock] {
        let reuseSignature = DayPlanAllDayBlocksReuseSignature(
            dates: dates,
            tasks: tasks,
            logs: logs,
            events: events,
            calendar: calendar
        )

        if !requiresFullValidation, cachedReuseSignature == reuseSignature, cachedKey != nil {
            return cachedBlocks
        }

        let fastSignature = DayPlanAllDayBlocksFastSignature(
            dates: dates,
            tasks: tasks,
            logs: logs,
            events: events,
            calendar: calendar
        )

        if !requiresFullValidation, cachedFastSignature == fastSignature, cachedKey != nil {
            cachedReuseSignature = reuseSignature
            return cachedBlocks
        }

        let key = DayPlanAllDayBlocksCacheKey(
            dates: dates,
            tasks: tasks,
            logs: logs,
            events: events,
            calendar: calendar
        )

        if cachedKey == key {
            cachedReuseSignature = reuseSignature
            cachedFastSignature = fastSignature
            requiresFullValidation = false
            return cachedBlocks
        }

        let blocks = DayPlanAllDayTasks.blocks(
            on: dates,
            from: tasks,
            logs: logs,
            events: events,
            calendar: calendar
        )
        cachedReuseSignature = reuseSignature
        cachedFastSignature = fastSignature
        cachedKey = key
        cachedBlocks = blocks
        requiresFullValidation = false
        return blocks
    }

    func requireFullValidation() {
        requiresFullValidation = true
    }

    func invalidate() {
        cachedReuseSignature = nil
        cachedFastSignature = nil
        cachedKey = nil
        cachedBlocks = []
        requiresFullValidation = false
    }
}

private struct DayPlanAllDayBlocksReuseSignature: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var visibleDayKeys: [String]
    var taskObjects: [ObjectIdentifier]
    var logObjects: [ObjectIdentifier]
    var eventObjects: [ObjectIdentifier]

    init(
        dates: [Date],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        events: [RoutineEvent],
        calendar: Calendar
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        visibleDayKeys =
            dates
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
            .sorted()
        taskObjects = tasks.map { ObjectIdentifier($0) }
        logObjects = logs.map { ObjectIdentifier($0) }
        eventObjects = events.map { ObjectIdentifier($0) }
    }
}

private struct DayPlanAllDayBlocksFastSignature: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var visibleDayKeys: [String]
    var taskIDs: Set<UUID>
    var logIDs: Set<UUID>
    var eventIDs: Set<UUID>

    init(
        dates: [Date],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        events: [RoutineEvent],
        calendar: Calendar
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        visibleDayKeys =
            dates
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
            .sorted()
        taskIDs = Set(tasks.map(\.id))
        logIDs = Set(logs.map(\.id))
        eventIDs = Set(events.map(\.id))
    }
}

private struct DayPlanAllDayBlocksCacheKey: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var visibleDayKeys: [String]
    var tasks: [TaskSnapshot]
    var logs: [LogSnapshot]
    var events: [EventSnapshot]

    init(
        dates: [Date],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        events: [RoutineEvent],
        calendar: Calendar
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        visibleDayKeys =
            dates
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
            .sorted()
        self.tasks =
            tasks
            .map { TaskSnapshot(task: $0) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        self.logs =
            logs
            .map { LogSnapshot(log: $0) }
            .sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        self.events =
            events
            .map { EventSnapshot(event: $0) }
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    struct TaskSnapshot: Equatable {
        var id: UUID
        var name: String?
        var emoji: String?
        var notes: String?
        var deadline: Date?
        var isAllDay: Bool
        var routineDurationModeRawValue: String
        var availabilityStartDate: Date?
        var availabilityEndDate: Date?
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
        var recurrenceRuleStorage: String
        var interval: Int16
        var lastDone: Date?
        var canceledAt: Date?
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var pauseUntil: Date?
        var snoozedUntil: Date?
        var createdAt: Date?

        init(task: RoutineTask) {
            id = task.id
            name = task.name
            emoji = task.emoji
            notes = task.notes
            deadline = task.deadline
            isAllDay = task.isAllDay
            routineDurationModeRawValue = task.routineDurationModeRawValue
            availabilityStartDate = task.availabilityStartDate
            availabilityEndDate = task.availabilityEndDate
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
            recurrenceRuleStorage = task.recurrenceRuleStorage
            interval = task.interval
            lastDone = task.lastDone
            canceledAt = task.canceledAt
            scheduleAnchor = task.scheduleAnchor
            pausedAt = task.pausedAt
            pauseUntil = task.pauseUntil
            snoozedUntil = task.snoozedUntil
            createdAt = task.createdAt
        }
    }

    struct LogSnapshot: Equatable {
        var id: UUID
        var timestamp: Date?
        var taskID: UUID
        var kindRawValue: String
        var hasSpecificWorkTime: Bool?
        var sourceTaskID: UUID?

        init(log: RoutineLog) {
            id = log.id
            timestamp = log.timestamp
            taskID = log.taskID
            kindRawValue = log.kindRawValue
            hasSpecificWorkTime = log.hasSpecificWorkTime
            sourceTaskID = log.sourceTaskID
        }
    }

    struct EventSnapshot: Equatable {
        var id: UUID
        var title: String?
        var emoji: String?
        var isAllDay: Bool
        var startedAt: Date?
        var endedAt: Date?

        init(event: RoutineEvent) {
            id = event.id
            title = event.title
            emoji = event.emoji
            isAllDay = event.isAllDay
            startedAt = event.startedAt
            endedAt = event.endedAt
        }
    }
}

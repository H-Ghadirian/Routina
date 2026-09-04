import SwiftUI

struct DayPlanPlannedBlockPresentation {
    var visibleBlocksByDayKey: [String: [DayPlanBlock]]
    var rawBlocks: [DayPlanBlock]
}

@MainActor
final class DayPlanVisibleBlockContextCache: ObservableObject {
    private var cachedReuseSignature: DayPlanVisibleBlockContextReuseSignature?
    private var cachedKey: DayPlanVisibleBlockContextCacheKey?
    private var cachedContext: DayPlanVisibleBlockContext?
    private var requiresFullValidation = false

    func context(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        calendar: Calendar,
        referenceDate: Date,
        activeFocusSessions: [FocusSession]
    ) -> DayPlanVisibleBlockContext {
        let reuseSignature = DayPlanVisibleBlockContextReuseSignature(
            tasks: tasks,
            logs: logs,
            activeFocusSessions: activeFocusSessions,
            calendar: calendar,
            referenceDate: referenceDate
        )

        if !requiresFullValidation, cachedReuseSignature == reuseSignature, let cachedContext {
            return cachedContext
        }

        let key = DayPlanVisibleBlockContextCacheKey(
            tasks: tasks,
            logs: logs,
            activeFocusSessions: activeFocusSessions,
            calendar: calendar,
            referenceDate: referenceDate
        )

        if cachedKey == key, let cachedContext {
            cachedReuseSignature = reuseSignature
            requiresFullValidation = false
            return cachedContext
        }

        let context = DayPlanVisibleBlockContext(
            tasks: tasks,
            logs: logs,
            calendar: calendar,
            referenceDate: referenceDate,
            activeFocusSessions: activeFocusSessions
        )
        cachedReuseSignature = reuseSignature
        cachedKey = key
        cachedContext = context
        requiresFullValidation = false
        return context
    }

    func requireFullValidation() {
        requiresFullValidation = true
    }

    func invalidate() {
        cachedReuseSignature = nil
        cachedKey = nil
        cachedContext = nil
        requiresFullValidation = false
    }
}

private struct DayPlanVisibleBlockContextReuseSignature: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var taskObjects: [ObjectIdentifier]
    var logObjects: [ObjectIdentifier]
    var activeFocusSessionObjects: [ObjectIdentifier]
    var referenceMinute: DayPlanTimelineRenderSnapshotKey.ReferenceMinute

    init(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        activeFocusSessions: [FocusSession],
        calendar: Calendar,
        referenceDate: Date
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        taskObjects = tasks.map { ObjectIdentifier($0) }
        logObjects = logs.map { ObjectIdentifier($0) }
        activeFocusSessionObjects = activeFocusSessions.map { ObjectIdentifier($0) }
        referenceMinute = DayPlanTimelineRenderSnapshotKey.ReferenceMinute(
            referenceDate: referenceDate,
            calendar: calendar
        )
    }
}

private struct DayPlanVisibleBlockContextCacheKey: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var tasks: [TaskSnapshot]
    var logs: [LogSnapshot]
    var activeFocusSessions: [FocusSessionSnapshot]
    var referenceMinute: DayPlanTimelineRenderSnapshotKey.ReferenceMinute

    init(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        activeFocusSessions: [FocusSession],
        calendar: Calendar,
        referenceDate: Date
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        referenceMinute = DayPlanTimelineRenderSnapshotKey.ReferenceMinute(
            referenceDate: referenceDate,
            calendar: calendar
        )
        self.tasks =
            tasks
            .map(TaskSnapshot.init(task:))
            .sorted { $0.idSortKey < $1.idSortKey }

        let completedKind = RoutineLogKind.completed.rawValue
        let fulfilledKind = RoutineLogKind.fulfilled.rawValue
        let canceledKind = RoutineLogKind.canceled.rawValue
        let missedKind = RoutineLogKind.missed.rawValue
        self.logs =
            logs
            .compactMap { log -> LogSnapshot? in
                guard
                    log.kindRawValue == completedKind
                        || log.kindRawValue == fulfilledKind
                        || log.kindRawValue == canceledKind
                        || log.kindRawValue == missedKind,
                    log.timestamp != nil
                else {
                    return nil
                }
                return LogSnapshot(log: log)
            }
            .sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
                }
                if lhs.taskIDSortKey != rhs.taskIDSortKey {
                    return lhs.taskIDSortKey < rhs.taskIDSortKey
                }
                if lhs.kindRawValue != rhs.kindRawValue {
                    return lhs.kindRawValue < rhs.kindRawValue
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.activeFocusSessions =
            activeFocusSessions
            .map(FocusSessionSnapshot.init(session:))
            .sorted { $0.idSortKey < $1.idSortKey }
    }

    struct TaskSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
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
        var createdAt: Date?
        var pausedAt: Date?
        var pauseUntil: Date?
        var snoozedUntil: Date?
        var autoAssumeDailyDone: Bool
        var autoAssumeDoneTimeOfDayHour: Int?
        var autoAssumeDoneTimeOfDayMinute: Int?
        var hasSequentialSteps: Bool
        var hasChecklistItems: Bool

        init(task: RoutineTask) {
            id = task.id
            idSortKey = task.id.uuidString
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
            createdAt = task.createdAt
            pausedAt = task.pausedAt
            pauseUntil = task.pauseUntil
            snoozedUntil = task.snoozedUntil
            autoAssumeDailyDone = task.autoAssumeDailyDone
            autoAssumeDoneTimeOfDayHour = task.autoAssumeDoneTimeOfDay?.hour
            autoAssumeDoneTimeOfDayMinute = task.autoAssumeDoneTimeOfDay?.minute
            hasSequentialSteps = task.hasSequentialSteps
            hasChecklistItems = task.hasChecklistItems
        }
    }

    struct LogSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var timestamp: Date?
        var taskID: UUID
        var taskIDSortKey: String
        var kindRawValue: String
        var hasSpecificWorkTime: Bool?
        var sourceTaskID: UUID?

        init(log: RoutineLog) {
            id = log.id
            idSortKey = log.id.uuidString
            timestamp = log.timestamp
            taskID = log.taskID
            taskIDSortKey = log.taskID.uuidString
            kindRawValue = log.kindRawValue
            hasSpecificWorkTime = log.hasSpecificWorkTime
            sourceTaskID = log.sourceTaskID
        }
    }

    struct FocusSessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var taskID: UUID
        var plannedDurationSeconds: TimeInterval
        var startedAt: Date?
        var completedAt: Date?
        var abandonedAt: Date?
        var pausedAt: Date?
        var tagName: String?

        init(session: FocusSession) {
            id = session.id
            idSortKey = session.id.uuidString
            taskID = session.taskID
            plannedDurationSeconds = session.plannedDurationSeconds
            startedAt = session.startedAt
            completedAt = session.completedAt
            abandonedAt = session.abandonedAt
            pausedAt = session.pausedAt
            tagName = session.tagName
        }
    }
}

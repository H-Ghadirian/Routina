import SwiftData
import SwiftUI

struct DayPlanTimelineDataSnapshot {
    var id = UUID()
    var signature = DayPlanTimelineDataSnapshotSignature()
    var tasks: [RoutineTask] = []
    var logs: [RoutineLog] = []
    var sleepSessions: [SleepSession] = []
    var awaySessions: [AwaySession] = []
    var events: [RoutineEvent] = []
    var sprintFocusSessions: [SprintFocusSessionRecord] = []
    var sprintFocusAllocations: [SprintFocusAllocationRecord] = []
    var boardSprints: [BoardSprintRecord] = []
    var focusSessions: [FocusSession] = []

    init() {}

    init(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        events: [RoutineEvent],
        sprintFocusSessions: [SprintFocusSessionRecord],
        sprintFocusAllocations: [SprintFocusAllocationRecord],
        boardSprints: [BoardSprintRecord],
        focusSessions: [FocusSession]
    ) {
        signature = DayPlanTimelineDataSnapshotSignature(
            tasks: tasks,
            logs: logs,
            sleepSessions: sleepSessions,
            awaySessions: awaySessions,
            events: events,
            sprintFocusSessions: sprintFocusSessions,
            sprintFocusAllocations: sprintFocusAllocations,
            boardSprints: boardSprints,
            focusSessions: focusSessions
        )
        self.tasks = tasks
        self.logs = logs
        self.sleepSessions = sleepSessions
        self.awaySessions = awaySessions
        self.events = events
        self.sprintFocusSessions = sprintFocusSessions
        self.sprintFocusAllocations = sprintFocusAllocations
        self.boardSprints = boardSprints
        self.focusSessions = focusSessions
    }

    static func fetch(from context: ModelContext) throws -> DayPlanTimelineDataSnapshot {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let sleepSessions = try context.fetch(
            FetchDescriptor<SleepSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )
        let awaySessions = try context.fetch(
            FetchDescriptor<AwaySession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )
        let events = try context.fetch(
            FetchDescriptor<RoutineEvent>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )
        let sprintFocusSessions = try context.fetch(
            FetchDescriptor<SprintFocusSessionRecord>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )
        let sprintFocusAllocations = try context.fetch(FetchDescriptor<SprintFocusAllocationRecord>())
        let boardSprints = try context.fetch(FetchDescriptor<BoardSprintRecord>())
        let focusSessions = try context.fetch(
            FetchDescriptor<FocusSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )

        return DayPlanTimelineDataSnapshot(
            tasks: tasks,
            logs: logs,
            sleepSessions: sleepSessions,
            awaySessions: awaySessions,
            events: events,
            sprintFocusSessions: sprintFocusSessions,
            sprintFocusAllocations: sprintFocusAllocations,
            boardSprints: boardSprints,
            focusSessions: focusSessions
        )
    }
}

struct DayPlanTimelineDataSnapshotSignature: Equatable {
    var tasks: [TaskSnapshot] = []
    var logs: [LogSnapshot] = []
    var sleepSessions: [SleepSessionSnapshot] = []
    var awaySessions: [AwaySessionSnapshot] = []
    var events: [EventSnapshot] = []
    var sprintFocusSessions: [SprintFocusSessionSnapshot] = []
    var sprintFocusAllocations: [SprintFocusAllocationSnapshot] = []
    var boardSprints: [BoardSprintSnapshot] = []
    var focusSessions: [FocusSessionSnapshot] = []

    init() {}

    init(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        events: [RoutineEvent],
        sprintFocusSessions: [SprintFocusSessionRecord],
        sprintFocusAllocations: [SprintFocusAllocationRecord],
        boardSprints: [BoardSprintRecord],
        focusSessions: [FocusSession]
    ) {
        self.tasks =
            tasks
            .map(TaskSnapshot.init(task:))
            .sorted { $0.idSortKey < $1.idSortKey }
        self.logs =
            logs
            .map(LogSnapshot.init(log:))
            .sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.sleepSessions =
            sleepSessions
            .map(SleepSessionSnapshot.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.awaySessions =
            awaySessions
            .map(AwaySessionSnapshot.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.events =
            events
            .map(EventSnapshot.init(event:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.sprintFocusSessions =
            sprintFocusSessions
            .map(SprintFocusSessionSnapshot.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return lhs.startedAt < rhs.startedAt
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.sprintFocusAllocations =
            sprintFocusAllocations
            .map(SprintFocusAllocationSnapshot.init(allocation:))
            .sorted { lhs, rhs in
                if lhs.sessionIDSortKey != rhs.sessionIDSortKey {
                    return lhs.sessionIDSortKey < rhs.sessionIDSortKey
                }
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.boardSprints =
            boardSprints
            .map(BoardSprintSnapshot.init(sprint:))
            .sorted { $0.idSortKey < $1.idSortKey }
        self.focusSessions =
            focusSessions
            .map(FocusSessionSnapshot.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
                }
                return lhs.idSortKey < rhs.idSortKey
            }
    }

    struct TaskSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
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
        var colorRawValue: String
        var autoAssumeDailyDone: Bool
        var autoAssumeDoneTimeOfDayHour: Int?
        var autoAssumeDoneTimeOfDayMinute: Int?
        var estimatedDurationMinutes: Int?
        var flagsStorage: String
        var stepsStorage: String
        var checklistItemsStorage: String
        var completedChecklistItemIDsStorage: String
        var completedChecklistProgressStartedAt: Date?

        init(task: RoutineTask) {
            id = task.id
            idSortKey = task.id.uuidString
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
            colorRawValue = task.colorRawValue
            autoAssumeDailyDone = task.autoAssumeDailyDone
            autoAssumeDoneTimeOfDayHour = task.autoAssumeDoneTimeOfDayHour
            autoAssumeDoneTimeOfDayMinute = task.autoAssumeDoneTimeOfDayMinute
            estimatedDurationMinutes = task.estimatedDurationMinutes
            flagsStorage = task.flagsStorage
            stepsStorage = task.stepsStorage
            checklistItemsStorage = task.checklistItemsStorage
            completedChecklistItemIDsStorage = task.completedChecklistItemIDsStorage
            completedChecklistProgressStartedAt = task.completedChecklistProgressStartedAt
        }
    }

    struct LogSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var timestamp: Date?
        var taskID: UUID
        var kindRawValue: String
        var actualDurationMinutes: Int?
        var hasSpecificWorkTime: Bool?
        var sourceTaskID: UUID?

        init(log: RoutineLog) {
            id = log.id
            idSortKey = log.id.uuidString
            timestamp = log.timestamp
            taskID = log.taskID
            kindRawValue = log.kindRawValue
            actualDurationMinutes = log.actualDurationMinutes
            hasSpecificWorkTime = log.hasSpecificWorkTime
            sourceTaskID = log.sourceTaskID
        }
    }

    struct SleepSessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var startedAt: Date?
        var endedAt: Date?
        var targetDurationMinutes: Int

        init(session: SleepSession) {
            id = session.id
            idSortKey = session.id.uuidString
            startedAt = session.startedAt
            endedAt = session.endedAt
            targetDurationMinutes = session.targetDurationMinutes
        }
    }

    struct AwaySessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var presetRawValue: String
        var title: String
        var linkedTaskID: UUID?
        var startedAt: Date?
        var plannedDurationSeconds: TimeInterval
        var completedAt: Date?
        var endedEarlyAt: Date?

        init(session: AwaySession) {
            id = session.id
            idSortKey = session.id.uuidString
            presetRawValue = session.presetRawValue
            title = session.title
            linkedTaskID = session.linkedTaskID
            startedAt = session.startedAt
            plannedDurationSeconds = session.plannedDurationSeconds
            completedAt = session.completedAt
            endedEarlyAt = session.endedEarlyAt
        }
    }

    struct EventSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var title: String?
        var emoji: String?
        var isAllDay: Bool
        var startedAt: Date?
        var endedAt: Date?

        init(event: RoutineEvent) {
            id = event.id
            idSortKey = event.id.uuidString
            title = event.title
            emoji = event.emoji
            isAllDay = event.isAllDay
            startedAt = event.startedAt
            endedAt = event.endedAt
        }
    }

    struct SprintFocusSessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var sprintID: UUID
        var startedAt: Date
        var stoppedAt: Date?
        var pausedAt: Date?
        var accumulatedPausedSeconds: TimeInterval

        init(session: SprintFocusSessionRecord) {
            id = session.id
            idSortKey = session.id.uuidString
            sprintID = session.sprintID
            startedAt = session.startedAt
            stoppedAt = session.stoppedAt
            pausedAt = session.pausedAt
            accumulatedPausedSeconds = session.accumulatedPausedSeconds
        }
    }

    struct SprintFocusAllocationSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var sessionID: UUID
        var sessionIDSortKey: String
        var taskID: UUID
        var minutes: Int
        var sortOrder: Int

        init(allocation: SprintFocusAllocationRecord) {
            id = allocation.id
            idSortKey = allocation.id.uuidString
            sessionID = allocation.sessionID
            sessionIDSortKey = allocation.sessionID.uuidString
            taskID = allocation.taskID
            minutes = allocation.minutes
            sortOrder = allocation.sortOrder
        }
    }

    struct BoardSprintSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var title: String

        init(sprint: BoardSprintRecord) {
            id = sprint.id
            idSortKey = sprint.id.uuidString
            title = sprint.title
        }
    }

    struct FocusSessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var taskID: UUID
        var startedAt: Date?
        var plannedDurationSeconds: TimeInterval
        var completedAt: Date?
        var abandonedAt: Date?
        var pausedAt: Date?
        var accumulatedPausedSeconds: TimeInterval
        var tagName: String?

        init(session: FocusSession) {
            id = session.id
            idSortKey = session.id.uuidString
            taskID = session.taskID
            startedAt = session.startedAt
            plannedDurationSeconds = session.plannedDurationSeconds
            completedAt = session.completedAt
            abandonedAt = session.abandonedAt
            pausedAt = session.pausedAt
            accumulatedPausedSeconds = session.accumulatedPausedSeconds
            tagName = session.tagName
        }
    }
}

import SwiftUI

@MainActor
final class DayPlanSleepBlocksCache: ObservableObject {
    private var cachedKey: DayPlanSleepBlocksCacheKey?
    private var cachedBlocksByDayKey: [String: [DayPlanSleepBlock]] = [:]

    func blocksByDayKey(
        on dates: [Date],
        from sessions: [SleepSession],
        referenceDate: Date,
        calendar: Calendar
    ) -> [String: [DayPlanSleepBlock]] {
        let key = DayPlanSleepBlocksCacheKey(
            dates: dates,
            sessions: sessions,
            referenceDate: referenceDate,
            calendar: calendar
        )

        if cachedKey == key {
            return cachedBlocksByDayKey
        }

        let blocksByDayKey = DayPlanSleepBlocks.blocksByDayKey(
            on: dates,
            from: sessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        cachedKey = key
        cachedBlocksByDayKey = blocksByDayKey
        return blocksByDayKey
    }

    func invalidate() {
        cachedKey = nil
        cachedBlocksByDayKey = [:]
    }
}

private struct DayPlanSleepBlocksCacheKey: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var visibleDayKeys: [String]
    var referenceMinute: ReferenceMinute?
    var sessions: [SessionSnapshot]

    init(
        dates: [Date],
        sessions: [SleepSession],
        referenceDate: Date,
        calendar: Calendar
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        let visibleDayStarts =
            dates
            .map { calendar.startOfDay(for: $0) }
            .sorted()
        visibleDayKeys =
            visibleDayStarts
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
        let visibleRangeStart = visibleDayStarts.first
        let visibleRangeEnd = visibleDayStarts.last.flatMap {
            calendar.date(byAdding: .day, value: 1, to: $0)
        }
        let relevantSessions: [SleepSession]
        if let visibleRangeStart, let visibleRangeEnd {
            relevantSessions = sessions.filter { session in
                guard let startedAt = session.startedAt else { return false }
                let endedAt = session.endedAt ?? referenceDate
                return startedAt < visibleRangeEnd && endedAt >= visibleRangeStart
            }
        } else {
            relevantSessions = []
        }
        referenceMinute =
            relevantSessions.contains { $0.endedAt == nil }
            ? ReferenceMinute(referenceDate: referenceDate, calendar: calendar)
            : nil
        self.sessions =
            relevantSessions
            .map(SessionSnapshot.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
                }
                return lhs.idSortKey < rhs.idSortKey
            }
    }

    struct ReferenceMinute: Equatable {
        var dayKey: String
        var minute: Int

        init(referenceDate: Date, calendar: Calendar) {
            dayKey = DayPlanStorage.dayKey(for: referenceDate, calendar: calendar)
            let components = calendar.dateComponents([.hour, .minute], from: referenceDate)
            minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        }
    }

    struct SessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var startedAt: Date?
        var endedAt: Date?

        init(session: SleepSession) {
            id = session.id
            idSortKey = session.id.uuidString
            startedAt = session.startedAt
            endedAt = session.endedAt
        }
    }
}

@MainActor
final class DayPlanAwayBlocksCache: ObservableObject {
    private var cachedKey: DayPlanAwayBlocksCacheKey?
    private var cachedBlocksByDayKey: [String: [DayPlanAwayBlock]] = [:]

    func blocksByDayKey(
        on dates: [Date],
        from sessions: [AwaySession],
        tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) -> [String: [DayPlanAwayBlock]] {
        let key = DayPlanAwayBlocksCacheKey(
            dates: dates,
            sessions: sessions,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )

        if cachedKey == key {
            return cachedBlocksByDayKey
        }

        let blocksByDayKey = DayPlanAwayBlocks.blocksByDayKey(
            on: dates,
            from: sessions,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        cachedKey = key
        cachedBlocksByDayKey = blocksByDayKey
        return blocksByDayKey
    }

    func invalidate() {
        cachedKey = nil
        cachedBlocksByDayKey = [:]
    }
}

private struct DayPlanAwayBlocksCacheKey: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var visibleDayKeys: [String]
    var referenceMinute: ReferenceMinute?
    var sessions: [SessionSnapshot]
    var tasks: [TaskSnapshot]

    init(
        dates: [Date],
        sessions: [AwaySession],
        tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        let visibleDayStarts =
            dates
            .map { calendar.startOfDay(for: $0) }
            .sorted()
        visibleDayKeys =
            visibleDayStarts
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
        let visibleRangeStart = visibleDayStarts.first
        let visibleRangeEnd = visibleDayStarts.last.flatMap {
            calendar.date(byAdding: .day, value: 1, to: $0)
        }
        let relevantSessions: [AwaySession]
        if let visibleRangeStart, let visibleRangeEnd {
            relevantSessions = sessions.filter { session in
                guard let startedAt = session.startedAt else { return false }
                let endedAt = session.finishedAt ?? session.plannedEndAt ?? referenceDate
                return startedAt < visibleRangeEnd && endedAt >= visibleRangeStart
            }
        } else {
            relevantSessions = []
        }
        referenceMinute =
            relevantSessions.contains { $0.isActive && $0.plannedEndAt == nil }
            ? ReferenceMinute(referenceDate: referenceDate, calendar: calendar)
            : nil
        self.sessions =
            relevantSessions
            .map(SessionSnapshot.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
                }
                return lhs.idSortKey < rhs.idSortKey
            }

        let linkedTaskIDs = Set(relevantSessions.compactMap(\.linkedTaskID))
        self.tasks =
            tasks
            .filter { linkedTaskIDs.contains($0.id) }
            .map(TaskSnapshot.init(task:))
            .sorted { $0.idSortKey < $1.idSortKey }
    }

    struct ReferenceMinute: Equatable {
        var dayKey: String
        var minute: Int

        init(referenceDate: Date, calendar: Calendar) {
            dayKey = DayPlanStorage.dayKey(for: referenceDate, calendar: calendar)
            let components = calendar.dateComponents([.hour, .minute], from: referenceDate)
            minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        }
    }

    struct SessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var presetRawValue: String
        var title: String
        var linkedTaskID: UUID?
        var linkedTaskIDSortKey: String?
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
            linkedTaskIDSortKey = session.linkedTaskID?.uuidString
            startedAt = session.startedAt
            plannedDurationSeconds = session.plannedDurationSeconds
            completedAt = session.completedAt
            endedEarlyAt = session.endedEarlyAt
        }
    }

    struct TaskSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var name: String?
        var emoji: String?

        init(task: RoutineTask) {
            id = task.id
            idSortKey = task.id.uuidString
            name = task.name
            emoji = task.emoji
        }
    }
}
@MainActor
final class DayPlanSprintFocusBlocksCache: ObservableObject {
    private var cachedKey: DayPlanSprintFocusBlocksCacheKey?
    private var cachedBlocksByDayKey: [String: [DayPlanSprintFocusBlock]] = [:]

    func blocksByDayKey(
        on dates: [Date],
        from sessions: [SprintFocusSessionRecord],
        allocations: [SprintFocusAllocationRecord],
        sprints: [BoardSprintRecord],
        tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) -> [String: [DayPlanSprintFocusBlock]] {
        let key = DayPlanSprintFocusBlocksCacheKey(
            dates: dates,
            sessions: sessions,
            allocations: allocations,
            sprints: sprints,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )

        if cachedKey == key {
            return cachedBlocksByDayKey
        }

        let blocksByDayKey = DayPlanSprintFocusBlocks.blocksByDayKey(
            on: dates,
            from: sessions,
            allocations: allocations,
            sprints: sprints,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        cachedKey = key
        cachedBlocksByDayKey = blocksByDayKey
        return blocksByDayKey
    }

    func invalidate() {
        cachedKey = nil
        cachedBlocksByDayKey = [:]
    }
}

private struct DayPlanSprintFocusBlocksCacheKey: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var visibleDayKeys: [String]
    var referenceMinute: ReferenceMinute?
    var sessions: [SessionSnapshot]
    var allocations: [AllocationSnapshot]
    var sprints: [SprintSnapshot]
    var tasks: [TaskSnapshot]

    init(
        dates: [Date],
        sessions: [SprintFocusSessionRecord],
        allocations: [SprintFocusAllocationRecord],
        sprints: [BoardSprintRecord],
        tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        let visibleDayStarts =
            dates
            .map { calendar.startOfDay(for: $0) }
            .sorted()
        visibleDayKeys =
            visibleDayStarts
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
        let visibleRangeStart = visibleDayStarts.first
        let visibleRangeEnd = visibleDayStarts.last.flatMap {
            calendar.date(byAdding: .day, value: 1, to: $0)
        }
        let relevantSessions: [SprintFocusSessionRecord]
        if let visibleRangeStart, let visibleRangeEnd {
            relevantSessions = sessions.filter { session in
                let sessionEnd = max(session.stoppedAt ?? referenceDate, session.startedAt)
                return session.startedAt < visibleRangeEnd && sessionEnd >= visibleRangeStart
            }
        } else {
            relevantSessions = []
        }
        let relevantSessionIDs = Set(relevantSessions.map(\.id))
        let relevantSprintIDs = Set(relevantSessions.map(\.sprintID))
        let relevantAllocations = allocations.filter {
            relevantSessionIDs.contains($0.sessionID) && $0.minutes > 0
        }
        let allocatedTaskIDs = Set(relevantAllocations.map(\.taskID))

        referenceMinute =
            relevantSessions.contains(where: \.isActive)
            ? ReferenceMinute(referenceDate: referenceDate, calendar: calendar)
            : nil
        self.sessions =
            relevantSessions
            .map(SessionSnapshot.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return lhs.startedAt < rhs.startedAt
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.allocations =
            relevantAllocations
            .map(AllocationSnapshot.init(allocation:))
            .sorted { lhs, rhs in
                if lhs.sessionID != rhs.sessionID {
                    return lhs.sessionIDSortKey < rhs.sessionIDSortKey
                }
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.sprints =
            sprints
            .filter { relevantSprintIDs.contains($0.id) }
            .map(SprintSnapshot.init(sprint:))
            .sorted { $0.idSortKey < $1.idSortKey }
        self.tasks =
            tasks
            .filter { allocatedTaskIDs.contains($0.id) }
            .map(TaskSnapshot.init(task:))
            .sorted { $0.idSortKey < $1.idSortKey }
    }

    struct ReferenceMinute: Equatable {
        var dayKey: String
        var minute: Int

        init(referenceDate: Date, calendar: Calendar) {
            dayKey = DayPlanStorage.dayKey(for: referenceDate, calendar: calendar)
            let components = calendar.dateComponents([.hour, .minute], from: referenceDate)
            minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        }
    }

    struct SessionSnapshot: Equatable {
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

    struct AllocationSnapshot: Equatable {
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

    struct SprintSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var title: String

        init(sprint: BoardSprintRecord) {
            id = sprint.id
            idSortKey = sprint.id.uuidString
            title = sprint.title
        }
    }

    struct TaskSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var name: String?
        var emoji: String?

        init(task: RoutineTask) {
            id = task.id
            idSortKey = task.id.uuidString
            name = task.name
            emoji = task.emoji
        }
    }
}

import Foundation
import SwiftData

enum DayPlanTaskSorting {
    static func availableTasks(from tasks: [RoutineTask]) -> [RoutineTask] {
        tasks
            .filter { !$0.isCompletedOneOff && !$0.isCanceledOneOff }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned
                }

                if lhs.isOneOffTask != rhs.isOneOffTask {
                    return lhs.isOneOffTask
                }

                let lhsDeadline = lhs.deadline ?? .distantFuture
                let rhsDeadline = rhs.deadline ?? .distantFuture
                if lhsDeadline != rhsDeadline {
                    return lhsDeadline < rhsDeadline
                }

                return title(for: lhs).localizedCaseInsensitiveCompare(title(for: rhs)) == .orderedAscending
            }
    }

    static func filteredTasks(from tasks: [RoutineTask], query: String) -> [RoutineTask] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tasks }

        let normalizedQuery = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return tasks.filter { task in
            let searchableText = ([title(for: task), task.emoji ?? ""] + task.tags)
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return searchableText.contains(normalizedQuery)
        }
    }

    static func title(for task: RoutineTask) -> String {
        let trimmed = RoutineTask.trimmedName(task.name) ?? ""
        return trimmed.isEmpty ? "Untitled task" : trimmed
    }
}

struct DayPlanTimelineActivityBlock: Identifiable, Equatable {
    var block: DayPlanBlock
    var kind: RoutineLogKind
    var source: DayPlanTimelineActivitySource

    var id: String {
        switch source {
        case let .log(logID):
            return "timeline-log-\(logID.uuidString)"
        case .taskLastDone:
            return "timeline-last-done-\(block.taskID.uuidString)"
        case .taskCanceledAt:
            return "timeline-canceled-\(block.taskID.uuidString)"
        }
    }
}

enum DayPlanTimelineActivitySource: Equatable {
    case log(UUID)
    case taskLastDone
    case taskCanceledAt
}

struct DayPlanFocusSessionBlock: Identifiable, Equatable {
    var sessionID: UUID
    var block: DayPlanBlock
    var durationMinutes: Int

    var id: String {
        "\(block.dayKey)-\(sessionID.uuidString)"
    }
}

enum DayPlanTimelineTasks {
    static func count(
        on date: Date,
        tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocks: [DayPlanBlock],
        calendar: Calendar
    ) -> Int {
        taskIDs(
            on: date,
            taskIDs: tasks.map(\.id),
            lastDoneForTaskID: Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.lastDone) }),
            canceledAtForTaskID: Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.canceledAt) }),
            logs: logs,
            plannedBlocks: plannedBlocks,
            calendar: calendar
        )
        .count
    }

    static func tasks(
        on date: Date,
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocks: [DayPlanBlock],
        calendar: Calendar
    ) -> [RoutineTask] {
        let matchingIDs = taskIDs(
            on: date,
            taskIDs: tasks.map(\.id),
            lastDoneForTaskID: Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.lastDone) }),
            canceledAtForTaskID: Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.canceledAt) }),
            logs: logs,
            plannedBlocks: plannedBlocks,
            calendar: calendar
        )

        return tasks
            .filter { matchingIDs.contains($0.id) }
            .sorted { lhs, rhs in
                let lhsDate = latestActivityDate(
                    for: lhs.id,
                    fallbackLastDone: lhs.lastDone,
                    fallbackCanceledAt: lhs.canceledAt,
                    logs: logs,
                    on: date,
                    calendar: calendar
                ) ?? .distantPast
                let rhsDate = latestActivityDate(
                    for: rhs.id,
                    fallbackLastDone: rhs.lastDone,
                    fallbackCanceledAt: rhs.canceledAt,
                    logs: logs,
                    on: date,
                    calendar: calendar
                ) ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return DayPlanTaskSorting.title(for: lhs).localizedCaseInsensitiveCompare(DayPlanTaskSorting.title(for: rhs)) == .orderedAscending
            }
    }

    static func activityBlocks(
        on date: Date,
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocks: [DayPlanBlock],
        calendar: Calendar
    ) -> [DayPlanTimelineActivityBlock] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        return activityBlocksByDayKey(
            on: [date],
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: [dayKey: plannedBlocks],
            calendar: calendar
        )[dayKey] ?? []
    }

    static func activityBlocksByDayKey(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        calendar: Calendar
    ) -> [String: [DayPlanTimelineActivityBlock]] {
        let visibleDayKeys = Set(dates.map { DayPlanStorage.dayKey(for: $0, calendar: calendar) })
        guard !visibleDayKeys.isEmpty else { return [:] }

        let tasksByID = Dictionary(grouping: tasks, by: \.id).compactMapValues(\.first)
        let knownTaskIDs = Set(tasksByID.keys)
        let plannedTaskIDsByDayKey = plannedBlocksByDayKey.mapValues { Set($0.map(\.taskID)) }
        var latestActivityByKey: [DayPlanTimelineActivityKey: DayPlanTimelineActivity] = [:]

        func record(_ activity: DayPlanTimelineActivity, taskID: UUID) {
            guard knownTaskIDs.contains(taskID) else { return }
            let dayKey = DayPlanStorage.dayKey(for: activity.timestamp, calendar: calendar)
            guard visibleDayKeys.contains(dayKey) else { return }
            guard plannedTaskIDsByDayKey[dayKey]?.contains(taskID) != true else { return }

            let key = DayPlanTimelineActivityKey(dayKey: dayKey, taskID: taskID)
            if let existing = latestActivityByKey[key], existing.timestamp >= activity.timestamp {
                return
            }
            latestActivityByKey[key] = activity
        }

        for log in logs {
            guard let timestamp = log.timestamp else { continue }
            record(
                DayPlanTimelineActivity(
                    timestamp: timestamp,
                    kind: log.kind,
                    actualDurationMinutes: log.actualDurationMinutes,
                    source: .log(log.id)
                ),
                taskID: log.taskID
            )
        }

        for task in tasks {
            if let lastDone = task.lastDone {
                record(
                    DayPlanTimelineActivity(
                        timestamp: lastDone,
                        kind: .completed,
                        actualDurationMinutes: nil,
                        source: .taskLastDone
                    ),
                    taskID: task.id
                )
            }

            if let canceledAt = task.canceledAt {
                record(
                    DayPlanTimelineActivity(
                        timestamp: canceledAt,
                        kind: .canceled,
                        actualDurationMinutes: nil,
                        source: .taskCanceledAt
                    ),
                    taskID: task.id
                )
            }
        }

        let blocks = latestActivityByKey.compactMap { key, activity -> DayPlanTimelineActivityBlock? in
            guard let task = tasksByID[key.taskID] else { return nil }
            let startMinute = startMinute(for: activity.timestamp, calendar: calendar)
            let durationMinutes = activity.actualDurationMinutes
                ?? task.estimatedDurationMinutes
                ?? DayPlanBlock.minimumDurationMinutes * 2
            let block = DayPlanBlock(
                id: task.id,
                taskID: task.id,
                dayKey: key.dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: DayPlanTaskSorting.title(for: task),
                emojiSnapshot: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
                createdAt: activity.timestamp,
                updatedAt: activity.timestamp
            )
            return DayPlanTimelineActivityBlock(
                block: block,
                kind: activity.kind,
                source: activity.source
            )
        }

        return Dictionary(grouping: blocks, by: \.block.dayKey)
            .mapValues {
                $0.sorted { lhs, rhs in
                    if lhs.block.startMinute != rhs.block.startMinute {
                        return lhs.block.startMinute < rhs.block.startMinute
                    }
                    return lhs.block.titleSnapshot.localizedCaseInsensitiveCompare(rhs.block.titleSnapshot) == .orderedAscending
                }
            }
    }

    static func taskIDs(
        on date: Date,
        taskIDs: [UUID],
        lastDoneForTaskID: [UUID: Date?],
        canceledAtForTaskID: [UUID: Date?] = [:],
        logs: [RoutineLog],
        plannedBlocks: [DayPlanBlock],
        calendar: Calendar
    ) -> Set<UUID> {
        let knownTaskIDs = Set(taskIDs)
        var activityIDs = Set<UUID>()

        for log in logs {
            guard knownTaskIDs.contains(log.taskID),
                  let timestamp = log.timestamp,
                  calendar.isDate(timestamp, inSameDayAs: date)
            else { continue }
            activityIDs.insert(log.taskID)
        }

        for (taskID, lastDone) in lastDoneForTaskID {
            guard knownTaskIDs.contains(taskID),
                  let lastDone,
                  calendar.isDate(lastDone, inSameDayAs: date)
            else { continue }
            activityIDs.insert(taskID)
        }

        for (taskID, canceledAt) in canceledAtForTaskID {
            guard knownTaskIDs.contains(taskID),
                  let canceledAt,
                  calendar.isDate(canceledAt, inSameDayAs: date)
            else { continue }
            activityIDs.insert(taskID)
        }

        activityIDs.subtract(Set(plannedBlocks.map(\.taskID)))
        return activityIDs
    }

    static func latestActivityDate(
        for taskID: UUID,
        fallbackLastDone: Date?,
        fallbackCanceledAt: Date? = nil,
        logs: [RoutineLog],
        on date: Date,
        calendar: Calendar
    ) -> Date? {
        let logDate = logs
            .filter { log in
                guard log.taskID == taskID,
                      let timestamp = log.timestamp
                else { return false }
                return calendar.isDate(timestamp, inSameDayAs: date)
            }
            .compactMap(\.timestamp)
            .max()

        let legacyDates = [fallbackLastDone, fallbackCanceledAt]
            .compactMap { candidate -> Date? in
                guard let candidate,
                      calendar.isDate(candidate, inSameDayAs: date)
                else { return nil }
                return candidate
            }

        var dates = legacyDates
        if let logDate {
            dates.append(logDate)
        }
        return dates.max()
    }

    @MainActor
    @discardableResult
    static func moveActivity(
        _ activity: DayPlanTimelineActivityBlock,
        to date: Date,
        startMinute: Int,
        tasks: [RoutineTask],
        logs: [RoutineLog],
        context: ModelContext,
        calendar: Calendar
    ) -> Bool {
        guard let task = tasks.first(where: { $0.id == activity.block.taskID }) else {
            return false
        }

        let targetTimestamp = timestamp(on: date, startMinute: startMinute, calendar: calendar)
        let sourceTimestamp = activity.block.updatedAt
        let taskLogs = logs.filter { $0.taskID == activity.block.taskID }
        let movedLog: RoutineLog?

        switch activity.source {
        case let .log(logID):
            guard let log = taskLogs.first(where: { $0.id == logID }) else {
                return false
            }
            log.timestamp = targetTimestamp
            movedLog = log

        case .taskLastDone:
            task.lastDone = targetTimestamp
            movedLog = upsertFallbackLog(
                taskID: task.id,
                kind: .completed,
                sourceTimestamp: sourceTimestamp,
                targetTimestamp: targetTimestamp,
                logs: taskLogs,
                context: context
            )

        case .taskCanceledAt:
            task.canceledAt = targetTimestamp
            movedLog = upsertFallbackLog(
                taskID: task.id,
                kind: .canceled,
                sourceTimestamp: sourceTimestamp,
                targetTimestamp: targetTimestamp,
                logs: taskLogs,
                context: context
            )
        }

        synchronizeTaskActivityDates(
            for: task,
            movedKind: activity.kind,
            sourceTimestamp: sourceTimestamp,
            targetTimestamp: targetTimestamp,
            movedLogID: movedLog?.id,
            logs: taskLogs,
            calendar: calendar
        )

        do {
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
            return true
        } catch {
            NSLog("Failed to move timeline activity in day planner: \(error.localizedDescription)")
            return false
        }
    }

    private static func latestActivity(
        for task: RoutineTask,
        logs: [RoutineLog],
        on date: Date,
        calendar: Calendar
    ) -> DayPlanTimelineActivity? {
        var activities = logs.compactMap { log -> DayPlanTimelineActivity? in
            guard log.taskID == task.id,
                  let timestamp = log.timestamp,
                  calendar.isDate(timestamp, inSameDayAs: date)
            else { return nil }

            return DayPlanTimelineActivity(
                timestamp: timestamp,
                kind: log.kind,
                actualDurationMinutes: log.actualDurationMinutes,
                source: .log(log.id)
            )
        }

        if let lastDone = task.lastDone, calendar.isDate(lastDone, inSameDayAs: date) {
            activities.append(
                DayPlanTimelineActivity(
                    timestamp: lastDone,
                    kind: .completed,
                    actualDurationMinutes: nil,
                    source: .taskLastDone
                )
            )
        }

        if let canceledAt = task.canceledAt, calendar.isDate(canceledAt, inSameDayAs: date) {
            activities.append(
                DayPlanTimelineActivity(
                    timestamp: canceledAt,
                    kind: .canceled,
                    actualDurationMinutes: nil,
                    source: .taskCanceledAt
                )
            )
        }

        return activities.max { lhs, rhs in
            lhs.timestamp < rhs.timestamp
        }
    }

    private static func startMinute(for timestamp: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: timestamp)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        return DayPlanBlock.clampedStartMinute(minute)
    }

    private static func timestamp(on date: Date, startMinute: Int, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(
            byAdding: .minute,
            value: DayPlanBlock.clampedStartMinute(startMinute),
            to: startOfDay
        ) ?? startOfDay
    }

    @MainActor
    private static func upsertFallbackLog(
        taskID: UUID,
        kind: RoutineLogKind,
        sourceTimestamp: Date,
        targetTimestamp: Date,
        logs: [RoutineLog],
        context: ModelContext
    ) -> RoutineLog {
        if let log = logs.first(where: { log in
            log.kind == kind && log.timestamp == sourceTimestamp
        }) {
            log.timestamp = targetTimestamp
            return log
        }

        let log = RoutineLog(timestamp: targetTimestamp, taskID: taskID, kind: kind)
        context.insert(log)
        return log
    }

    private static func synchronizeTaskActivityDates(
        for task: RoutineTask,
        movedKind: RoutineLogKind,
        sourceTimestamp: Date,
        targetTimestamp: Date,
        movedLogID: UUID?,
        logs: [RoutineLog],
        calendar: Calendar
    ) {
        switch movedKind {
        case .completed:
            var completionDates = logs
                .filter { $0.kind == .completed }
                .compactMap { log -> Date? in
                    if log.id == movedLogID {
                        return targetTimestamp
                    }
                    return log.timestamp
                }
            if !logs.contains(where: { $0.id == movedLogID }) {
                completionDates.append(targetTimestamp)
            }
            if let currentLastDone = task.lastDone, currentLastDone != sourceTimestamp {
                completionDates.append(currentLastDone)
            }
            let latestCompletion = completionDates
                .max()
            task.lastDone = latestCompletion
            task.canceledAt = nil
            if task.usesRollingScheduleAnchor {
                task.scheduleAnchor = latestCompletion
            } else if task.isOneOffTask {
                task.scheduleAnchor = latestCompletion
            } else if task.scheduleAnchor == sourceTimestamp {
                task.scheduleAnchor = latestCompletion
            }

        case .canceled:
            if task.canceledAt == sourceTimestamp
                || task.canceledAt.map({ calendar.isDate($0, inSameDayAs: sourceTimestamp) }) == true {
                task.canceledAt = targetTimestamp
            }

        case .missed:
            break
        }
    }
}

enum DayPlanFocusSessionBlocks {
    static func activeBlocksByDayKey(
        on dates: [Date],
        from tasks: [RoutineTask],
        sessions: [FocusSession],
        now: Date,
        calendar: Calendar
    ) -> [String: [DayPlanFocusSessionBlock]] {
        let visibleDayKeys = Set(dates.map { DayPlanStorage.dayKey(for: $0, calendar: calendar) })
        guard !visibleDayKeys.isEmpty else { return [:] }

        let blocks = activeBlocks(
            from: tasks,
            sessions: sessions,
            now: now,
            calendar: calendar
        )
        .filter { visibleDayKeys.contains($0.block.dayKey) }

        return Dictionary(grouping: blocks, by: \.block.dayKey)
            .mapValues {
                $0.sorted { lhs, rhs in
                    if lhs.block.startMinute != rhs.block.startMinute {
                        return lhs.block.startMinute < rhs.block.startMinute
                    }
                    return lhs.block.titleSnapshot.localizedCaseInsensitiveCompare(rhs.block.titleSnapshot) == .orderedAscending
                }
            }
    }

    static func activeBlocks(
        from tasks: [RoutineTask],
        sessions: [FocusSession],
        now: Date,
        calendar: Calendar
    ) -> [DayPlanFocusSessionBlock] {
        let tasksByID = Dictionary(grouping: tasks, by: \.id).compactMapValues(\.first)
        let blocks = sessions.compactMap { session -> DayPlanFocusSessionBlock? in
            guard session.completedAt == nil,
                  session.abandonedAt == nil,
                  let startedAt = session.startedAt,
                  let task = tasksByID[session.taskID]
            else { return nil }

            let dayKey = DayPlanStorage.dayKey(for: now, calendar: calendar)
            let renderStart = renderStart(for: startedAt, now: now, calendar: calendar)
            let startMinute = startMinute(for: renderStart, calendar: calendar)
            let elapsedSeconds = max(60, now.timeIntervalSince(renderStart))
            let elapsedMinutes = max(1, Int(ceil(elapsedSeconds / 60)))
            let remainingMinutes = max(1, DayPlanBlock.minutesPerDay - startMinute)
            let durationMinutes = min(elapsedMinutes, remainingMinutes)
            let block = DayPlanBlock(
                id: session.id,
                taskID: task.id,
                dayKey: dayKey,
                startMinute: startMinute,
                durationMinutes: DayPlanBlock.clampedDuration(
                    max(durationMinutes, DayPlanBlock.minimumDurationMinutes),
                    startMinute: startMinute
                ),
                titleSnapshot: DayPlanTaskSorting.title(for: task),
                emojiSnapshot: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
                createdAt: renderStart,
                updatedAt: now
            )

            return DayPlanFocusSessionBlock(
                sessionID: session.id,
                block: block,
                durationMinutes: durationMinutes
            )
        }

        return blocks.sorted { lhs, rhs in
            if lhs.block.startMinute != rhs.block.startMinute {
                return lhs.block.startMinute < rhs.block.startMinute
            }
            return lhs.block.titleSnapshot.localizedCaseInsensitiveCompare(rhs.block.titleSnapshot) == .orderedAscending
        }
    }

    private static func startMinute(for timestamp: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: timestamp)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        return DayPlanBlock.clampedStartMinute(minute)
    }

    private static func renderStart(for startedAt: Date, now: Date, calendar: Calendar) -> Date {
        if startedAt > now {
            return now
        }

        guard calendar.isDate(startedAt, inSameDayAs: now) else {
            return calendar.startOfDay(for: now)
        }

        return startedAt
    }
}

private struct DayPlanTimelineActivity: Equatable {
    var timestamp: Date
    var kind: RoutineLogKind
    var actualDurationMinutes: Int?
    var source: DayPlanTimelineActivitySource
}

private struct DayPlanTimelineActivityKey: Hashable {
    var dayKey: String
    var taskID: UUID
}

enum DayPlanFormatting {
    static func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        switch (hours, remainingMinutes) {
        case (0, let minutes):
            return "\(minutes)m"
        case (let hours, 0):
            return "\(hours)h"
        default:
            return "\(hours)h \(remainingMinutes)m"
        }
    }

    static func hourText(for hour: Int, on date: Date, calendar: Calendar) -> String {
        timeText(for: hour * 60, on: date, calendar: calendar)
    }

    static func timeText(for minute: Int, on date: Date, calendar: Calendar) -> String {
        let startOfDay = calendar.startOfDay(for: date)
        let clampedMinute = min(max(minute, 0), DayPlanBlock.minutesPerDay)
        let time = calendar.date(byAdding: .minute, value: clampedMinute, to: startOfDay) ?? startOfDay
        return time.formatted(date: .omitted, time: .shortened)
    }
}

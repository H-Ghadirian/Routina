import Foundation
import SwiftData

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

    var dismissalID: String {
        switch source {
        case let .log(logID):
            return "timeline-log-\(logID.uuidString)"
        case .taskLastDone:
            return [
                "timeline-last-done",
                block.taskID.uuidString,
                block.dayKey,
                String(Int(block.updatedAt.timeIntervalSinceReferenceDate.rounded())),
            ].joined(separator: "-")
        case .taskCanceledAt:
            return [
                "timeline-canceled",
                block.taskID.uuidString,
                block.dayKey,
                String(Int(block.updatedAt.timeIntervalSinceReferenceDate.rounded())),
            ].joined(separator: "-")
        }
    }
}

enum DayPlanTimelineActivitySource: Equatable {
    case log(UUID)
    case taskLastDone
    case taskCanceledAt
}

enum DayPlanHiddenTimelineActivityStore {
    static func hiddenIDs(from storage: String?) -> Set<String> {
        Set(
            (storage ?? "")
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    static func storageString(for hiddenIDs: Set<String>) -> String {
        hiddenIDs
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted()
            .joined(separator: "\n")
    }

    static func storageString(afterHiding activity: DayPlanTimelineActivityBlock, in storage: String?) -> String {
        var hiddenIDs = hiddenIDs(from: storage)
        hiddenIDs.insert(activity.dismissalID)
        return storageString(for: hiddenIDs)
    }
}

enum DayPlanTimelineTasks {
    private static let automaticSuggestionKinds: [RoutineLogKind] = [.completed]

    static func count(
        on date: Date,
        tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocks: [DayPlanBlock],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = []
    ) -> Int {
        activityBlocks(
            on: date,
            from: tasks,
            logs: logs,
            plannedBlocks: plannedBlocks,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs
        )
        .count
    }

    static func tasks(
        on date: Date,
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocks: [DayPlanBlock],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = []
    ) -> [RoutineTask] {
        let matchingIDs = Set(activityBlocks(
            on: date,
            from: tasks,
            logs: logs,
            plannedBlocks: plannedBlocks,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs
        ).map(\.block.taskID))

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
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = []
    ) -> [DayPlanTimelineActivityBlock] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        return activityBlocksByDayKey(
            on: [date],
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: [dayKey: plannedBlocks],
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs
        )[dayKey] ?? []
    }

    static func automaticSuggestionBlocks(
        on date: Date,
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocks: [DayPlanBlock],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = []
    ) -> [DayPlanTimelineActivityBlock] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        return automaticSuggestionBlocksByDayKey(
            on: [date],
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: [dayKey: plannedBlocks],
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs
        )[dayKey] ?? []
    }

    static func automaticSuggestionBlocksByDayKey(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = []
    ) -> [String: [DayPlanTimelineActivityBlock]] {
        activityBlocksByDayKey(
            on: dates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            excludesAllDayTasks: true,
            includedKinds: automaticSuggestionKinds
        )
    }

    static func activityBlocksByDayKey(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = [],
        excludesAllDayTasks: Bool = false,
        includedKinds: [RoutineLogKind]? = nil
    ) -> [String: [DayPlanTimelineActivityBlock]] {
        let visibleDayKeys = Set(dates.map { DayPlanStorage.dayKey(for: $0, calendar: calendar) })
        guard !visibleDayKeys.isEmpty else { return [:] }

        let tasksByID = Dictionary(grouping: tasks, by: \.id).compactMapValues(\.first)
        let plannedTaskIDsByDayKey = plannedBlocksByDayKey.mapValues { Set($0.map(\.taskID)) }
        var latestActivityByKey: [DayPlanTimelineActivityKey: DayPlanTimelineActivity] = [:]

        func record(_ activity: DayPlanTimelineActivity, taskID: UUID) {
            if let includedKinds, !includedKinds.contains(activity.kind) {
                return
            }
            guard let task = tasksByID[taskID] else { return }
            guard !excludesAllDayTasks || !task.isAllDay else { return }
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
            let activityBlock = DayPlanTimelineActivityBlock(
                block: block,
                kind: activity.kind,
                source: activity.source
            )
            guard !hiddenActivityIDs.contains(activityBlock.dismissalID) else { return nil }
            return activityBlock
        }

        let blocksByDayKey = Dictionary(grouping: blocks, by: \.block.dayKey)
        return Dictionary(uniqueKeysWithValues: blocksByDayKey.map { dayKey, dayBlocks in
            let plannedBlocks = plannedBlocksByDayKey[dayKey] ?? []
            let arrangedBlocks = arrangedTimelineActivityBlocks(
                dayBlocks,
                plannedBlocks: plannedBlocks,
                calendar: calendar
            )
            .sorted { lhs, rhs in
                if lhs.block.startMinute != rhs.block.startMinute {
                    return lhs.block.startMinute < rhs.block.startMinute
                }
                return lhs.block.titleSnapshot.localizedCaseInsensitiveCompare(rhs.block.titleSnapshot) == .orderedAscending
            }

            return (dayKey, arrangedBlocks)
        })
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

    private static func arrangedTimelineActivityBlocks(
        _ blocks: [DayPlanTimelineActivityBlock],
        plannedBlocks: [DayPlanBlock],
        calendar: Calendar
    ) -> [DayPlanTimelineActivityBlock] {
        let completedBlocks = blocks
            .filter { $0.kind == .completed }
            .sorted { lhs, rhs in
                if lhs.block.updatedAt != rhs.block.updatedAt {
                    return lhs.block.updatedAt > rhs.block.updatedAt
                }
                return lhs.block.titleSnapshot.localizedCaseInsensitiveCompare(rhs.block.titleSnapshot) == .orderedDescending
            }

        var occupiedIntervals = plannedBlocks.map(DayPlanOccupiedInterval.init(block:))
        let arrangedCompletedBlocks: [DayPlanTimelineActivityBlock] = completedBlocks.compactMap { activity in
            let completionMinute = startMinute(for: activity.block.updatedAt, calendar: calendar)
            guard let arrangedActivity = activity.ending(
                noLaterThan: completionMinute,
                avoiding: occupiedIntervals
            ) else {
                return nil
            }
            occupiedIntervals.append(DayPlanOccupiedInterval(block: arrangedActivity.block))
            return arrangedActivity
        }

        return blocks.filter { $0.kind != .completed } + arrangedCompletedBlocks
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

private struct DayPlanOccupiedInterval {
    var startMinute: Int
    var endMinute: Int

    init(block: DayPlanBlock) {
        self.startMinute = block.startMinute
        self.endMinute = block.endMinute
    }

    func overlaps(startMinute: Int, endMinute: Int) -> Bool {
        max(startMinute, self.startMinute) < min(endMinute, self.endMinute)
    }
}

private extension DayPlanTimelineActivityBlock {
    func ending(
        noLaterThan endMinute: Int,
        avoiding occupiedIntervals: [DayPlanOccupiedInterval]
    ) -> DayPlanTimelineActivityBlock? {
        var clampedEndMinute = min(max(endMinute, 0), DayPlanBlock.minutesPerDay)
        var startMinute = max(0, clampedEndMinute - block.durationMinutes)

        while clampedEndMinute >= DayPlanBlock.minimumDurationMinutes {
            let durationMinutes = clampedEndMinute - startMinute
            guard durationMinutes >= DayPlanBlock.minimumDurationMinutes else {
                return nil
            }

            if let conflict = occupiedIntervals
                .filter({ $0.overlaps(startMinute: startMinute, endMinute: clampedEndMinute) })
                .max(by: { $0.startMinute < $1.startMinute }) {
                clampedEndMinute = conflict.startMinute
                startMinute = max(0, clampedEndMinute - block.durationMinutes)
                continue
            }

            let adjustedBlock = DayPlanBlock(
                id: block.id,
                taskID: block.taskID,
                dayKey: block.dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: block.titleSnapshot,
                emojiSnapshot: block.emojiSnapshot,
                createdAt: block.createdAt,
                updatedAt: block.updatedAt
            )

            return DayPlanTimelineActivityBlock(
                block: adjustedBlock,
                kind: kind,
                source: source
            )
        }

        return nil
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

import Foundation
import SwiftData
import OSLog

struct DayPlanTimelineActivityBlock: Identifiable, Equatable {
    var block: DayPlanBlock
    var kind: RoutineLogKind
    var source: DayPlanTimelineActivitySource

    var id: String {
        switch source {
        case let .log(logID):
            return "timeline-log-\(logID.uuidString)"
        case .assumedDone:
            return "timeline-assumed-\(block.taskID.uuidString)-\(block.dayKey)"
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
        case .assumedDone:
            return "timeline-assumed-\(block.taskID.uuidString)-\(block.dayKey)"
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
    case assumedDone
    case taskLastDone
    case taskCanceledAt

    var isSyntheticAssumedDone: Bool {
        self == .assumedDone
    }
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

struct DayPlanTimelineActivityPlacement {
    var placed: [DayPlanTimelineActivityBlock]
    var unplaced: [DayPlanTimelineActivityBlock]

    func sorted() -> DayPlanTimelineActivityPlacement {
        DayPlanTimelineActivityPlacement(
            placed: DayPlanTimelineActivityPlacement.sorted(placed),
            unplaced: DayPlanTimelineActivityPlacement.sorted(unplaced)
        )
    }

    private static func sorted(
        _ blocks: [DayPlanTimelineActivityBlock]
    ) -> [DayPlanTimelineActivityBlock] {
        blocks.sorted { lhs, rhs in
            if lhs.block.startMinute != rhs.block.startMinute {
                return lhs.block.startMinute < rhs.block.startMinute
            }
            return lhs.block.titleSnapshot.localizedCaseInsensitiveCompare(rhs.block.titleSnapshot) == .orderedAscending
        }
    }

    func filteringBlockedIntervals(_ intervals: [DayPlanBlockedInterval]) -> DayPlanTimelineActivityPlacement {
        guard !intervals.isEmpty else { return sorted() }

        return DayPlanTimelineActivityPlacement(
            placed: placed.filter { !Self.isBlocked($0.block, by: intervals) },
            unplaced: unplaced.filter { !Self.isBlocked($0.block, by: intervals) }
        )
        .sorted()
    }

    private static func isBlocked(_ block: DayPlanBlock, by intervals: [DayPlanBlockedInterval]) -> Bool {
        intervals.contains { $0.overlaps(block: block) }
    }
}

private enum DayPlanPerformanceLog {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Routina",
        category: "PlannerPerformance"
    )
    private static let slowPlacementThresholdMilliseconds = 50.0

    static func logTimelinePlacementIfSlow(
        elapsedMilliseconds: Double,
        visibleDayCount: Int,
        taskCount: Int,
        logCount: Int,
        sourceCount: Int,
        placedCount: Int,
        unplacedCount: Int
    ) {
        guard elapsedMilliseconds >= slowPlacementThresholdMilliseconds else { return }

        logger.debug(
            """
            Planner timeline placement spike: \
            \(elapsedMilliseconds, format: .fixed(precision: 1), privacy: .public)ms, \
            days=\(visibleDayCount, privacy: .public), \
            tasks=\(taskCount, privacy: .public), \
            logs=\(logCount, privacy: .public), \
            sources=\(sourceCount, privacy: .public), \
            placed=\(placedCount, privacy: .public), \
            unplaced=\(unplacedCount, privacy: .public)
            """
        )
    }
}

enum DayPlanTimelineTasks {
    private static let automaticSuggestionKinds: [RoutineLogKind] = [.completed]

    static func count(
        on date: Date,
        tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocks: [DayPlanBlock],
        blockedIntervals: [DayPlanBlockedInterval] = [],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = [],
        referenceDate: Date = Date()
    ) -> Int {
        activityBlocks(
            on: date,
            from: tasks,
            logs: logs,
            plannedBlocks: plannedBlocks,
            blockedIntervals: blockedIntervals,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            referenceDate: referenceDate
        )
        .count
    }

    static func tasks(
        on date: Date,
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocks: [DayPlanBlock],
        blockedIntervals: [DayPlanBlockedInterval] = [],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = [],
        referenceDate: Date = Date()
    ) -> [RoutineTask] {
        let matchingIDs = Set(activityBlocks(
            on: date,
            from: tasks,
            logs: logs,
            plannedBlocks: plannedBlocks,
            blockedIntervals: blockedIntervals,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            referenceDate: referenceDate
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
        blockedIntervals: [DayPlanBlockedInterval] = [],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = [],
        referenceDate: Date = Date()
    ) -> [DayPlanTimelineActivityBlock] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        return activityBlocksByDayKey(
            on: [date],
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: [dayKey: plannedBlocks],
            blockedIntervalsByDayKey: [dayKey: blockedIntervals],
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            referenceDate: referenceDate
        )[dayKey] ?? []
    }

    static func automaticSuggestionBlocks(
        on date: Date,
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocks: [DayPlanBlock],
        blockedIntervals: [DayPlanBlockedInterval] = [],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = [],
        referenceDate: Date = Date()
    ) -> [DayPlanTimelineActivityBlock] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        return automaticSuggestionBlocksByDayKey(
            on: [date],
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: [dayKey: plannedBlocks],
            blockedIntervalsByDayKey: [dayKey: blockedIntervals],
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            referenceDate: referenceDate
        )[dayKey] ?? []
    }

    static func automaticSuggestionBlocksByDayKey(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]] = [:],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = [],
        referenceDate: Date = Date()
    ) -> [String: [DayPlanTimelineActivityBlock]] {
        activityBlocksByDayKey(
            on: dates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            excludesAllDayTasks: true,
            includedKinds: automaticSuggestionKinds,
            referenceDate: referenceDate
        )
    }

    static func automaticSuggestionPlacementsByDayKey(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]] = [:],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = [],
        referenceDate: Date = Date()
    ) -> [String: DayPlanTimelineActivityPlacement] {
        activityBlockPlacementsByDayKey(
            on: dates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            excludesAllDayTasks: true,
            includedKinds: automaticSuggestionKinds,
            referenceDate: referenceDate
        )
    }

    static func automaticUnplaceableSuggestionBlocksByDayKey(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]] = [:],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = [],
        referenceDate: Date = Date()
    ) -> [String: [DayPlanTimelineActivityBlock]] {
        activityBlockPlacementsByDayKey(
            on: dates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            excludesAllDayTasks: true,
            includedKinds: automaticSuggestionKinds,
            referenceDate: referenceDate
        )
        .mapValues { $0.unplaced }
    }

    static func assumedDoneSummaryBlocksByDayKey(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = [],
        referenceDate: Date = Date()
    ) -> [String: [DayPlanTimelineActivityBlock]] {
        activityBlocksByDayKey(
            on: dates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: [:],
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            excludesAllDayTasks: true,
            includedKinds: automaticSuggestionKinds,
            referenceDate: referenceDate
        )
        .mapValues { blocks in
            blocks.filter { $0.source.isSyntheticAssumedDone }
        }
    }

    static func activityBlocksByDayKey(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]] = [:],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = [],
        excludesAllDayTasks: Bool = false,
        includedKinds: [RoutineLogKind]? = nil,
        referenceDate: Date = Date()
    ) -> [String: [DayPlanTimelineActivityBlock]] {
        activityBlockPlacementsByDayKey(
            on: dates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            excludesAllDayTasks: excludesAllDayTasks,
            includedKinds: includedKinds,
            referenceDate: referenceDate
        )
        .mapValues { $0.placed }
    }

    private static func activityBlockPlacementsByDayKey(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]] = [:],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = [],
        excludesAllDayTasks: Bool = false,
        includedKinds: [RoutineLogKind]? = nil,
        referenceDate: Date = Date()
    ) -> [String: DayPlanTimelineActivityPlacement] {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let dateInfos = dates.map {
            DayPlanTimelineDateInfo(
                date: $0,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
        let visibleDayKeys = Set(dateInfos.map(\.dayKey))
        guard !visibleDayKeys.isEmpty else { return [:] }

        let taskInfosByID = Dictionary(
            grouping: tasks.map { DayPlanTimelineTaskInfo(task: $0) },
            by: \.id
        )
        .compactMapValues(\.first)
        let plannedTaskIDsByDayKey = plannedBlocksByDayKey.mapValues { Set($0.map(\.taskID)) }
        let recordedDayIndexes = recordedDayIndexes(
            taskInfosByID: taskInfosByID,
            logs: logs,
            calendar: calendar
        )
        var latestActivityByKey: [DayPlanTimelineActivityKey: DayPlanTimelineActivity] = [:]

        func record(_ activity: DayPlanTimelineActivity, taskID: UUID) {
            if let includedKinds, !includedKinds.contains(activity.kind) {
                return
            }
            guard let taskInfo = taskInfosByID[taskID] else { return }
            guard !excludesAllDayTasks || !taskInfo.isAllDay else { return }
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
            let kind = log.kind
            record(
                DayPlanTimelineActivity(
                    timestamp: timestamp,
                    kind: kind,
                    actualDurationMinutes: log.actualDurationMinutes,
                    source: .log(log.id)
                ),
                taskID: log.taskID
            )
        }

        for taskInfo in taskInfosByID.values {
            if let lastDone = taskInfo.lastDone {
                record(
                    DayPlanTimelineActivity(
                        timestamp: lastDone,
                        kind: .completed,
                        actualDurationMinutes: nil,
                        source: .taskLastDone
                    ),
                    taskID: taskInfo.id
                )
            }

            if taskInfo.isAssumedCompletionEligible {
                for dateInfo in dateInfos {
                    let assumedDay = taskInfo.currentOccurrenceDay(
                        referenceDate: dateInfo.assumptionReferenceDate,
                        calendar: calendar
                    )
                    guard calendar.isDate(assumedDay, inSameDayAs: dateInfo.date),
                          taskInfo.isAssumedDone(
                            on: assumedDay,
                            dayKey: dateInfo.dayKey,
                            referenceDate: dateInfo.assumptionReferenceDate,
                            recordedCompletionDayKeys: recordedDayIndexes.completed[taskInfo.id, default: []],
                            recordedCancellationDayKeys: recordedDayIndexes.canceled[taskInfo.id, default: []],
                            calendar: calendar
                          )
                    else {
                        continue
                    }

                    record(
                        DayPlanTimelineActivity(
                            timestamp: taskInfo.assumedCompletionTimestamp(
                                on: assumedDay,
                                calendar: calendar
                            ),
                            kind: .completed,
                            actualDurationMinutes: nil,
                            source: .assumedDone
                        ),
                        taskID: taskInfo.id
                    )
                }
            }

            if let canceledAt = taskInfo.canceledAt {
                record(
                    DayPlanTimelineActivity(
                        timestamp: canceledAt,
                        kind: .canceled,
                        actualDurationMinutes: nil,
                        source: .taskCanceledAt
                    ),
                    taskID: taskInfo.id
                )
            }
        }

        let blocks = latestActivityByKey.compactMap { key, activity -> DayPlanTimelineActivityBlock? in
            guard let taskInfo = taskInfosByID[key.taskID] else { return nil }
            let startMinute = startMinute(for: activity.timestamp, calendar: calendar)
            let durationMinutes = activity.actualDurationMinutes
                ?? taskInfo.estimatedDurationMinutes
                ?? DayPlanBlock.minimumDurationMinutes * 2
            let block = DayPlanBlock(
                id: taskInfo.id,
                taskID: taskInfo.id,
                dayKey: key.dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: taskInfo.title,
                emojiSnapshot: taskInfo.emoji,
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
        let placementsByDayKey = Dictionary(uniqueKeysWithValues: blocksByDayKey.map { dayKey, dayBlocks in
            let plannedBlocks = plannedBlocksByDayKey[dayKey] ?? []
            let placement = arrangedTimelineActivityBlocks(
                dayBlocks,
                plannedBlocks: plannedBlocks,
                calendar: calendar
            )
            let blockedIntervals = blockedIntervalsByDayKey[dayKey] ?? []
            let visiblePlacement = placement.filteringBlockedIntervals(blockedIntervals)

            return (dayKey, visiblePlacement)
        })

        let elapsedMilliseconds = (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
        let placedCount = placementsByDayKey.values.reduce(0) { $0 + $1.placed.count }
        let unplacedCount = placementsByDayKey.values.reduce(0) { $0 + $1.unplaced.count }
        DayPlanPerformanceLog.logTimelinePlacementIfSlow(
            elapsedMilliseconds: elapsedMilliseconds,
            visibleDayCount: dates.count,
            taskCount: tasks.count,
            logCount: logs.count,
            sourceCount: latestActivityByKey.count,
            placedCount: placedCount,
            unplacedCount: unplacedCount
        )

        return placementsByDayKey
    }

    private static func recordedDayIndexes(
        taskInfosByID: [UUID: DayPlanTimelineTaskInfo],
        logs: [RoutineLog],
        calendar: Calendar
    ) -> DayPlanTimelineRecordedDayIndexes {
        var completed: [UUID: Set<String>] = [:]
        var canceled: [UUID: Set<String>] = [:]

        for taskInfo in taskInfosByID.values {
            if let lastDone = taskInfo.lastDone {
                completed[taskInfo.id, default: []].insert(
                    taskInfo.recordedDisplayDayKey(for: lastDone, calendar: calendar)
                )
            }
            if let canceledAt = taskInfo.canceledAt {
                canceled[taskInfo.id, default: []].insert(
                    taskInfo.recordedDisplayDayKey(for: canceledAt, calendar: calendar)
                )
            }
        }

        for log in logs {
            guard let timestamp = log.timestamp,
                  let taskInfo = taskInfosByID[log.taskID]
            else { continue }

            let dayKey = taskInfo.recordedDisplayDayKey(for: timestamp, calendar: calendar)
            switch log.kind {
            case .completed:
                completed[log.taskID, default: []].insert(dayKey)
            case .canceled:
                canceled[log.taskID, default: []].insert(dayKey)
            case .missed:
                break
            }
        }

        return DayPlanTimelineRecordedDayIndexes(completed: completed, canceled: canceled)
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

        case .assumedDone:
            return false

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
    ) -> DayPlanTimelineActivityPlacement {
        let completedBlocks = blocks
            .filter { $0.kind == .completed }
            .sorted { lhs, rhs in
                if lhs.block.updatedAt != rhs.block.updatedAt {
                    return lhs.block.updatedAt > rhs.block.updatedAt
                }
                return lhs.block.titleSnapshot.localizedCaseInsensitiveCompare(rhs.block.titleSnapshot) == .orderedDescending
            }

        var occupiedIntervals = plannedBlocks.map(DayPlanOccupiedInterval.init(block:))
        var arrangedCompletedBlocks: [DayPlanTimelineActivityBlock] = []
        var unplacedBlocks: [DayPlanTimelineActivityBlock] = []

        for activity in completedBlocks {
            let completionMinute = startMinute(for: activity.block.updatedAt, calendar: calendar)
            guard let arrangedActivity = activity.ending(
                noLaterThan: completionMinute,
                avoiding: occupiedIntervals
            ) else {
                unplacedBlocks.append(activity)
                continue
            }
            occupiedIntervals.append(DayPlanOccupiedInterval(block: arrangedActivity.block))
            arrangedCompletedBlocks.append(arrangedActivity)
        }

        return DayPlanTimelineActivityPlacement(
            placed: blocks.filter { $0.kind != .completed } + arrangedCompletedBlocks,
            unplaced: unplacedBlocks
        )
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
        let preferredEndMinute = max(endMinute, block.durationMinutes)
        var clampedEndMinute = min(max(preferredEndMinute, DayPlanBlock.minimumDurationMinutes), DayPlanBlock.minutesPerDay)
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

private struct DayPlanTimelineDateInfo {
    var date: Date
    var dayKey: String
    var assumptionReferenceDate: Date

    init(date: Date, referenceDate: Date, calendar: Calendar) {
        self.date = date
        dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)

        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: referenceDate)
        guard day < today else {
            assumptionReferenceDate = referenceDate
            return
        }

        assumptionReferenceDate = calendar.date(
            byAdding: DateComponents(day: 1, second: -1),
            to: day
        ) ?? day
    }
}

private struct DayPlanTimelineRecordedDayIndexes {
    var completed: [UUID: Set<String>]
    var canceled: [UUID: Set<String>]
}

private struct DayPlanTimelineTaskInfo {
    var task: RoutineTask
    var id: UUID
    var title: String
    var emoji: String?
    var isAllDay: Bool
    var lastDone: Date?
    var canceledAt: Date?
    var estimatedDurationMinutes: Int?
    var autoAssumeDoneTimeOfDay: RoutineTimeOfDay?
    var createdAt: Date?
    var pausedAt: Date?
    var snoozedUntil: Date?
    var recurrenceRule: RoutineRecurrenceRule
    var hasChecklistItems: Bool
    var isAssumedCompletionEligible: Bool

    init(task: RoutineTask) {
        let scheduleMode = task.scheduleMode
        let recurrenceRule = task.recurrenceRule
        let hasSequentialSteps = task.hasSequentialSteps
        let hasChecklistItems = task.hasChecklistItems

        self.task = task
        id = task.id
        title = DayPlanTaskSorting.title(for: task)
        emoji = CalendarTaskImportSupport.displayEmoji(for: task.emoji)
        isAllDay = task.isAllDay
        lastDone = task.lastDone
        canceledAt = task.canceledAt
        estimatedDurationMinutes = task.estimatedDurationMinutes
        autoAssumeDoneTimeOfDay = task.autoAssumeDoneTimeOfDay
        createdAt = task.createdAt
        pausedAt = task.pausedAt
        snoozedUntil = task.snoozedUntil
        self.recurrenceRule = recurrenceRule
        self.hasChecklistItems = hasChecklistItems
        isAssumedCompletionEligible = task.autoAssumeDailyDone
            && RoutineAssumedCompletion.isEligible(
                scheduleMode: scheduleMode,
                recurrenceRule: recurrenceRule,
                hasSequentialSteps: hasSequentialSteps,
                hasChecklistItems: hasChecklistItems
            )
    }

    func currentOccurrenceDay(referenceDate: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: referenceDate)
        guard let timeRange = recurrenceRule.timeRange,
              timeRange.isOvernight
        else {
            return today
        }

        let referenceTime = RoutineTimeOfDay.from(referenceDate, calendar: calendar)
        guard referenceTime.minutesFromStartOfDay < timeRange.start.minutesFromStartOfDay,
              let previousDay = calendar.date(byAdding: .day, value: -1, to: today)
        else {
            return today
        }

        return previousDay
    }

    func isAssumedDone(
        on day: Date,
        dayKey: String,
        referenceDate: Date,
        recordedCompletionDayKeys: Set<String>,
        recordedCancellationDayKeys: Set<String>,
        calendar: Calendar
    ) -> Bool {
        guard isAssumedCompletionEligible else { return false }

        let selectedDay = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: referenceDate)
        guard selectedDay <= today else { return false }

        if let createdAt {
            let createdDay = calendar.startOfDay(for: createdAt)
            guard selectedDay >= createdDay else { return false }
        }

        if let pausedAt,
           selectedDay >= calendar.startOfDay(for: pausedAt) {
            return false
        }

        if selectedDay == today, isArchived(referenceDate: referenceDate, calendar: calendar) {
            return false
        }

        if recordedCompletionDayKeys.contains(dayKey) {
            return false
        }

        if recordedCancellationDayKeys.contains(dayKey) {
            return false
        }

        if hasChecklistItems,
           task.isChecklistInProgress(referenceDate: selectedDay, calendar: calendar) {
            return false
        }

        if selectedDay == today {
            return referenceDate >= availableAt(on: selectedDay, calendar: calendar)
        }

        return true
    }

    func assumedCompletionTimestamp(on day: Date, calendar: Calendar) -> Date {
        (autoAssumeDoneTimeOfDay ?? RoutineAssumedCompletion.defaultDoneTimeOfDay)
            .date(on: day, calendar: calendar)
    }

    func recordedDisplayDayKey(for timestamp: Date, calendar: Calendar) -> String {
        let displayDay = RoutineDateMath.completionDisplayDay(
            for: task,
            completionDate: timestamp,
            calendar: calendar
        ) ?? calendar.startOfDay(for: timestamp)
        return DayPlanStorage.dayKey(for: displayDay, calendar: calendar)
    }

    private func availableAt(on day: Date, calendar: Calendar) -> Date {
        if let timeRange = recurrenceRule.timeRange {
            return timeRange.startDate(on: day, calendar: calendar)
        }
        if let timeOfDay = recurrenceRule.timeOfDay {
            return timeOfDay.date(on: day, calendar: calendar)
        }
        return calendar.startOfDay(for: day)
    }

    private func isArchived(referenceDate: Date, calendar: Calendar) -> Bool {
        if pausedAt != nil {
            return true
        }
        guard let snoozedUntil else { return false }
        return calendar.startOfDay(for: referenceDate) < calendar.startOfDay(for: snoozedUntil)
    }
}

private struct DayPlanTimelineActivityKey: Hashable {
    var dayKey: String
    var taskID: UUID
}

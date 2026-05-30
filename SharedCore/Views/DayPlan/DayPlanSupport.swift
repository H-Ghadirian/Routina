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

struct DayPlanFocusSessionBlock: Identifiable, Equatable {
    var sessionID: UUID
    var block: DayPlanBlock
    var durationMinutes: Int

    var id: String {
        "\(block.dayKey)-\(sessionID.uuidString)"
    }
}

struct DayPlanBlockedInterval: Equatable, Sendable {
    var dayKey: String
    var startMinute: Int
    var endMinute: Int
    var title: String

    var durationMinutes: Int {
        max(endMinute - startMinute, 0)
    }

    func overlaps(startMinute: Int, durationMinutes: Int) -> Bool {
        let targetStart = DayPlanBlock.clampedStartMinute(startMinute)
        let targetDuration = DayPlanBlock.clampedDuration(durationMinutes, startMinute: targetStart)
        let targetEnd = min(DayPlanBlock.minutesPerDay, targetStart + targetDuration)
        return max(targetStart, self.startMinute) < min(targetEnd, endMinute)
    }
}

struct DayPlanSleepBlock: Identifiable, Equatable {
    var sessionID: UUID
    var block: DayPlanBlock
    var interval: DayPlanBlockedInterval

    var id: String {
        "sleep-\(sessionID.uuidString)-\(block.dayKey)"
    }
}

struct DayPlanEventBlock: Identifiable, Equatable {
    var eventID: UUID
    var block: DayPlanBlock

    var id: String {
        "event-\(eventID.uuidString)-\(block.dayKey)"
    }
}

struct DayPlanAllDayBlock: Identifiable, Equatable {
    var id: UUID
    var taskID: UUID?
    var eventID: UUID?
    var title: String
    var emoji: String?
    var startDate: Date
    var endDate: Date
    var isLegacyDateOnlyCalendarTask: Bool
    var isEvent: Bool
}

enum DayPlanAllDayTasks {
    private typealias AllDaySpan = (startDate: Date, endDate: Date, isLegacyDateOnlyCalendarTask: Bool)

    static func blocks(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog] = [],
        events: [RoutineEvent] = [],
        calendar: Calendar
    ) -> [DayPlanAllDayBlock] {
        guard let firstDate = dates.first,
              let lastDate = dates.last,
              let visibleEnd = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: lastDate)
              )
        else { return [] }

        let visibleStart = calendar.startOfDay(for: firstDate)
        let logsByTaskID = Dictionary(grouping: logs, by: \.taskID)

        let taskBlocks = tasks.flatMap { task -> [DayPlanAllDayBlock] in
            guard !task.isCanceledOneOff,
                  !task.isArchived(referenceDate: visibleStart, calendar: calendar) else {
                return []
            }

            return allDaySpans(
                for: task,
                on: dates,
                logs: logsByTaskID[task.id] ?? [],
                calendar: calendar
            )
                .filter { span in
                    span.endDate > visibleStart && span.startDate < visibleEnd
                }
                .map { span in
                    DayPlanAllDayBlock(
                        id: task.id,
                        taskID: task.id,
                        eventID: nil,
                        title: DayPlanTaskSorting.title(for: task),
                        emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
                        startDate: span.startDate,
                        endDate: span.endDate,
                        isLegacyDateOnlyCalendarTask: span.isLegacyDateOnlyCalendarTask,
                        isEvent: false
                    )
                }
        }

        let eventBlocks = events.compactMap { event -> DayPlanAllDayBlock? in
            guard event.isAllDay,
                  let startedAt = event.startedAt else {
                return nil
            }

            let startDate = calendar.startOfDay(for: startedAt)
            let endDate = normalizedEndDate(
                startDate: startedAt,
                endDate: event.endedAt ?? startedAt,
                calendar: calendar
            )
            guard endDate > visibleStart, startDate < visibleEnd else { return nil }

            return DayPlanAllDayBlock(
                id: event.id,
                taskID: nil,
                eventID: event.id,
                title: event.displayTitle,
                emoji: event.displayEmoji,
                startDate: startDate,
                endDate: endDate,
                isLegacyDateOnlyCalendarTask: false,
                isEvent: true
            )
        }

        return (taskBlocks + eventBlocks)
        .sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate {
                return lhs.startDate < rhs.startDate
            }
            if lhs.endDate != rhs.endDate {
                return lhs.endDate > rhs.endDate
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func allDaySpans(
        for task: RoutineTask,
        on dates: [Date],
        logs: [RoutineLog],
        calendar: Calendar
    ) -> [AllDaySpan] {
        if let metadata = CalendarTaskImportSupport.eventMetadata(in: task.notes),
           metadata.isAllDay {
            let startDate = calendar.startOfDay(for: metadata.startDate)
            let endDate = normalizedEndDate(
                startDate: metadata.startDate,
                endDate: metadata.endDate,
                calendar: calendar
            )
            guard endDate > startDate else { return [] }
            return [(startDate, endDate, false)]
        }

        if task.isAllDay {
            var spans: [AllDaySpan] = []
            if task.isOneOffTask,
               let deadline = task.deadline,
               let span = oneDaySpan(on: deadline, calendar: calendar) {
                spans.append(span)
            } else {
                spans += routineAllDayOccurrenceStarts(for: task, on: dates, calendar: calendar)
                    .compactMap { startDate in
                        oneDaySpan(on: startDate, calendar: calendar)
                    }
            }

            spans += completedActivityStarts(for: task, logs: logs, on: dates, calendar: calendar)
                .compactMap { startDate in
                    oneDaySpan(on: startDate, calendar: calendar)
                }

            return deduplicatedOneDaySpans(spans, calendar: calendar)
        }

        guard task.isOneOffTask,
              let notes = task.notes,
              CalendarTaskImportSupport.sourceMarker(in: notes) != nil,
              let deadline = task.deadline,
              !hasExplicitTime(deadline, calendar: calendar) else {
            return []
        }

        guard let span = oneDaySpan(on: deadline, calendar: calendar) else { return [] }
        return [(span.startDate, span.endDate, true)]
    }

    private static func oneDaySpan(
        on date: Date,
        calendar: Calendar
    ) -> AllDaySpan? {
        let startDate = calendar.startOfDay(for: date)
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: startDate),
              endDate > startDate else {
            return nil
        }
        return (startDate, endDate, false)
    }

    private static func completedActivityStarts(
        for task: RoutineTask,
        logs: [RoutineLog],
        on dates: [Date],
        calendar: Calendar
    ) -> [Date] {
        let visibleDayKeys = Set(dates.map { DayPlanStorage.dayKey(for: $0, calendar: calendar) })
        guard !visibleDayKeys.isEmpty else { return [] }

        var startsByDayKey: [String: Date] = [:]
        func record(_ timestamp: Date?) {
            guard let timestamp else { return }
            let startDate = calendar.startOfDay(for: timestamp)
            let dayKey = DayPlanStorage.dayKey(for: startDate, calendar: calendar)
            guard visibleDayKeys.contains(dayKey) else { return }
            startsByDayKey[dayKey] = startDate
        }

        logs
            .filter { $0.kind == .completed }
            .forEach { record($0.timestamp) }
        record(task.lastDone)

        return startsByDayKey.values.sorted()
    }

    private static func deduplicatedOneDaySpans(
        _ spans: [AllDaySpan],
        calendar: Calendar
    ) -> [AllDaySpan] {
        var seenDayKeys = Set<String>()
        return spans.filter { span in
            let dayKey = DayPlanStorage.dayKey(for: span.startDate, calendar: calendar)
            return seenDayKeys.insert(dayKey).inserted
        }
    }

    private static func routineAllDayOccurrenceStarts(
        for task: RoutineTask,
        on dates: [Date],
        calendar: Calendar
    ) -> [Date] {
        guard !task.isOneOffTask else { return [] }

        return dates.compactMap { date in
            let startOfDay = calendar.startOfDay(for: date)
            return routineOccurs(task, on: startOfDay, calendar: calendar) ? startOfDay : nil
        }
    }

    private static func routineOccurs(
        _ task: RoutineTask,
        on day: Date,
        calendar: Calendar
    ) -> Bool {
        switch task.recurrenceRule.kind {
        case .dailyTime:
            return true

        case .weekly:
            let weekday = task.recurrenceRule.weekday ?? calendar.firstWeekday
            return calendar.component(.weekday, from: day) == weekday

        case .monthlyDay:
            let dayOfMonth = clampedDayOfMonth(
                task.recurrenceRule.dayOfMonth ?? 1,
                monthContaining: day,
                calendar: calendar
            )
            return calendar.component(.day, from: day) == dayOfMonth

        case .intervalDays:
            let dueDate = RoutineDateMath.upcomingDueDate(
                for: task,
                referenceDate: day,
                calendar: calendar
            )
            return calendar.isDate(dueDate, inSameDayAs: day)
        }
    }

    private static func clampedDayOfMonth(
        _ dayOfMonth: Int,
        monthContaining date: Date,
        calendar: Calendar
    ) -> Int {
        guard let range = calendar.range(of: .day, in: .month, for: date) else {
            return min(max(dayOfMonth, 1), 31)
        }
        return min(max(dayOfMonth, range.lowerBound), range.upperBound - 1)
    }

    private static func normalizedEndDate(
        startDate: Date,
        endDate: Date,
        calendar: Calendar
    ) -> Date {
        let startDay = calendar.startOfDay(for: startDate)
        guard endDate > startDate else {
            return calendar.date(byAdding: .day, value: 1, to: startDay) ?? startDay
        }

        let endDay = calendar.startOfDay(for: endDate)
        if endDay <= startDay {
            return calendar.date(byAdding: .day, value: 1, to: startDay) ?? startDay
        }

        if hasExplicitTime(endDate, calendar: calendar) {
            return calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        }

        return endDay
    }

    private static func hasExplicitTime(_ date: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        return (components.hour ?? 0) != 0
            || (components.minute ?? 0) != 0
            || (components.second ?? 0) != 0
            || (components.nanosecond ?? 0) != 0
    }
}

enum DayPlanEventBlocks {
    static func blocksByDayKey(
        on dates: [Date],
        from events: [RoutineEvent],
        calendar: Calendar
    ) -> [String: [DayPlanEventBlock]] {
        let visibleDates = dates.map { calendar.startOfDay(for: $0) }
        guard !visibleDates.isEmpty else { return [:] }

        let blocks = events.flatMap { event in
            blocksForEvent(event, on: visibleDates, calendar: calendar)
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

    private static func blocksForEvent(
        _ event: RoutineEvent,
        on visibleDates: [Date],
        calendar: Calendar
    ) -> [DayPlanEventBlock] {
        guard !event.isAllDay,
              let startedAt = event.startedAt else {
            return []
        }

        let endedAt = event.endedAt ?? startedAt.addingTimeInterval(60 * 60)
        guard endedAt > startedAt else { return [] }

        return visibleDates.compactMap { visibleDate -> DayPlanEventBlock? in
            let dayStart = calendar.startOfDay(for: visibleDate)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return nil
            }

            let intervalStart = max(startedAt, dayStart)
            let intervalEnd = min(endedAt, dayEnd)
            guard intervalEnd > intervalStart else { return nil }

            let dayKey = DayPlanStorage.dayKey(for: dayStart, calendar: calendar)
            let startMinute = Self.startMinute(for: intervalStart, calendar: calendar)
            let rawDuration = max(1, Int(ceil(intervalEnd.timeIntervalSince(intervalStart) / 60)))
            let durationMinutes = DayPlanBlock.clampedDuration(rawDuration, startMinute: startMinute)
            let block = DayPlanBlock(
                id: event.id,
                taskID: event.id,
                dayKey: dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: event.displayTitle,
                emojiSnapshot: event.displayEmoji,
                createdAt: startedAt,
                updatedAt: endedAt
            )
            return DayPlanEventBlock(eventID: event.id, block: block)
        }
    }

    private static func startMinute(for timestamp: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: timestamp)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        return DayPlanBlock.clampedStartMinute(minute)
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

enum DayPlanFocusSessionBlocks {
    static func activeBlocksByDayKey(
        on dates: [Date],
        from tasks: [RoutineTask],
        sessions: [FocusSession],
        now: Date,
        calendar: Calendar,
        excluding plannedBlocks: [DayPlanBlock] = []
    ) -> [String: [DayPlanFocusSessionBlock]] {
        let visibleDayKeys = Set(dates.map { DayPlanStorage.dayKey(for: $0, calendar: calendar) })
        guard !visibleDayKeys.isEmpty else { return [:] }

        let blocks = activeBlocks(
            from: tasks,
            sessions: sessions,
            now: now,
            calendar: calendar,
            excluding: plannedBlocks
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
        calendar: Calendar,
        excluding plannedBlocks: [DayPlanBlock] = []
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
            if session.plannedDurationSeconds > 0 {
                guard !isRepresentedByPlannerBlock(block, plannedBlocks: plannedBlocks) else {
                    return nil
                }
            }

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

    private static func isRepresentedByPlannerBlock(
        _ focusBlock: DayPlanBlock,
        plannedBlocks: [DayPlanBlock]
    ) -> Bool {
        plannedBlocks.contains { plannedBlock in
            if plannedBlock.id == focusBlock.id {
                return true
            }

            guard plannedBlock.taskID == focusBlock.taskID,
                  plannedBlock.dayKey == focusBlock.dayKey else {
                return false
            }

            return plannedBlock.startMinute < focusBlock.endMinute
                && focusBlock.startMinute < plannedBlock.endMinute
        }
    }
}

enum DayPlanFocusSessionPlannerSync {
    @discardableResult
    static func saveStartedFocusBlock(
        for task: RoutineTask,
        session: FocusSession,
        startedAt: Date,
        durationSeconds: TimeInterval,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        let block = plannerBlock(
            for: task,
            session: session,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            calendar: calendar
        )
        var blocks = DayPlanStorage.loadBlocks(forDayKey: block.dayKey, context: context)

        if let existingBlock = blocks.first(where: { $0.id == block.id }) {
            return existingBlock
        }

        if durationSeconds > 0,
           let existingBlock = blocks.first(where: { representsFocusBlock($0, focusBlock: block) }) {
            return existingBlock
        }

        blocks.append(block)
        DayPlanStorage.saveBlocks(blocks, forDayKey: block.dayKey, context: context)
        return block
    }

    @discardableResult
    static func saveEndedCountUpFocusBlock(
        for task: RoutineTask,
        session: FocusSession,
        endedAt: Date,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        guard session.plannedDurationSeconds <= 0,
              let startedAt = session.startedAt else {
            return nil
        }

        let elapsedSeconds = max(60, endedAt.timeIntervalSince(startedAt))
        let block = plannerBlock(
            for: task,
            session: session,
            startedAt: startedAt,
            durationSeconds: elapsedSeconds,
            calendar: calendar,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        var blocks = DayPlanStorage.loadBlocks(forDayKey: block.dayKey, context: context)

        if let index = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks[index] = block
        } else {
            blocks.append(block)
        }

        DayPlanStorage.saveBlocks(blocks, forDayKey: block.dayKey, context: context)
        return block
    }

    static func plannerBlock(
        for task: RoutineTask,
        session: FocusSession,
        startedAt: Date,
        durationSeconds: TimeInterval,
        calendar: Calendar,
        minimumDurationMinutes: Int? = nil
    ) -> DayPlanBlock {
        let minimumDurationMinutes = minimumDurationMinutes
            ?? (durationSeconds > 0 ? DayPlanBlock.minimumDurationMinutes : DayPlanBlock.minimumStoredDurationMinutes)
        let startMinute = startMinute(
            for: startedAt,
            calendar: calendar,
            minimumDurationMinutes: minimumDurationMinutes
        )
        return DayPlanBlock(
            id: session.id,
            taskID: task.id,
            dayKey: DayPlanStorage.dayKey(for: startedAt, calendar: calendar),
            startMinute: startMinute,
            durationMinutes: durationMinutes(
                durationSeconds: durationSeconds,
                startMinute: startMinute,
                minimumDurationMinutes: minimumDurationMinutes
            ),
            titleSnapshot: DayPlanTaskSorting.title(for: task),
            emojiSnapshot: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
            createdAt: startedAt,
            updatedAt: startedAt,
            minimumDurationMinutes: minimumDurationMinutes
        )
    }

    private static func startMinute(
        for timestamp: Date,
        calendar: Calendar,
        minimumDurationMinutes: Int = DayPlanBlock.minimumDurationMinutes
    ) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: timestamp)
        return DayPlanBlock.clampedStartMinute(
            ((components.hour ?? 0) * 60) + (components.minute ?? 0),
            minimumDurationMinutes: minimumDurationMinutes
        )
    }

    private static func durationMinutes(
        durationSeconds: TimeInterval,
        startMinute: Int,
        minimumDurationMinutes: Int
    ) -> Int {
        let rawMinutes = durationSeconds > 0 ? max(1, Int(ceil(durationSeconds / 60))) : 1
        return DayPlanBlock.clampedDuration(
            rawMinutes,
            startMinute: startMinute,
            minimumDurationMinutes: minimumDurationMinutes
        )
    }

    private static func representsFocusBlock(
        _ plannedBlock: DayPlanBlock,
        focusBlock: DayPlanBlock
    ) -> Bool {
        if plannedBlock.id == focusBlock.id {
            return true
        }

        guard plannedBlock.taskID == focusBlock.taskID,
              plannedBlock.dayKey == focusBlock.dayKey else {
            return false
        }

        return plannedBlock.startMinute < focusBlock.endMinute
            && focusBlock.startMinute < plannedBlock.endMinute
    }
}

enum DayPlanSleepBlocks {
    static func blocksByDayKey(
        on dates: [Date],
        from sessions: [SleepSession],
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> [String: [DayPlanSleepBlock]] {
        let visibleDates = dates.map { calendar.startOfDay(for: $0) }
        guard !visibleDates.isEmpty else { return [:] }

        let blocks = sessions.flatMap { session in
            blocksForSession(
                for: session,
                on: visibleDates,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }

        return Dictionary(grouping: blocks, by: \.block.dayKey)
            .mapValues {
                $0.sorted { lhs, rhs in
                    if lhs.block.startMinute != rhs.block.startMinute {
                        return lhs.block.startMinute < rhs.block.startMinute
                    }
                    return lhs.block.createdAt < rhs.block.createdAt
                }
            }
    }

    static func blockedIntervalsByDayKey(
        on dates: [Date],
        from sessions: [SleepSession],
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> [String: [DayPlanBlockedInterval]] {
        blocksByDayKey(
            on: dates,
            from: sessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        .mapValues { blocks in
            blocks.map(\.interval)
        }
    }

    static func blockedIntervals(
        on date: Date,
        from sessions: [SleepSession],
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> [DayPlanBlockedInterval] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        return blockedIntervalsByDayKey(
            on: [date],
            from: sessions,
            referenceDate: referenceDate,
            calendar: calendar
        )[dayKey] ?? []
    }

    static func conflictingInterval(
        on date: Date,
        from sessions: [SleepSession],
        startMinute: Int,
        durationMinutes: Int,
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> DayPlanBlockedInterval? {
        blockedIntervals(
            on: date,
            from: sessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        .first {
            $0.overlaps(startMinute: startMinute, durationMinutes: durationMinutes)
        }
    }

    private static func blocksForSession(
        for session: SleepSession,
        on visibleDates: [Date],
        referenceDate: Date,
        calendar: Calendar
    ) -> [DayPlanSleepBlock] {
        guard let startedAt = session.startedAt else { return [] }

        let endedAt = session.endedAt ?? referenceDate
        guard endedAt > startedAt else { return [] }

        return visibleDates.compactMap { visibleDate -> DayPlanSleepBlock? in
            let dayStart = calendar.startOfDay(for: visibleDate)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return nil
            }

            let intervalStart = max(startedAt, dayStart)
            let intervalEnd = min(endedAt, dayEnd)
            guard intervalEnd > intervalStart else { return nil }

            let dayKey = DayPlanStorage.dayKey(for: dayStart, calendar: calendar)
            let startMinute = Self.startMinute(for: intervalStart, calendar: calendar)
            let rawDuration = max(1, Int(ceil(intervalEnd.timeIntervalSince(intervalStart) / 60)))
            let durationMinutes = DayPlanBlock.clampedDuration(rawDuration, startMinute: startMinute)
            let block = DayPlanBlock(
                id: session.id,
                taskID: session.id,
                dayKey: dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: "Sleep",
                emojiSnapshot: "🛌",
                createdAt: startedAt,
                updatedAt: endedAt
            )
            let interval = DayPlanBlockedInterval(
                dayKey: dayKey,
                startMinute: block.startMinute,
                endMinute: block.endMinute,
                title: "Sleep"
            )

            return DayPlanSleepBlock(
                sessionID: session.id,
                block: block,
                interval: interval
            )
        }
    }

    private static func startMinute(for timestamp: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: timestamp)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        return DayPlanBlock.clampedStartMinute(minute)
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

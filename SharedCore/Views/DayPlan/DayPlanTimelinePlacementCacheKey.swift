import Foundation

struct DayPlanTimelinePlacementCacheKey: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var referenceAssumptionBucket: DayPlanTimelineReferenceAssumptionBucket
    var visibleDayKeys: [String]
    var hiddenActivityIDs: [String]
    var tasks: [TaskSnapshot]
    var logs: [LogSnapshot]
    var plannedDays: [DayBlocksSnapshot]
    var blockedDays: [DayBlockedIntervalsSnapshot]

    init(
        dates: [Date],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]],
        calendar: Calendar,
        hiddenActivityIDs: Set<String>,
        referenceDate: Date
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        referenceAssumptionBucket = DayPlanTimelineReferenceAssumptionBucket(
            dates: dates,
            tasks: tasks,
            calendar: calendar,
            referenceDate: referenceDate
        )
        visibleDayKeys =
            dates
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
            .sorted()
        self.hiddenActivityIDs = hiddenActivityIDs.sorted()
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
        plannedDays =
            plannedBlocksByDayKey
            .map { dayKey, blocks in
                DayBlocksSnapshot(dayKey: dayKey, blocks: blocks)
            }
            .sorted { $0.dayKey < $1.dayKey }
        blockedDays =
            blockedIntervalsByDayKey
            .map { dayKey, intervals in
                DayBlockedIntervalsSnapshot(dayKey: dayKey, intervals: intervals)
            }
            .sorted { $0.dayKey < $1.dayKey }
    }

    struct TaskSnapshot: Equatable {
        var id: UUID
        var name: String?
        var emoji: String?
        var isAllDay: Bool
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
        var autoAssumeDailyDone: Bool
        var autoAssumeDoneTimeOfDayHour: Int?
        var autoAssumeDoneTimeOfDayMinute: Int?
        var estimatedDurationMinutes: Int?
        var hasStoredSequentialSteps: Bool
        var hasStoredChecklistItems: Bool
        var autoAssumeChecklistItemsStorage: String?
        var autoAssumeCompletedChecklistItemIDsStorage: String?
        var autoAssumeCompletedChecklistProgressStartedAt: Date?

        init(task: RoutineTask) {
            id = task.id
            name = task.name
            emoji = task.emoji
            let autoAssumeDailyDone = task.autoAssumeDailyDone
            let checklistItemsStorage = task.checklistItemsStorage
            isAllDay = task.isAllDay
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
            self.autoAssumeDailyDone = autoAssumeDailyDone
            autoAssumeDoneTimeOfDayHour = autoAssumeDailyDone ? task.autoAssumeDoneTimeOfDayHour : nil
            autoAssumeDoneTimeOfDayMinute = autoAssumeDailyDone ? task.autoAssumeDoneTimeOfDayMinute : nil
            estimatedDurationMinutes = task.estimatedDurationMinutes
            hasStoredSequentialSteps = !task.stepsStorage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            hasStoredChecklistItems = !checklistItemsStorage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            autoAssumeChecklistItemsStorage = autoAssumeDailyDone ? checklistItemsStorage : nil
            autoAssumeCompletedChecklistItemIDsStorage =
                autoAssumeDailyDone
                ? task.completedChecklistItemIDsStorage
                : nil
            autoAssumeCompletedChecklistProgressStartedAt =
                autoAssumeDailyDone
                ? task.completedChecklistProgressStartedAt
                : nil
        }
    }

    struct LogSnapshot: Equatable {
        var id: UUID
        var timestamp: Date?
        var taskID: UUID
        var kindRawValue: String
        var actualDurationMinutes: Int?
        var hasSpecificWorkTime: Bool?
        var sourceTaskID: UUID?

        init(log: RoutineLog) {
            id = log.id
            timestamp = log.timestamp
            taskID = log.taskID
            kindRawValue = log.kindRawValue
            actualDurationMinutes = log.actualDurationMinutes
            hasSpecificWorkTime = log.hasSpecificWorkTime
            sourceTaskID = log.sourceTaskID
        }
    }

    struct DayBlocksSnapshot: Equatable {
        var dayKey: String
        var blocks: [BlockSnapshot]

        init(dayKey: String, blocks: [DayPlanBlock]) {
            self.dayKey = dayKey
            self.blocks =
                blocks
                .map { BlockSnapshot(block: $0) }
                .sorted { lhs, rhs in
                    if lhs.dayKey != rhs.dayKey {
                        return lhs.dayKey < rhs.dayKey
                    }
                    if lhs.startMinute != rhs.startMinute {
                        return lhs.startMinute < rhs.startMinute
                    }
                    if lhs.durationMinutes != rhs.durationMinutes {
                        return lhs.durationMinutes < rhs.durationMinutes
                    }
                    return lhs.taskID.uuidString < rhs.taskID.uuidString
                }
        }
    }

    struct BlockSnapshot: Equatable {
        var taskID: UUID
        var dayKey: String
        var startMinute: Int
        var durationMinutes: Int

        init(block: DayPlanBlock) {
            taskID = block.taskID
            dayKey = block.dayKey
            startMinute = block.startMinute
            durationMinutes = block.durationMinutes
        }
    }

    struct DayBlockedIntervalsSnapshot: Equatable {
        var dayKey: String
        var intervals: [BlockedIntervalSnapshot]

        init(dayKey: String, intervals: [DayPlanBlockedInterval]) {
            self.dayKey = dayKey
            self.intervals =
                intervals
                .map { BlockedIntervalSnapshot(interval: $0) }
                .sorted { lhs, rhs in
                    if lhs.startMinute != rhs.startMinute {
                        return lhs.startMinute < rhs.startMinute
                    }
                    return lhs.endMinute < rhs.endMinute
                }
        }
    }

    struct BlockedIntervalSnapshot: Equatable {
        var dayKey: String
        var startMinute: Int
        var endMinute: Int

        init(interval: DayPlanBlockedInterval) {
            dayKey = interval.dayKey
            startMinute = interval.startMinute
            endMinute = interval.endMinute
        }
    }
}

struct DayPlanTimelineReferenceAssumptionBucket: Equatable {
    var referenceDayKey: String
    var passedAvailabilityBoundaryCount: Int

    init(
        dates: [Date],
        tasks: [RoutineTask],
        calendar: Calendar,
        referenceDate: Date
    ) {
        let today = calendar.startOfDay(for: referenceDate)
        referenceDayKey = DayPlanStorage.dayKey(for: today, calendar: calendar)

        let visibleDayKeys = Set(dates.map { DayPlanStorage.dayKey(for: $0, calendar: calendar) })
        guard visibleDayKeys.contains(referenceDayKey) else {
            passedAvailabilityBoundaryCount = 0
            return
        }

        let currentTime = RoutineTimeOfDay.from(referenceDate, calendar: calendar)
        let currentMinute = currentTime.minutesFromStartOfDay
        let boundaries = Set(tasks.compactMap(Self.availabilityBoundaryMinute))
        passedAvailabilityBoundaryCount = boundaries.filter { $0 <= currentMinute }.count
    }

    private static func availabilityBoundaryMinute(for task: RoutineTask) -> Int? {
        guard RoutineAssumedCompletion.isEligible(task) else { return nil }

        if let minute = clampedMinute(
            hour: task.recurrenceTimeRangeStartHour,
            minute: task.recurrenceTimeRangeStartMinute
        ) {
            return minute
        }

        if let minute = clampedMinute(
            hour: task.recurrenceTimeOfDayHour,
            minute: task.recurrenceTimeOfDayMinute
        ) {
            return minute
        }

        return 0
    }

    private static func clampedMinute(hour: Int, minute: Int) -> Int {
        min(max(hour, 0), 23) * 60 + min(max(minute, 0), 59)
    }

    private static func clampedMinute(hour: Int?, minute: Int?) -> Int? {
        guard let hour, let minute else { return nil }
        return clampedMinute(hour: hour, minute: minute)
    }
}

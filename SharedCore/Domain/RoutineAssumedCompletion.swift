import Foundation

enum RoutineAssumedCompletion {
    struct ScheduledBlockCompletionTiming: Equatable, Sendable {
        let completedAt: Date
        let actualDurationMinutes: Int
    }

    static let defaultDoneTimeOfDay = RoutineTimeOfDay(hour: 12, minute: 0)
    static let flagRuleAvailabilitySummary = "Available for scheduled daily, weekly, monthly, or yearly routines with one occurrence per day; eligible multi-day After done routines; and one-time tasks with one date and a Time block."

    static func isEligible(_ task: RoutineTask) -> Bool {
        task.autoAssumeDailyDone
            && isEligible(
                scheduleMode: task.scheduleMode,
                recurrenceRule: task.recurrenceRule,
                recurrenceTimeRangeRole: task.recurrenceTimeRangeRole,
                availabilityStartDate: task.availabilityStartDate,
                availabilityEndDate: task.availabilityEndDate,
                isAllDay: task.isAllDay,
                trackingCadenceEnabled: task.trackingCadenceEnabled,
                hasSequentialSteps: task.hasSequentialSteps,
                hasChecklistItems: task.hasChecklistItems
            )
    }

    static func isEligible(
        scheduleMode: RoutineScheduleMode,
        recurrenceRule: RoutineRecurrenceRule,
        recurrenceTimeRangeRole: RoutineTimeRangeRole = .availability,
        availabilityStartDate: Date? = nil,
        availabilityEndDate: Date? = nil,
        isAllDay: Bool = false,
        trackingCadenceEnabled: Bool = true,
        hasSequentialSteps: Bool,
        hasChecklistItems: Bool
    ) -> Bool {
        if scheduleMode == .oneOff {
            return availabilityStartDate != nil
                && availabilityEndDate == nil
                && !isAllDay
                && recurrenceRule.timeRange != nil
                && recurrenceTimeRangeRole == .scheduledBlock
                && !hasSequentialSteps
                && !hasChecklistItems
        }

        guard scheduleMode.usesRoutineCadence,
              trackingCadenceEnabled,
              !hasSequentialSteps,
              supportsAssumedCompletion(
                recurrenceRule,
                scheduleMode: scheduleMode
              )
        else {
            return false
        }

        if scheduleMode.routineFormat == .standard {
            return !hasChecklistItems
        }

        return scheduleMode.isChecklistCompletionMode && hasChecklistItems
    }

    static func canEnable(
        scheduleMode: RoutineScheduleMode,
        recurrenceRule: RoutineRecurrenceRule,
        recurrenceTimeRangeRole: RoutineTimeRangeRole = .availability,
        availabilityStartDate: Date? = nil,
        availabilityEndDate: Date? = nil,
        isAllDay: Bool = false,
        trackingCadenceEnabled: Bool = true,
        hasSequentialSteps: Bool,
        hasChecklistItems: Bool
    ) -> Bool {
        guard isEligible(
            scheduleMode: scheduleMode,
            recurrenceRule: recurrenceRule,
            recurrenceTimeRangeRole: recurrenceTimeRangeRole,
            availabilityStartDate: availabilityStartDate,
            availabilityEndDate: availabilityEndDate,
            isAllDay: isAllDay,
            trackingCadenceEnabled: trackingCadenceEnabled,
            hasSequentialSteps: hasSequentialSteps,
            hasChecklistItems: hasChecklistItems
        ) else {
            return false
        }

        if scheduleMode == .oneOff {
            return true
        }

        return true
    }

    static func unavailableReason(
        scheduleMode: RoutineScheduleMode,
        recurrenceRule: RoutineRecurrenceRule,
        recurrenceTimeRangeRole: RoutineTimeRangeRole = .availability,
        availabilityStartDate: Date? = nil,
        availabilityEndDate: Date? = nil,
        isAllDay: Bool = false,
        trackingCadenceEnabled: Bool = true,
        hasSequentialSteps: Bool,
        hasChecklistItems: Bool
    ) -> String? {
        guard !canEnable(
            scheduleMode: scheduleMode,
            recurrenceRule: recurrenceRule,
            recurrenceTimeRangeRole: recurrenceTimeRangeRole,
            availabilityStartDate: availabilityStartDate,
            availabilityEndDate: availabilityEndDate,
            isAllDay: isAllDay,
            trackingCadenceEnabled: trackingCadenceEnabled,
            hasSequentialSteps: hasSequentialSteps,
            hasChecklistItems: hasChecklistItems
        ) else {
            return nil
        }

        if hasSequentialSteps {
            return "It is not available for tasks with steps."
        }
        if scheduleMode.routineFormat == .standard, hasChecklistItems {
            return "It is not available for Standard routines with checklist items."
        }
        if scheduleMode.isChecklistCompletionMode, !hasChecklistItems {
            return "Checklist-completion routines need checklist items first."
        }
        if scheduleMode == .oneOff {
            return "Use exactly one availability date and a Time block."
        }
        if !scheduleMode.usesRoutineCadence || !trackingCadenceEnabled {
            return "Add a supported repeating schedule."
        }
        if recurrenceRule.advanced?.occursMoreThanOncePerDay == true {
            return "Use a schedule with at most one occurrence per day."
        }
        if scheduleMode.scheduleBehavior != .soft,
           scheduleMode.taskType != .record,
           !supportsRollingAfterCompletionAssumption(
                recurrenceRule,
                scheduleMode: scheduleMode
           ) {
            return "Only eligible multi-day After done Standard routines can use it."
        }
        return "This schedule does not support auto-assume done."
    }

    static func isAssumedDone(
        for task: RoutineTask,
        on day: Date,
        referenceDate: Date = Date(),
        logs: [RoutineLog] = [],
        calendar: Calendar = .current
    ) -> Bool {
        guard isEligible(task) else { return false }

        let selectedDay = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: referenceDate)
        guard selectedDay <= today else { return false }

        guard hasScheduledOccurrence(for: task, on: selectedDay, calendar: calendar) else {
            return false
        }

        if let createdAt = task.createdAt {
            let createdDay = calendar.startOfDay(for: createdAt)
            guard selectedDay >= createdDay else { return false }
        }

        if task.isPaused(referenceDate: selectedDay) {
            return false
        }

        if selectedDay == today,
           task.isArchived(referenceDate: referenceDate, calendar: calendar) {
            return false
        }

        if hasRecordedCompletion(for: task, on: selectedDay, logs: logs, calendar: calendar) {
            return false
        }

        if hasRecordedCancellation(for: task, on: selectedDay, logs: logs, calendar: calendar) {
            return false
        }

        if hasRecordedMiss(for: task, on: selectedDay, logs: logs, calendar: calendar) {
            return false
        }

        if task.isChecklistInProgress(referenceDate: selectedDay, calendar: calendar) {
            return false
        }

        if selectedDay == today {
            return referenceDate >= availableAt(for: task, on: selectedDay, calendar: calendar)
        }

        return true
    }

    static func assumedDates(
        for task: RoutineTask,
        through referenceDate: Date = Date(),
        logs: [RoutineLog] = [],
        includeToday: Bool = true,
        calendar: Calendar = .current
    ) -> [Date] {
        guard isEligible(task) else { return [] }

        if task.isOneOffTask {
            guard let occurrenceDay = task.availabilityStartDate,
                  isAssumedDone(
                    for: task,
                    on: occurrenceDay,
                    referenceDate: referenceDate,
                    logs: logs,
                    calendar: calendar
                  )
            else {
                return []
            }
            return [calendar.startOfDay(for: occurrenceDay)]
        }

        let today = calendar.startOfDay(for: referenceDate)
        let endDay: Date
        if includeToday {
            endDay = today
        } else if let previousDay = calendar.date(byAdding: .day, value: -1, to: today) {
            endDay = previousDay
        } else {
            return []
        }

        let firstCandidate: Date
        if let rollingAssumptionStartDay = rollingAssumptionStartDay(
            for: task,
            calendar: calendar
        ) {
            firstCandidate = rollingAssumptionStartDay
        } else {
            firstCandidate = calendar.startOfDay(
                for: task.createdAt ?? task.scheduleAnchor ?? task.lastDone ?? referenceDate
            )
        }
        guard firstCandidate <= endDay else { return [] }

        var dates: [Date] = []
        var current = firstCandidate

        while current <= endDay {
            if isAssumedDone(
                for: task,
                on: current,
                referenceDate: referenceDate,
                logs: logs,
                calendar: calendar
            ) {
                dates.append(current)
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else {
                break
            }
            current = next
        }

        return dates
    }

    static func pastAssumedDates(
        for task: RoutineTask,
        referenceDate: Date = Date(),
        logs: [RoutineLog] = [],
        calendar: Calendar = .current
    ) -> [Date] {
        assumedDates(
            for: task,
            through: referenceDate,
            logs: logs,
            includeToday: false,
            calendar: calendar
        )
    }

    static func completionTimestamp(
        for day: Date,
        timeOfDay: RoutineTimeOfDay? = nil,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        if calendar.isDate(day, inSameDayAs: referenceDate) {
            return referenceDate
        }

        return (timeOfDay ?? defaultDoneTimeOfDay).date(on: day, calendar: calendar)
    }

    static func completionTimestamp(
        for task: RoutineTask,
        on day: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        completionTimestamp(
            for: day,
            timeOfDay: task.autoAssumeDoneTimeOfDay,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    /// Resolves the concrete interval that an eligible one-off assumed completion
    /// represents when the user confirms it.
    static func scheduledBlockCompletionTiming(
        for task: RoutineTask,
        on day: Date,
        calendar: Calendar = .current
    ) -> ScheduledBlockCompletionTiming? {
        guard task.isOneOffTask,
              isEligible(task),
              let availabilityStartDate = task.availabilityStartDate,
              task.availabilityEndDate == nil,
              calendar.isDate(availabilityStartDate, inSameDayAs: day),
              let timeRange = task.recurrenceRule.timeRange
        else {
            return nil
        }

        let startsAt = timeRange.startDate(on: availabilityStartDate, calendar: calendar)
        let completedAt = timeRange.endDate(on: availabilityStartDate, calendar: calendar)
        let actualDurationMinutes = calendar.dateComponents(
            [.minute],
            from: startsAt,
            to: completedAt
        ).minute ?? 0
        guard actualDurationMinutes > 0 else { return nil }

        return ScheduledBlockCompletionTiming(
            completedAt: completedAt,
            actualDurationMinutes: actualDurationMinutes
        )
    }

    static func currentOccurrenceDay(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date {
        let today = calendar.startOfDay(for: referenceDate)
        guard let timeRange = task.recurrenceRule.timeRange,
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

    static func requiresIndividualAssumedCompletionConfirmation(
        for task: RoutineTask
    ) -> Bool {
        task.scheduleMode.usesRoutineCadence
            && task.scheduleMode.routineFormat == .standard
            && task.recurrenceRule.kind == .intervalDays
            && task.recurrenceRule.interval > 1
    }

    private static func availableAt(
        for task: RoutineTask,
        on day: Date,
        calendar: Calendar
    ) -> Date {
        if task.recurrenceRule.advanced != nil,
           let firstOccurrence = RoutineDateMath.scheduledOccurrences(
                for: task,
                on: day,
                calendar: calendar
           ).min() {
            return firstOccurrence
        }
        if let timeRange = task.recurrenceRule.timeRange {
            return timeRange.startDate(on: day, calendar: calendar)
        }
        if let timeOfDay = task.recurrenceRule.timeOfDay {
            return timeOfDay.date(on: day, calendar: calendar)
        }
        switch task.recurrenceRule.kind {
        case .dailyTime:
            return calendar.startOfDay(for: day)
        case .intervalDays, .weekly, .monthlyDay:
            return calendar.startOfDay(for: day)
        }
    }

    private static func supportsAssumedCompletion(
        _ recurrenceRule: RoutineRecurrenceRule,
        scheduleMode: RoutineScheduleMode
    ) -> Bool {
        guard recurrenceRule.advanced?.occursMoreThanOncePerDay != true else {
            return false
        }
        return recurrenceRule.isDaily
            || recurrenceRule.isFixedCalendar
            || supportsRollingAfterCompletionAssumption(
                recurrenceRule,
                scheduleMode: scheduleMode
            )
    }

    private static func supportsRollingAfterCompletionAssumption(
        _ recurrenceRule: RoutineRecurrenceRule,
        scheduleMode: RoutineScheduleMode
    ) -> Bool {
        scheduleMode.routineFormat == .standard
            && recurrenceRule.kind == .intervalDays
            && recurrenceRule.interval > 1
    }

    private static func hasScheduledOccurrence(
        for task: RoutineTask,
        on day: Date,
        calendar: Calendar
    ) -> Bool {
        if task.isOneOffTask {
            guard let availabilityStartDate = task.availabilityStartDate,
                  task.availabilityEndDate == nil else {
                return false
            }
            return calendar.isDate(availabilityStartDate, inSameDayAs: day)
        }

        let recurrenceRule = task.recurrenceRule
        if recurrenceRule.advanced != nil {
            return !RoutineDateMath.scheduledOccurrences(
                for: task,
                on: day,
                calendar: calendar
            ).isEmpty
        }

        switch recurrenceRule.kind {
        case .intervalDays:
            guard let rollingAssumptionStartDay = rollingAssumptionStartDay(
                for: task,
                calendar: calendar
            ) else {
                return recurrenceRule.isDaily
            }
            return day >= rollingAssumptionStartDay
        case .dailyTime:
            return true
        case .weekly, .monthlyDay:
            return RoutineDateMath.isFixedCalendarOccurrence(
                for: recurrenceRule,
                on: day,
                calendar: calendar
            )
        }
    }

    private static func rollingAssumptionStartDay(
        for task: RoutineTask,
        calendar: Calendar
    ) -> Date? {
        guard task.scheduleMode.usesRoutineCadence,
              task.scheduleMode.routineFormat == .standard,
              task.recurrenceRule.kind == .intervalDays,
              task.recurrenceRule.interval > 1
        else {
            return nil
        }

        let anchor = task.lastDone ?? task.scheduleAnchor ?? task.createdAt
        guard let anchor else { return nil }
        return calendar.date(
            byAdding: .day,
            value: max(task.recurrenceRule.interval, 1),
            to: calendar.startOfDay(for: anchor)
        )
    }

    private static func hasRecordedCompletion(
        for task: RoutineTask,
        on day: Date,
        logs: [RoutineLog],
        calendar: Calendar
    ) -> Bool {
        if let lastDone = task.lastDone,
           isRecordedDate(lastDone, for: task, on: day, calendar: calendar) {
            return true
        }

        return logs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind.resolvesDoneDate
                && isRecordedDate(timestamp, for: task, on: day, calendar: calendar)
        }
    }

    private static func hasRecordedCancellation(
        for task: RoutineTask,
        on day: Date,
        logs: [RoutineLog],
        calendar: Calendar
    ) -> Bool {
        if let canceledAt = task.canceledAt,
           isRecordedDate(canceledAt, for: task, on: day, calendar: calendar) {
            return true
        }

        return logs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind == .canceled
                && isRecordedDate(timestamp, for: task, on: day, calendar: calendar)
        }
    }

    private static func hasRecordedMiss(
        for task: RoutineTask,
        on day: Date,
        logs: [RoutineLog],
        calendar: Calendar
    ) -> Bool {
        logs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind == .missed
                && isRecordedDate(timestamp, for: task, on: day, calendar: calendar)
        }
    }

    private static func isRecordedDate(
        _ date: Date,
        for task: RoutineTask,
        on day: Date,
        calendar: Calendar
    ) -> Bool {
        if let displayDay = RoutineDateMath.completionDisplayDay(
            for: task,
            completionDate: date,
            calendar: calendar
        ) {
            return calendar.isDate(displayDay, inSameDayAs: day)
        }
        return calendar.isDate(date, inSameDayAs: day)
    }
}

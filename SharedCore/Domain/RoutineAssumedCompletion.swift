import Foundation

enum RoutineAssumedCompletion {
    static let defaultDoneTimeOfDay = RoutineTimeOfDay(hour: 12, minute: 0)

    static func isEligible(_ task: RoutineTask) -> Bool {
        task.autoAssumeDailyDone
            && isEligible(
                scheduleMode: task.scheduleMode,
                recurrenceRule: task.recurrenceRule,
                hasSequentialSteps: task.hasSequentialSteps,
                hasChecklistItems: task.hasChecklistItems
            )
    }

    static func isEligible(
        scheduleMode: RoutineScheduleMode,
        recurrenceRule: RoutineRecurrenceRule,
        hasSequentialSteps: Bool,
        hasChecklistItems: Bool
    ) -> Bool {
        guard scheduleMode.taskType == .routine,
              !hasSequentialSteps,
              recurrenceRule.isDaily
        else {
            return false
        }

        if scheduleMode.isStandardRoutineMode {
            return !hasChecklistItems
        }

        return scheduleMode.isChecklistCompletionMode && hasChecklistItems
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

        if let createdAt = task.createdAt {
            let createdDay = calendar.startOfDay(for: createdAt)
            guard selectedDay >= createdDay else { return false }
        }

        if let pausedAt = task.pausedAt,
           selectedDay >= calendar.startOfDay(for: pausedAt) {
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

        let today = calendar.startOfDay(for: referenceDate)
        let endDay: Date
        if includeToday {
            endDay = today
        } else if let previousDay = calendar.date(byAdding: .day, value: -1, to: today) {
            endDay = previousDay
        } else {
            return []
        }

        let firstCandidate = calendar.startOfDay(
            for: task.createdAt ?? task.scheduleAnchor ?? task.lastDone ?? referenceDate
        )
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

    private static func availableAt(
        for task: RoutineTask,
        on day: Date,
        calendar: Calendar
    ) -> Date {
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
            return log.kind == .completed
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

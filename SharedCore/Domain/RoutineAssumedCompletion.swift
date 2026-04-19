import Foundation

enum RoutineAssumedCompletion {
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
        scheduleMode == .fixedInterval
            && !hasSequentialSteps
            && !hasChecklistItems
            && recurrenceRule.isDaily
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
            if selectedDay == createdDay,
               createdAt > availableAt(for: task, on: selectedDay, calendar: calendar) {
                return false
            }
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
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        if calendar.isDate(day, inSameDayAs: referenceDate) {
            return referenceDate
        }

        let dayStart = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart) ?? dayStart
    }

    private static func availableAt(
        for task: RoutineTask,
        on day: Date,
        calendar: Calendar
    ) -> Date {
        switch task.recurrenceRule.kind {
        case .dailyTime:
            return (task.recurrenceRule.timeOfDay ?? .defaultValue).date(on: day, calendar: calendar)
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
           calendar.isDate(lastDone, inSameDayAs: day) {
            return true
        }

        return logs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind == .completed && calendar.isDate(timestamp, inSameDayAs: day)
        }
    }

    private static func hasRecordedCancellation(
        for task: RoutineTask,
        on day: Date,
        logs: [RoutineLog],
        calendar: Calendar
    ) -> Bool {
        if let canceledAt = task.canceledAt,
           calendar.isDate(canceledAt, inSameDayAs: day) {
            return true
        }

        return logs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind == .canceled && calendar.isDate(timestamp, inSameDayAs: day)
        }
    }
}

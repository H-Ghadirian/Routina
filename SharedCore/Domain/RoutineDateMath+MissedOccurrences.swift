import Foundation

extension RoutineDateMath {
    static func missedExactTimedOccurrenceDate(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        missedExactTimedOccurrenceDates(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        .first
    }

    static func isScheduledOccurrenceMissed(
        _ occurrence: Date,
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard usesExactTimedOccurrences(for: task) else { return false }
        guard
            scheduledOccurrences(for: task, on: occurrence, calendar: calendar).contains(where: {
                RoutineOccurrenceIdentity.matches(
                    $0,
                    occurrence,
                    for: task,
                    calendar: calendar
                )
            })
        else {
            return false
        }
        return isExactTimedOccurrenceMissed(
            occurrence,
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    static func missedExactTimedOccurrenceDates(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        guard usesExactTimedOccurrences(for: task) else { return [] }
        var dates: [Date] = []
        var candidate = dueDate(for: task, referenceDate: referenceDate, calendar: calendar)

        for _ in 0..<10_000 {
            guard
                isExactTimedOccurrenceMissed(
                    candidate,
                    for: task,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            else {
                return dates
            }
            dates.append(candidate)
            let nextCandidate = nextExactTimedOccurrence(after: candidate, for: task, calendar: calendar)
            guard nextCandidate > candidate else { return dates }
            candidate = nextCandidate
        }

        return dates
    }

    static func isExactTimedMissedOccurrenceAcknowledged(
        for task: RoutineTask,
        missedDate: Date,
        logs: [RoutineLog],
        calendar: Calendar = .current
    ) -> Bool {
        guard usesExactTimedOccurrences(for: task) else { return false }
        return logs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            guard log.kind == .missed || log.kind.resolvesDoneDate || log.kind == .canceled else { return false }
            return RoutineOccurrenceIdentity.matches(
                timestamp,
                missedDate,
                for: task,
                calendar: calendar
            )
        }
    }

    static func unresolvedMissedExactTimedOccurrenceDate(
        for task: RoutineTask,
        referenceDate: Date,
        logs: [RoutineLog],
        calendar: Calendar = .current
    ) -> Date? {
        unresolvedMissedExactTimedOccurrenceDates(
            for: task,
            referenceDate: referenceDate,
            logs: logs,
            calendar: calendar
        )
        .first
    }

    static func unresolvedMissedExactTimedOccurrenceDates(
        for task: RoutineTask,
        referenceDate: Date,
        logs: [RoutineLog],
        calendar: Calendar = .current
    ) -> [Date] {
        unresolvedMissedExactTimedOccurrenceDates(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        ) { missedDate in
            isExactTimedMissedOccurrenceAcknowledged(
                for: task,
                missedDate: missedDate,
                logs: logs,
                calendar: calendar
            )
        }
    }

    static func unresolvedMissedExactTimedOccurrenceDates(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current,
        isAcknowledged: (Date) -> Bool
    ) -> [Date] {
        mergedMissedExactTimedOccurrenceDates(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        .filter { missedDate in
            !isExactTimedMissedOccurrenceAcknowledgedByTaskState(
                for: task,
                missedDate: missedDate,
                calendar: calendar
            )
                && !isAcknowledged(missedDate)
        }
    }

    static func nextDueDateAfterMissedExactTimedOccurrence(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard
            let missedDate = missedExactTimedOccurrenceDates(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ).last
        else {
            return nil
        }

        return nextExactTimedOccurrence(after: missedDate, for: task, calendar: calendar)
    }

    private static func mergedMissedExactTimedOccurrenceDates(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> [Date] {
        var dates: [Date] = []
        for missedDate in historicalMissedExactTimedOccurrenceDates(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            appendUnique(missedDate, to: &dates, for: task, calendar: calendar)
        }
        for missedDate in missedExactTimedOccurrenceDates(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            appendUnique(missedDate, to: &dates, for: task, calendar: calendar)
        }
        return dates.sorted()
    }

    private static func historicalMissedExactTimedOccurrenceDates(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> [Date] {
        guard usesExactTimedOccurrences(for: task) else { return [] }
        var dates: [Date] = []
        var candidate = firstHistoricalExactTimedOccurrence(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )

        for _ in 0..<10_000 {
            guard
                isExactTimedOccurrenceMissed(
                    candidate,
                    for: task,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            else {
                return dates
            }
            dates.append(candidate)
            let nextCandidate = nextExactTimedOccurrence(after: candidate, for: task, calendar: calendar)
            guard nextCandidate > candidate else { return dates }
            candidate = nextCandidate
        }

        return dates
    }

    private static func firstHistoricalExactTimedOccurrence(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> Date {
        let base = task.scheduleAnchor ?? task.createdAt ?? task.lastDone ?? referenceDate
        if let advanced = task.recurrenceRule.advanced {
            return nextAdvancedEffectiveOccurrence(
                for: advanced,
                after: historicalAdvancedSearchThreshold(
                    from: base,
                    advanced: advanced,
                    timeRange: task.recurrenceRule.timeRange,
                    calendar: calendar
                ),
                timeRange: task.recurrenceRule.timeRange,
                calendar: calendar
            ) ?? .distantFuture
        }
        let timeOfDay = scheduledTimeOfDay(for: task.recurrenceRule) ?? RoutineTimeOfDay(hour: 0, minute: 0)

        switch task.recurrenceRule.kind {
        case .intervalDays:
            let firstDueDate =
                calendar.date(
                    byAdding: .day,
                    value: max(task.recurrenceRule.interval, 1),
                    to: base
                ) ?? base
            return timeOfDay.date(on: firstDueDate, calendar: calendar)

        case .dailyTime:
            let searchBase: Date
            if let timeRange = task.recurrenceRule.timeRange,
                !timeRange.contains(base, calendar: calendar),
                base >= timeRange.endDate(on: base, calendar: calendar)
            {
                searchBase = base
            } else {
                searchBase = calendar.startOfDay(for: base)
            }
            return nextDailyOccurrence(
                after: searchBase,
                timeOfDay: timeOfDay,
                includeCurrentDate: true,
                calendar: calendar
            )

        case .weekly:
            let weekdays = task.recurrenceRule.resolvedWeekdays(calendar: calendar)
            let searchBase: Date
            if isWeeklyOccurrenceDay(base, weekdays: weekdays, calendar: calendar) {
                if let timeRange = task.recurrenceRule.timeRange,
                    !timeRange.contains(base, calendar: calendar),
                    base >= timeRange.endDate(on: base, calendar: calendar)
                {
                    searchBase = base
                } else {
                    searchBase = calendar.startOfDay(for: base)
                }
            } else {
                searchBase = base
            }
            return nextWeeklyOccurrence(
                after: searchBase,
                weekdays: weekdays,
                timeOfDay: timeOfDay,
                includeCurrentDate: true,
                calendar: calendar
            )

        case .monthlyDay:
            let daysOfMonth = task.recurrenceRule.resolvedDaysOfMonth(calendar: calendar)
            let searchBase: Date
            if isMonthlyOccurrenceDay(base, daysOfMonth: daysOfMonth, calendar: calendar) {
                if let timeRange = task.recurrenceRule.timeRange,
                    !timeRange.contains(base, calendar: calendar),
                    base >= timeRange.endDate(on: base, calendar: calendar)
                {
                    searchBase = base
                } else {
                    searchBase = calendar.startOfDay(for: base)
                }
            } else {
                searchBase = base
            }
            return nextMonthlyOccurrence(
                after: searchBase,
                daysOfMonth: daysOfMonth,
                timeOfDay: timeOfDay,
                includeCurrentDate: true,
                calendar: calendar
            )
        }
    }

    private static func appendUnique(
        _ date: Date,
        to dates: inout [Date],
        for task: RoutineTask,
        calendar: Calendar
    ) {
        guard
            !dates.contains(where: {
                RoutineOccurrenceIdentity.matches($0, date, for: task, calendar: calendar)
            })
        else { return }
        dates.append(date)
    }

    private static func isExactTimedMissedOccurrenceAcknowledgedByTaskState(
        for task: RoutineTask,
        missedDate: Date,
        calendar: Calendar
    ) -> Bool {
        if let lastDone = task.lastDone,
            RoutineOccurrenceIdentity.matches(lastDone, missedDate, for: task, calendar: calendar)
        {
            return true
        }
        if let canceledAt = task.canceledAt,
            RoutineOccurrenceIdentity.matches(canceledAt, missedDate, for: task, calendar: calendar)
        {
            return true
        }
        return false
    }

    static func isExactTimedOccurrenceMissed(
        _ occurrence: Date,
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        if let timeRange = task.recurrenceRule.timeRange {
            let occurrenceCalendar = advancedCalendar(
                for: task.recurrenceRule.advanced,
                input: calendar
            )
            let windowEnd = timeRange.endDate(on: occurrence, calendar: occurrenceCalendar)
            return referenceDate >= windowEnd
        }
        return calendar.startOfDay(for: occurrence) < calendar.startOfDay(for: referenceDate)
    }

    static func nextExactTimedOccurrence(
        after occurrence: Date,
        for task: RoutineTask,
        calendar: Calendar
    ) -> Date {
        if let advanced = task.recurrenceRule.advanced {
            return nextAdvancedEffectiveOccurrence(
                for: advanced,
                after: occurrence,
                timeRange: task.recurrenceRule.timeRange,
                calendar: calendar
            ) ?? occurrence
        }

        switch task.recurrenceRule.kind {
        case .dailyTime:
            return nextDailyOccurrence(
                after: occurrence,
                timeOfDay: scheduledTimeOfDay(for: task.recurrenceRule) ?? RoutineTimeOfDay(hour: 0, minute: 0),
                includeCurrentDate: false,
                calendar: calendar
            )

        case .weekly:
            return nextWeeklyOccurrence(
                after: occurrence,
                weekdays: task.recurrenceRule.resolvedWeekdays(calendar: calendar),
                timeOfDay: scheduledTimeOfDay(for: task.recurrenceRule),
                includeCurrentDate: false,
                calendar: calendar
            )

        case .monthlyDay:
            return nextMonthlyOccurrence(
                after: occurrence,
                daysOfMonth: task.recurrenceRule.resolvedDaysOfMonth(calendar: calendar),
                timeOfDay: scheduledTimeOfDay(for: task.recurrenceRule),
                includeCurrentDate: false,
                calendar: calendar
            )

        case .intervalDays:
            let nextDate =
                calendar.date(
                    byAdding: .day,
                    value: max(task.recurrenceRule.interval, 1),
                    to: occurrence
                ) ?? occurrence
            if let timeOfDay = scheduledTimeOfDay(for: task.recurrenceRule) {
                return timeOfDay.date(on: nextDate, calendar: calendar)
            }
            return nextDate
        }
    }
}

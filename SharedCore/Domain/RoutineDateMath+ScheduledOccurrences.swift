import Foundation

extension RoutineDateMath {
    static func scheduledOccurrence(
        for task: RoutineTask,
        on day: Date,
        calendar: Calendar = .current
    ) -> Date? {
        scheduledOccurrences(for: task, on: day, calendar: calendar).first
    }

    static func isFixedCalendarOccurrence(
        for recurrenceRule: RoutineRecurrenceRule,
        on day: Date,
        calendar: Calendar = .current
    ) -> Bool {
        switch recurrenceRule.kind {
        case .weekly, .monthlyDay:
            break
        case .intervalDays, .dailyTime:
            return false
        }

        if let advanced = recurrenceRule.advanced {
            let occurrenceCalendar = advancedCalendar(for: advanced, input: calendar)
            let startOfDay = occurrenceCalendar.startOfDay(for: day)
            guard
                let endOfDay = occurrenceCalendar.date(
                    byAdding: .day,
                    value: 1,
                    to: startOfDay
                )
            else {
                return false
            }
            let occurrence = RoutineAdvancedRecurrenceGenerator.nextOccurrence(
                for: advanced,
                after: startOfDay.addingTimeInterval(-0.001),
                calendar: occurrenceCalendar
            )
            return occurrence.map { $0 < endOfDay } ?? false
        }

        let normalizedDay = calendar.startOfDay(for: day)
        switch recurrenceRule.kind {
        case .weekly:
            return recurrenceRule.resolvedWeekdays(calendar: calendar)
                .contains(calendar.component(.weekday, from: normalizedDay))

        case .monthlyDay:
            let dayCount = calendar.range(of: .day, in: .month, for: normalizedDay)?.count ?? 31
            let scheduledDays = recurrenceRule.resolvedDaysOfMonth(calendar: calendar)
                .map { min(max($0, 1), dayCount) }
            return scheduledDays.contains(calendar.component(.day, from: normalizedDay))

        case .intervalDays, .dailyTime:
            return false
        }
    }

    static func scheduledOccurrences(
        for task: RoutineTask,
        on day: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        if let advanced = task.recurrenceRule.advanced {
            let occurrenceCalendar = advancedCalendar(for: advanced, input: calendar)
            let startOfDay = occurrenceCalendar.startOfDay(for: day)
            guard let endOfDay = occurrenceCalendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                return []
            }
            var occurrences: [Date] = []
            var threshold = startOfDay.addingTimeInterval(-0.001)

            for _ in 0..<10_000 {
                guard
                    let occurrence = RoutineAdvancedRecurrenceGenerator.nextOccurrence(
                        for: advanced,
                        after: threshold,
                        calendar: occurrenceCalendar
                    ), occurrence < endOfDay
                else {
                    break
                }
                occurrences.append(
                    availabilityAdjustedAdvancedOccurrence(
                        occurrence,
                        advanced: advanced,
                        timeRange: task.recurrenceRule.timeRange,
                        calendar: occurrenceCalendar
                    ))
                guard occurrence > threshold else { break }
                threshold = occurrence
            }
            return occurrences
        }

        guard usesExactTimedOccurrences(for: task) else { return [] }
        guard let timeOfDay = scheduledTimeOfDay(for: task.recurrenceRule) else { return [] }

        let startOfDay = calendar.startOfDay(for: day)

        switch task.recurrenceRule.kind {
        case .dailyTime:
            return [timeOfDay.date(on: startOfDay, calendar: calendar)]

        case .weekly:
            guard
                task.recurrenceRule.resolvedWeekdays(calendar: calendar)
                    .contains(calendar.component(.weekday, from: startOfDay))
            else { return [] }
            return [timeOfDay.date(on: startOfDay, calendar: calendar)]

        case .monthlyDay:
            let scheduledDays = task.recurrenceRule.resolvedDaysOfMonth(calendar: calendar).map {
                clampedDayOfMonth($0, monthContaining: startOfDay, calendar: calendar)
            }
            guard scheduledDays.contains(calendar.component(.day, from: startOfDay)) else { return [] }
            return [timeOfDay.date(on: startOfDay, calendar: calendar)]

        case .intervalDays:
            guard
                let occurrence = intervalOccurrence(
                    for: task,
                    on: startOfDay,
                    timeOfDay: timeOfDay,
                    calendar: calendar
                )
            else {
                return []
            }
            return [occurrence]
        }
    }

    static func completionTargetDate(
        for task: RoutineTask,
        selectedDay: Date,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        if usesExactTimedOccurrences(for: task) {
            let normalizedSelectedDay = calendar.startOfDay(for: selectedDay)
            if calendar.isDate(normalizedSelectedDay, inSameDayAs: referenceDate) {
                if let activeOccurrence = activeScheduledWindowOccurrence(
                    for: task,
                    referenceDate: referenceDate,
                    calendar: calendar
                ) {
                    return activeOccurrence
                }
                return scheduledOccurrences(
                    for: task,
                    on: normalizedSelectedDay,
                    calendar: calendar
                )
                .last(where: { $0 <= referenceDate })
            }

            return scheduledOccurrence(for: task, on: normalizedSelectedDay, calendar: calendar)
        }

        if task.recurrenceRule.usesAdvancedModel {
            let due = dueDate(for: task, referenceDate: referenceDate, calendar: calendar)
            guard due != .distantFuture, due <= referenceDate else {
                return nil
            }
            if calendar.isDate(selectedDay, inSameDayAs: referenceDate) {
                return due
            }
            return calendar.isDate(due, inSameDayAs: selectedDay) ? due : nil
        }

        return nil
    }

    static func completionDisplayDay(
        for task: RoutineTask,
        completionDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let completionDay = calendar.startOfDay(for: completionDate)
        guard usesExactTimedOccurrences(for: task) else {
            return completionDay
        }

        if task.recurrenceRule.advanced == nil,
            task.recurrenceRule.kind == .intervalDays
        {
            return intervalCompletionDisplayDay(
                for: task,
                completionDate: completionDate,
                calendar: calendar
            )
        }

        var candidateDays = [completionDay]
        if let previousDay = calendar.date(byAdding: .day, value: -1, to: completionDay) {
            candidateDays.append(previousDay)
        }

        var sameDayWindowFallback: Date?
        for candidateDay in candidateDays {
            guard let occurrence = scheduledOccurrence(for: task, on: candidateDay, calendar: calendar) else {
                continue
            }

            if let timeRange = task.recurrenceRule.timeRange {
                let windowEnd = timeRange.endDate(on: occurrence, calendar: calendar)
                if completionDate >= occurrence && completionDate < windowEnd {
                    return candidateDay
                }
                if calendar.isDate(candidateDay, inSameDayAs: completionDay) {
                    sameDayWindowFallback = candidateDay
                }
            } else if calendar.isDate(completionDate, inSameDayAs: occurrence) {
                return candidateDay
            }
        }

        if let sameDayWindowFallback {
            return sameDayWindowFallback
        }

        return nil
    }

    private static func intervalCompletionDisplayDay(
        for task: RoutineTask,
        completionDate: Date,
        calendar: Calendar
    ) -> Date {
        let completionDay = calendar.startOfDay(for: completionDate)
        guard let timeRange = task.recurrenceRule.timeRange,
            timeRange.isOvernight,
            let previousDay = calendar.date(byAdding: .day, value: -1, to: completionDay)
        else {
            return completionDay
        }

        let previousOccurrence = timeRange.startDate(on: previousDay, calendar: calendar)
        let previousWindowEnd = timeRange.endDate(on: previousOccurrence, calendar: calendar)
        if completionDate >= previousOccurrence && completionDate < previousWindowEnd {
            return previousDay
        }
        return completionDay
    }

    static func activeScheduledWindowOccurrence(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> Date? {
        guard let timeRange = task.recurrenceRule.timeRange else { return nil }
        let occurrenceCalendar = advancedCalendar(
            for: task.recurrenceRule.advanced,
            input: calendar
        )
        let referenceDay = occurrenceCalendar.startOfDay(for: referenceDate)
        var candidateDays = [referenceDay]
        if timeRange.isOvernight,
            let previousDay = occurrenceCalendar.date(byAdding: .day, value: -1, to: referenceDay)
        {
            candidateDays.append(previousDay)
        }

        if !RoutineOccurrenceIdentity.isTimestampScoped(for: task) {
            for candidateDay in candidateDays {
                guard
                    let occurrence = scheduledOccurrence(
                        for: task,
                        on: candidateDay,
                        calendar: occurrenceCalendar
                    )
                else {
                    continue
                }
                let windowEnd = timeRange.endDate(on: occurrence, calendar: occurrenceCalendar)
                if referenceDate >= occurrence, referenceDate < windowEnd {
                    return occurrence
                }
            }
            return nil
        }

        let due = dueDate(for: task, referenceDate: referenceDate, calendar: occurrenceCalendar)
        guard due != .distantFuture, due <= referenceDate else { return nil }

        for candidateDay in candidateDays {
            let scheduledOccurrences = scheduledOccurrences(
                for: task,
                on: candidateDay,
                calendar: occurrenceCalendar
            )
            guard
                scheduledOccurrences.contains(where: {
                    RoutineOccurrenceIdentity.matches($0, due, for: task, calendar: occurrenceCalendar)
                })
            else {
                continue
            }
            let windowStart = timeRange.startDate(on: candidateDay, calendar: occurrenceCalendar)
            let windowEnd = timeRange.endDate(on: candidateDay, calendar: occurrenceCalendar)
            if referenceDate >= windowStart, referenceDate < windowEnd {
                return due
            }
        }
        return nil
    }

    static func nextAdvancedEffectiveOccurrence(
        for advanced: RoutineAdvancedRecurrenceRule,
        after threshold: Date?,
        timeRange: RoutineTimeRange?,
        calendar: Calendar
    ) -> Date? {
        let effectiveThreshold =
            threshold
            ?? historicalAdvancedSearchThreshold(
                from: advanced.startDate,
                advanced: advanced,
                timeRange: timeRange,
                calendar: calendar
            )
        var generatorThreshold = threshold

        for _ in 0..<100_000 {
            guard
                let generated = RoutineAdvancedRecurrenceGenerator.nextOccurrence(
                    for: advanced,
                    after: generatorThreshold,
                    calendar: calendar
                )
            else {
                return nil
            }
            let effective = availabilityAdjustedAdvancedOccurrence(
                generated,
                advanced: advanced,
                timeRange: timeRange,
                calendar: calendar
            )
            if effective > effectiveThreshold {
                return effective
            }
            generatorThreshold = generated
        }
        return nil
    }

    private static func availabilityAdjustedAdvancedOccurrence(
        _ occurrence: Date,
        advanced: RoutineAdvancedRecurrenceRule,
        timeRange: RoutineTimeRange?,
        calendar: Calendar
    ) -> Date {
        guard let timeRange else { return occurrence }
        guard !advanced.occursMoreThanOncePerDay else { return occurrence }
        return timeRange.startDate(
            on: occurrence,
            calendar: advancedCalendar(for: advanced, input: calendar)
        )
    }

    static func nextAdvancedEffectiveOccurrence(
        for task: RoutineTask,
        after threshold: Date?,
        calendar: Calendar = .current
    ) -> Date? {
        guard let advanced = task.recurrenceRule.advanced else { return nil }
        return nextAdvancedEffectiveOccurrence(
            for: advanced,
            after: threshold,
            timeRange: task.recurrenceRule.timeRange,
            calendar: calendar
        )
    }

    static func historicalAdvancedSearchThreshold(
        from date: Date,
        advanced: RoutineAdvancedRecurrenceRule,
        timeRange: RoutineTimeRange?,
        calendar: Calendar
    ) -> Date {
        guard let timeRange else {
            return date.addingTimeInterval(-0.001)
        }
        let occurrenceCalendar = advancedCalendar(for: advanced, input: calendar)
        if !timeRange.isOvernight,
            date >= timeRange.endDate(on: date, calendar: occurrenceCalendar)
        {
            return date
        }
        return occurrenceCalendar.startOfDay(for: date).addingTimeInterval(-0.001)
    }

    static func advancedCalendar(
        for advanced: RoutineAdvancedRecurrenceRule?,
        input calendar: Calendar
    ) -> Calendar {
        guard let advanced,
            let timeZone = TimeZone(identifier: advanced.timeZoneIdentifier)
        else {
            return calendar
        }
        var resolved = calendar
        resolved.timeZone = timeZone
        return resolved
    }
}

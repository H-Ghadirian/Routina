import Foundation

enum RoutineDateMath {
    static func usesExactTimedOccurrences(for task: RoutineTask) -> Bool {
        let recurrenceRule = task.recurrenceRule
        let supportsExactOccurrences: Bool
        if let advanced = recurrenceRule.advanced {
            supportsExactOccurrences =
                advanced.frequency != .hourly
                && (recurrenceRule.timeRange != nil || !advanced.occursMoreThanOncePerDay)
        } else {
            supportsExactOccurrences = true
        }
        return task.usesEffectiveRoutineCadence
            && supportsExactOccurrences
            && recurrenceRule.usesTimeConstraint
            && !task.isChecklistDriven
    }

    static func dueDate(
        for item: RoutineChecklistItem,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date {
        let anchor = item.lastPurchasedAt ?? item.createdAt
        return calendar.date(
            byAdding: .day,
            value: RoutineChecklistItem.clampedIntervalDays(item.intervalDays),
            to: anchor
        ) ?? anchor
    }

    static func elapsedDaysSinceLastDone(
        from lastDone: Date?,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard let lastDone else { return 0 }
        let lastDoneStart = calendar.startOfDay(for: lastDone)
        let referenceStart = calendar.startOfDay(for: referenceDate)
        return calendar.dateComponents([.day], from: lastDoneStart, to: referenceStart).day ?? 0
    }

    static func effectiveScheduleAnchor(
        for task: RoutineTask,
        referenceDate: Date
    ) -> Date {
        task.scheduleAnchor ?? task.lastDone ?? referenceDate
    }

    static func dueDate(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date {
        if task.isOneOffTask {
            return task.deadline ?? referenceDate
        }

        guard task.usesEffectiveRoutineCadence else {
            return .distantFuture
        }

        if task.isChecklistDriven,
            let earliestChecklistDueDate = task.nextDueChecklistItem(referenceDate: referenceDate, calendar: calendar)
                .map({ dueDate(for: $0, referenceDate: referenceDate, calendar: calendar) })
        {
            return earliestChecklistDueDate
        }

        if let advanced = task.recurrenceRule.advanced {
            return nextAdvancedEffectiveOccurrence(
                for: advanced,
                after: task.lastSatisfiedScheduledOccurrenceAt ?? task.lastDone,
                timeRange: task.recurrenceRule.timeRange,
                calendar: calendar
            ) ?? .distantFuture
        }

        switch task.recurrenceRule.kind {
        case .intervalDays:
            let anchor = effectiveScheduleAnchor(for: task, referenceDate: referenceDate)
            let dueDate =
                calendar.date(
                    byAdding: .day,
                    value: max(task.recurrenceRule.interval, 1),
                    to: anchor
                ) ?? anchor
            if let timeOfDay = scheduledTimeOfDay(for: task.recurrenceRule) {
                return timeOfDay.date(on: dueDate, calendar: calendar)
            }
            return dueDate

        case .dailyTime:
            let reference = recurrenceReference(for: task, referenceDate: referenceDate)
            let base: Date
            if task.lastDone == nil, let timeRange = task.recurrenceRule.timeRange {
                base =
                    timeRange.contains(reference.base, calendar: calendar)
                    ? calendar.startOfDay(for: reference.base)
                    : reference.base
            } else if task.lastDone == nil {
                // For new tasks, search from start of day so today's occurrence is
                // found even if the task was created after the scheduled time.
                base = calendar.startOfDay(for: reference.base)
            } else {
                base = reference.base
            }
            return nextDailyOccurrence(
                after: base,
                timeOfDay: scheduledTimeOfDay(for: task.recurrenceRule) ?? RoutineTimeOfDay(hour: 0, minute: 0),
                includeCurrentDate: task.lastDone == nil || reference.includeCurrentDate,
                calendar: calendar
            )

        case .weekly:
            let reference = recurrenceReference(for: task, referenceDate: referenceDate)
            let timeOfDay = scheduledTimeOfDay(for: task.recurrenceRule)
            let base: Date
            if task.lastDone == nil,
                isWeeklyOccurrenceDay(
                    reference.base,
                    weekdays: task.recurrenceRule.resolvedWeekdays(calendar: calendar),
                    calendar: calendar
                )
            {
                // If a routine is created on its scheduled weekday, keep that day as
                // the first occurrence even when the creation time is later.
                if let timeRange = task.recurrenceRule.timeRange,
                    !timeRange.contains(reference.base, calendar: calendar),
                    reference.base >= timeRange.endDate(on: reference.base, calendar: calendar)
                {
                    base = reference.base
                } else {
                    base = calendar.startOfDay(for: reference.base)
                }
            } else {
                base = reference.base
            }
            return nextWeeklyOccurrence(
                after: base,
                weekdays: task.recurrenceRule.resolvedWeekdays(calendar: calendar),
                timeOfDay: timeOfDay,
                includeCurrentDate: task.lastDone == nil || reference.includeCurrentDate,
                calendar: calendar
            )

        case .monthlyDay:
            let reference = recurrenceReference(for: task, referenceDate: referenceDate)
            let timeOfDay = scheduledTimeOfDay(for: task.recurrenceRule)
            let base: Date
            if task.lastDone == nil,
                isMonthlyOccurrenceDay(
                    reference.base,
                    daysOfMonth: task.recurrenceRule.resolvedDaysOfMonth(calendar: calendar),
                    calendar: calendar
                )
            {
                // If a routine is created on its scheduled day-of-month, keep that day
                // as the first occurrence even when the creation time is later.
                if let timeRange = task.recurrenceRule.timeRange,
                    !timeRange.contains(reference.base, calendar: calendar),
                    reference.base >= timeRange.endDate(on: reference.base, calendar: calendar)
                {
                    base = reference.base
                } else {
                    base = calendar.startOfDay(for: reference.base)
                }
            } else {
                base = reference.base
            }
            return nextMonthlyOccurrence(
                after: base,
                daysOfMonth: task.recurrenceRule.resolvedDaysOfMonth(calendar: calendar),
                timeOfDay: timeOfDay,
                includeCurrentDate: task.lastDone == nil || reference.includeCurrentDate,
                calendar: calendar
            )
        }
    }

    static func upcomingDueDate(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date {
        if task.isOneOffTask {
            return dueDate(for: task, referenceDate: referenceDate, calendar: calendar)
        }
        guard task.usesEffectiveRoutineCadence else {
            return .distantFuture
        }
        if usesExactTimedOccurrences(for: task) {
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
                    return candidate
                }
                let nextCandidate = nextExactTimedOccurrence(after: candidate, for: task, calendar: calendar)
                guard nextCandidate > candidate else { return candidate }
                candidate = nextCandidate
            }
            return candidate
        }
        if task.recurrenceRule.usesAdvancedModel {
            return dueDate(for: task, referenceDate: referenceDate, calendar: calendar)
        }
        return dueDate(for: task, referenceDate: referenceDate, calendar: calendar)
    }

    static func daysUntilDue(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        if task.isSoftIntervalRoutine {
            return Int.max
        }
        if task.isOneOffTask {
            guard !task.isCompletedOneOff else { return Int.max }
            guard let targetDate = task.deadline else { return Int.max }
            let todayStart = calendar.startOfDay(for: referenceDate)
            let dueStart = calendar.startOfDay(for: targetDate)
            return calendar.dateComponents([.day], from: todayStart, to: dueStart).day ?? 0
        }
        guard task.usesEffectiveRoutineCadence else {
            return Int.max
        }
        let todayStart = calendar.startOfDay(for: referenceDate)
        let dueStart = calendar.startOfDay(for: upcomingDueDate(for: task, referenceDate: referenceDate, calendar: calendar))
        return calendar.dateComponents([.day], from: todayStart, to: dueStart).day ?? 0
    }

    static func overdueDays(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        if missedExactTimedOccurrenceDate(for: task, referenceDate: referenceDate, calendar: calendar) != nil {
            return 0
        }
        return max(-daysUntilDue(for: task, referenceDate: referenceDate, calendar: calendar), 0)
    }

    static func canMarkDone(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current,
        ignoreArchiveAtReferenceDate: Bool = false
    ) -> Bool {
        if !ignoreArchiveAtReferenceDate {
            guard !task.isArchived(referenceDate: referenceDate, calendar: calendar) else { return false }
        }

        if task.isOneOffTask {
            return !task.isCompletedOneOff
        }

        if !task.usesEffectiveRoutineCadence {
            return true
        }

        if task.isChecklistDriven {
            return !task.dueChecklistItems(referenceDate: referenceDate, calendar: calendar).isEmpty
        }

        if task.recurrenceRule.usesAdvancedModel {
            if usesExactTimedOccurrences(for: task),
                task.recurrenceRule.timeRange != nil
            {
                return activeScheduledWindowOccurrence(
                    for: task,
                    referenceDate: referenceDate,
                    calendar: calendar
                ) != nil
            }
            let due = dueDate(for: task, referenceDate: referenceDate, calendar: calendar)
            guard due != .distantFuture, due <= referenceDate else { return false }
            if let timeRange = task.recurrenceRule.timeRange {
                return timeRange.contains(
                    referenceDate,
                    calendar: advancedCalendar(for: task.recurrenceRule.advanced, input: calendar)
                )
            }
            return true
        }

        if !task.recurrenceRule.isFixedCalendar && !task.recurrenceRule.usesTimeConstraint {
            return true
        }
        if let missedDate = missedExactTimedOccurrenceDate(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            if task.recurrenceRule.usesTimeRange {
                return false
            }
            if !calendar.isDate(referenceDate, inSameDayAs: missedDate) {
                return false
            }
        }
        if let timeRange = task.recurrenceRule.timeRange,
            !timeRange.contains(referenceDate, calendar: calendar)
        {
            return false
        }
        return dueDate(for: task, referenceDate: referenceDate, calendar: calendar) <= referenceDate
    }

    static func supportsEarlyScheduledCompletion(for task: RoutineTask) -> Bool {
        let supportsStructuredSingleTimeEarlyCompletion =
            task.recurrenceRule.advanced != nil
            && task.recurrenceRule.timeRange == nil
            && !task.recurrenceRule.occursMoreThanOncePerDay
        return task.usesEffectiveRoutineCadence
            && task.recurrenceRule.isFixedCalendar
            && !task.isChecklistDriven
            && !task.isChecklistCompletionRoutine
            && !task.isMultiDayRoutine
            && !task.recurrenceRule.occursMoreThanOncePerDay
            && (!usesExactTimedOccurrences(for: task) || supportsStructuredSingleTimeEarlyCompletion)
    }

    static func canCompleteScheduledOccurrenceEarly(
        for task: RoutineTask,
        completedAt: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard supportsEarlyScheduledCompletion(for: task) else { return false }
        let occurrence = dueDate(for: task, referenceDate: completedAt, calendar: calendar)
        return occurrence != .distantFuture && occurrence > completedAt
    }

    static func scheduledOccurrenceSatisfiedByCompletion(
        for task: RoutineTask,
        completedAt: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard supportsEarlyScheduledCompletion(for: task) else { return nil }
        let occurrence = dueDate(for: task, referenceDate: completedAt, calendar: calendar)
        return occurrence == .distantFuture ? nil : occurrence
    }

    static func isCompletedForCurrentPeriod(
        _ hasCompletionOnCurrentDay: Bool,
        task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard hasCompletionOnCurrentDay else { return false }
        if task.isOneOffTask {
            return true
        }
        guard task.usesEffectiveRoutineCadence else {
            return false
        }
        guard task.recurrenceRule.occursMoreThanOncePerDay else { return true }
        return dueDate(for: task, referenceDate: referenceDate, calendar: calendar) > referenceDate
    }

    static func canMarkSelectedExactTimedOccurrenceDone(
        for task: RoutineTask,
        completionDate: Date,
        referenceDate: Date,
        logs: [RoutineLog],
        calendar: Calendar = .current
    ) -> Bool {
        guard usesExactTimedOccurrences(for: task) else { return false }
        guard completionDate <= referenceDate else { return false }
        guard
            scheduledOccurrences(for: task, on: completionDate, calendar: calendar).contains(where: {
                RoutineOccurrenceIdentity.matches($0, completionDate, for: task, calendar: calendar)
            })
        else {
            return false
        }
        let occurrence = completionDate

        let hasReplaceableResolution = logs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            guard log.kind == .missed || log.kind == .canceled else { return false }
            return RoutineOccurrenceIdentity.matches(
                timestamp,
                occurrence,
                for: task,
                calendar: calendar
            )
        }
        if hasReplaceableResolution {
            return true
        }

        let isSelectedMissedDate = unresolvedMissedExactTimedOccurrenceDates(
            for: task,
            referenceDate: referenceDate,
            logs: logs,
            calendar: calendar
        ).contains {
            RoutineOccurrenceIdentity.matches($0, occurrence, for: task, calendar: calendar)
        }
        if isSelectedMissedDate {
            return true
        }

        return canMarkDone(
            for: task,
            referenceDate: completionDate,
            calendar: calendar,
            ignoreArchiveAtReferenceDate: true
        )
    }
}

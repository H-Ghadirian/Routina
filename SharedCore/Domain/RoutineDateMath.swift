import Foundation

enum RoutineDateMath {
    static func usesExactTimedOccurrenceTracking(for task: RoutineTask) -> Bool {
        task.usesEffectiveRoutineCadence
            && task.recurrenceRule.usesTimeConstraint
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

        if task.isChecklistDriven,
           let earliestChecklistDueDate = task.nextDueChecklistItem(referenceDate: referenceDate, calendar: calendar)
                .map({ dueDate(for: $0, referenceDate: referenceDate, calendar: calendar) }) {
            return earliestChecklistDueDate
        }

        switch task.recurrenceRule.kind {
        case .intervalDays:
            let anchor = effectiveScheduleAnchor(for: task, referenceDate: referenceDate)
            let dueDate = calendar.date(
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
                base = timeRange.contains(reference.base, calendar: calendar)
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
               ) {
                // If a routine is created on its scheduled weekday, keep that day as
                // the first occurrence even when the creation time is later.
                if let timeRange = task.recurrenceRule.timeRange,
                   !timeRange.contains(reference.base, calendar: calendar),
                   reference.base >= timeRange.endDate(on: reference.base, calendar: calendar) {
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
               ) {
                // If a routine is created on its scheduled day-of-month, keep that day
                // as the first occurrence even when the creation time is later.
                if let timeRange = task.recurrenceRule.timeRange,
                   !timeRange.contains(reference.base, calendar: calendar),
                   reference.base >= timeRange.endDate(on: reference.base, calendar: calendar) {
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
        if usesExactTimedOccurrenceTracking(for: task) {
            var candidate = dueDate(for: task, referenceDate: referenceDate, calendar: calendar)
            for _ in 0..<10_000 {
                guard isExactTimedOccurrenceMissed(
                    candidate,
                    for: task,
                    referenceDate: referenceDate,
                    calendar: calendar
                ) else {
                    return candidate
                }
                let nextCandidate = nextExactTimedOccurrence(after: candidate, for: task, calendar: calendar)
                guard nextCandidate > candidate else { return candidate }
                candidate = nextCandidate
            }
            return candidate
        }
        return dueDate(for: task, referenceDate: referenceDate, calendar: calendar)
    }

    static func daysUntilDue(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        if task.isRecordTask {
            return Int.max
        }
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

        if task.isChecklistDriven {
            return !task.dueChecklistItems(referenceDate: referenceDate, calendar: calendar).isEmpty
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
           !timeRange.contains(referenceDate, calendar: calendar) {
            return false
        }
        return dueDate(for: task, referenceDate: referenceDate, calendar: calendar) <= referenceDate
    }

    static func canMarkSelectedExactTimedOccurrenceDone(
        for task: RoutineTask,
        completionDate: Date,
        referenceDate: Date,
        logs: [RoutineLog],
        calendar: Calendar = .current
    ) -> Bool {
        guard usesExactTimedOccurrenceTracking(for: task) else { return false }
        guard completionDate <= referenceDate else { return false }
        guard let occurrence = scheduledOccurrence(for: task, on: completionDate, calendar: calendar),
              occurrence == completionDate else {
            return false
        }

        let isSelectedMissedDate = unresolvedMissedExactTimedOccurrenceDates(
            for: task,
            referenceDate: referenceDate,
            logs: logs,
            calendar: calendar
        ).contains {
            calendar.isDate($0, inSameDayAs: occurrence)
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

    static func missedExactTimedOccurrenceDates(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        guard usesExactTimedOccurrenceTracking(for: task) else { return [] }
        var dates: [Date] = []
        var candidate = dueDate(for: task, referenceDate: referenceDate, calendar: calendar)

        for _ in 0..<10_000 {
            guard isExactTimedOccurrenceMissed(
                candidate,
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ) else {
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
        guard usesExactTimedOccurrenceTracking(for: task) else { return false }
        return logs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            guard log.kind == .missed || log.kind.resolvesDoneDate || log.kind == .canceled else { return false }
            return calendar.isDate(timestamp, inSameDayAs: missedDate)
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
        guard let missedDate = missedExactTimedOccurrenceDates(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        ).last else {
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
            appendUnique(missedDate, to: &dates, calendar: calendar)
        }
        for missedDate in missedExactTimedOccurrenceDates(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            appendUnique(missedDate, to: &dates, calendar: calendar)
        }
        return dates.sorted()
    }

    private static func historicalMissedExactTimedOccurrenceDates(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> [Date] {
        guard usesExactTimedOccurrenceTracking(for: task) else { return [] }
        var dates: [Date] = []
        var candidate = firstHistoricalExactTimedOccurrence(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )

        for _ in 0..<10_000 {
            guard isExactTimedOccurrenceMissed(
                candidate,
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ) else {
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
        let timeOfDay = scheduledTimeOfDay(for: task.recurrenceRule) ?? RoutineTimeOfDay(hour: 0, minute: 0)

        switch task.recurrenceRule.kind {
        case .intervalDays:
            let firstDueDate = calendar.date(
                byAdding: .day,
                value: max(task.recurrenceRule.interval, 1),
                to: base
            ) ?? base
            return timeOfDay.date(on: firstDueDate, calendar: calendar)

        case .dailyTime:
            let searchBase: Date
            if let timeRange = task.recurrenceRule.timeRange,
               !timeRange.contains(base, calendar: calendar),
               base >= timeRange.endDate(on: base, calendar: calendar) {
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
                   base >= timeRange.endDate(on: base, calendar: calendar) {
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
                   base >= timeRange.endDate(on: base, calendar: calendar) {
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

    private static func appendUnique(_ date: Date, to dates: inout [Date], calendar: Calendar) {
        guard !dates.contains(where: { calendar.isDate($0, inSameDayAs: date) }) else { return }
        dates.append(date)
    }

    private static func isExactTimedMissedOccurrenceAcknowledgedByTaskState(
        for task: RoutineTask,
        missedDate: Date,
        calendar: Calendar
    ) -> Bool {
        if let lastDone = task.lastDone,
           calendar.isDate(lastDone, inSameDayAs: missedDate) {
            return true
        }
        if let canceledAt = task.canceledAt,
           calendar.isDate(canceledAt, inSameDayAs: missedDate) {
            return true
        }
        return false
    }

    private static func isExactTimedOccurrenceMissed(
        _ occurrence: Date,
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        if let timeRange = task.recurrenceRule.timeRange {
            let windowEnd = timeRange.endDate(on: occurrence, calendar: calendar)
            return referenceDate >= windowEnd
        }
        return calendar.startOfDay(for: occurrence) < calendar.startOfDay(for: referenceDate)
    }

    private static func nextExactTimedOccurrence(
        after occurrence: Date,
        for task: RoutineTask,
        calendar: Calendar
    ) -> Date {
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
            let nextDate = calendar.date(
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

    static func scheduledOccurrence(
        for task: RoutineTask,
        on day: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard usesExactTimedOccurrenceTracking(for: task) else { return nil }
        guard let timeOfDay = scheduledTimeOfDay(for: task.recurrenceRule) else { return nil }

        let startOfDay = calendar.startOfDay(for: day)

        switch task.recurrenceRule.kind {
        case .dailyTime:
            return timeOfDay.date(on: startOfDay, calendar: calendar)

        case .weekly:
            guard task.recurrenceRule.resolvedWeekdays(calendar: calendar)
                .contains(calendar.component(.weekday, from: startOfDay)) else { return nil }
            return timeOfDay.date(on: startOfDay, calendar: calendar)

        case .monthlyDay:
            let scheduledDays = task.recurrenceRule.resolvedDaysOfMonth(calendar: calendar).map {
                clampedDayOfMonth($0, monthContaining: startOfDay, calendar: calendar)
            }
            guard scheduledDays.contains(calendar.component(.day, from: startOfDay)) else { return nil }
            return timeOfDay.date(on: startOfDay, calendar: calendar)

        case .intervalDays:
            return intervalOccurrence(
                for: task,
                on: startOfDay,
                timeOfDay: timeOfDay,
                calendar: calendar
            )
        }
    }

    static func completionTargetDate(
        for task: RoutineTask,
        selectedDay: Date,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard usesExactTimedOccurrenceTracking(for: task) else { return nil }

        let normalizedSelectedDay = calendar.startOfDay(for: selectedDay)
        if calendar.isDate(normalizedSelectedDay, inSameDayAs: referenceDate) {
            let due = dueDate(for: task, referenceDate: referenceDate, calendar: calendar)
            guard calendar.isDate(due, inSameDayAs: referenceDate) else { return nil }
            return due <= referenceDate ? due : nil
        }

        return scheduledOccurrence(for: task, on: normalizedSelectedDay, calendar: calendar)
    }

    static func completionDisplayDay(
        for task: RoutineTask,
        completionDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let completionDay = calendar.startOfDay(for: completionDate)
        guard usesExactTimedOccurrenceTracking(for: task) else {
            return completionDay
        }

        if task.recurrenceRule.kind == .intervalDays {
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

    static func softIntervalThresholdDate(
        for task: RoutineTask,
        calendar: Calendar = .current
    ) -> Date? {
        guard task.surfacesSoftIntervalNudges else { return nil }
        guard let lastDone = task.lastDone else { return nil }
        if task.recurrenceRule.kind.repeatBasis == .calendar {
            return softCalendarThresholdDate(for: task, after: lastDone, calendar: calendar)
        }
        let threshold = calendar.date(
            byAdding: .day,
            value: max(task.recurrenceRule.interval, 1),
            to: lastDone
        ) ?? lastDone
        if let timeOfDay = scheduledTimeOfDay(for: task.recurrenceRule) {
            return timeOfDay.date(on: threshold, calendar: calendar)
        }
        return threshold
    }

    private static func softCalendarThresholdDate(
        for task: RoutineTask,
        after lastDone: Date,
        calendar: Calendar
    ) -> Date? {
        let nextSearchBase = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: lastDone)
        ) ?? lastDone
        let timeOfDay = scheduledTimeOfDay(for: task.recurrenceRule)

        switch task.recurrenceRule.kind {
        case .intervalDays:
            return nil
        case .dailyTime:
            return nextDailyOccurrence(
                after: nextSearchBase,
                timeOfDay: timeOfDay ?? RoutineTimeOfDay(hour: 0, minute: 0),
                includeCurrentDate: true,
                calendar: calendar
            )
        case .weekly:
            return nextWeeklyOccurrence(
                after: nextSearchBase,
                weekdays: task.recurrenceRule.resolvedWeekdays(calendar: calendar),
                timeOfDay: timeOfDay,
                includeCurrentDate: true,
                calendar: calendar
            )
        case .monthlyDay:
            return nextMonthlyOccurrence(
                after: nextSearchBase,
                daysOfMonth: task.recurrenceRule.resolvedDaysOfMonth(calendar: calendar),
                timeOfDay: timeOfDay,
                includeCurrentDate: true,
                calendar: calendar
            )
        }
    }

    static func hasPassedSoftIntervalThreshold(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let thresholdDate = softIntervalThresholdDate(for: task, calendar: calendar) else {
            return false
        }
        if task.recurrenceRule.usesTimeConstraint {
            return referenceDate >= thresholdDate
        }
        return calendar.startOfDay(for: referenceDate) >= calendar.startOfDay(for: thresholdDate)
    }

    static func resumedScheduleAnchor(
        for task: RoutineTask,
        resumedAt: Date
    ) -> Date {
        if task.recurrenceRule.isFixedCalendar && !task.isChecklistDriven {
            return resumedAt
        }
        let baseAnchor = task.scheduleAnchor ?? task.lastDone ?? task.pausedAt ?? resumedAt
        guard let pausedAt = task.pausedAt else { return baseAnchor }
        let pauseDuration = max(resumedAt.timeIntervalSince(pausedAt), 0)
        return baseAnchor.addingTimeInterval(pauseDuration)
    }

    private static func recurrenceReference(
        for task: RoutineTask,
        referenceDate: Date
    ) -> (base: Date, includeCurrentDate: Bool) {
        if let scheduleAnchor = task.scheduleAnchor,
           let lastDone = task.lastDone {
            if scheduleAnchor > lastDone {
                return (scheduleAnchor, true)
            }
            return (lastDone, false)
        }

        if let lastDone = task.lastDone {
            return (lastDone, false)
        }

        if let scheduleAnchor = task.scheduleAnchor {
            // Allow marking past occurrences that predate the schedule anchor
            // (e.g. task created on the 28th but scheduled for the 26th)
            let base = referenceDate < scheduleAnchor ? referenceDate : scheduleAnchor
            return (base, true)
        }

        return (referenceDate, true)
    }

    private static func scheduledTimeOfDay(for recurrenceRule: RoutineRecurrenceRule) -> RoutineTimeOfDay? {
        recurrenceRule.timeRange?.start ?? recurrenceRule.timeOfDay
    }

    private static func intervalOccurrence(
        for task: RoutineTask,
        on day: Date,
        timeOfDay: RoutineTimeOfDay,
        calendar: Calendar
    ) -> Date? {
        let interval = max(task.recurrenceRule.interval, 1)
        let anchor = effectiveScheduleAnchor(for: task, referenceDate: day)
        let firstDueDate = calendar.date(
            byAdding: .day,
            value: interval,
            to: anchor
        ) ?? anchor
        let firstDueDay = calendar.startOfDay(for: firstDueDate)
        let targetDay = calendar.startOfDay(for: day)
        let daysSinceFirstDue = calendar.dateComponents(
            [.day],
            from: firstDueDay,
            to: targetDay
        ).day ?? 0

        guard daysSinceFirstDue >= 0, daysSinceFirstDue % interval == 0 else {
            return nil
        }
        return timeOfDay.date(on: targetDay, calendar: calendar)
    }

    private static func nextDailyOccurrence(
        after base: Date,
        timeOfDay: RoutineTimeOfDay,
        includeCurrentDate: Bool,
        calendar: Calendar
    ) -> Date {
        let candidate = timeOfDay.date(on: base, calendar: calendar)
        if candidate > base || (includeCurrentDate && candidate == base) {
            return candidate
        }

        let nextDay = calendar.date(byAdding: .day, value: 1, to: base) ?? base
        return timeOfDay.date(on: nextDay, calendar: calendar)
    }

    private static func clampedDayOfMonth(
        _ dayOfMonth: Int,
        monthContaining date: Date,
        calendar: Calendar
    ) -> Int {
        let dayRange = calendar.range(of: .day, in: .month, for: date) ?? (1..<32)
        return min(max(dayOfMonth, 1), dayRange.count)
    }

    private static func nextWeeklyOccurrence(
        after base: Date,
        weekdays: [Int],
        timeOfDay: RoutineTimeOfDay?,
        includeCurrentDate: Bool,
        calendar: Calendar
    ) -> Date {
        let selectedWeekdays = weekdays.isEmpty ? [calendar.firstWeekday] : weekdays
        return selectedWeekdays
            .map { weekday in
                var components = DateComponents()
                components.weekday = min(max(weekday, 1), 7)
                if let timeOfDay {
                    components.hour = timeOfDay.hour
                    components.minute = timeOfDay.minute
                } else {
                    components.hour = 0
                    components.minute = 0
                }

                // When no specific time is set, compare by calendar day so the routine is
                // considered due on the configured weekday regardless of creation time.
                let searchBase = timeOfDay == nil ? calendar.startOfDay(for: base) : base
                let searchDate = includeCurrentDate ? searchBase.addingTimeInterval(-1) : searchBase
                return calendar.nextDate(
                    after: searchDate,
                    matching: components,
                    matchingPolicy: .nextTimePreservingSmallerComponents,
                    repeatedTimePolicy: .first,
                    direction: .forward
                ) ?? base
            }
            .min() ?? base
    }

    private static func nextMonthlyOccurrence(
        after base: Date,
        daysOfMonth: [Int],
        timeOfDay: RoutineTimeOfDay?,
        includeCurrentDate: Bool,
        calendar: Calendar
    ) -> Date {
        let selectedDays = daysOfMonth.isEmpty ? [1] : daysOfMonth.map { min(max($0, 1), 31) }
        let monthAnchor = calendar.date(
            from: calendar.dateComponents([.year, .month], from: base)
        ) ?? base
        var currentMonth = monthAnchor

        while true {
            let dayCount = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 31
            let candidates = selectedDays.compactMap { selectedDay -> Date? in
                let safeDay = min(selectedDay, dayCount)
                var components = calendar.dateComponents([.year, .month], from: currentMonth)
                components.day = safeDay
                components.hour = timeOfDay?.hour ?? 0
                components.minute = timeOfDay?.minute ?? 0

                let candidate = calendar.date(from: components) ?? currentMonth
                // When no specific time is set, compare by calendar day so the routine is
                // considered due on the configured day of month regardless of creation time.
                let isAfterBase: Bool
                if timeOfDay == nil {
                    let candidateDay = calendar.startOfDay(for: candidate)
                    let baseDay = calendar.startOfDay(for: base)
                    isAfterBase = candidateDay > baseDay || (includeCurrentDate && candidateDay == baseDay)
                } else {
                    isAfterBase = candidate > base || (includeCurrentDate && candidate == base)
                }
                return isAfterBase ? candidate : nil
            }
            if let nextCandidate = candidates.min() {
                return nextCandidate
            }

            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }

    private static func isWeeklyOccurrenceDay(
        _ date: Date,
        weekdays: [Int],
        calendar: Calendar
    ) -> Bool {
        let selectedWeekdays = weekdays.isEmpty ? [calendar.firstWeekday] : weekdays
        return selectedWeekdays.map { min(max($0, 1), 7) }.contains(calendar.component(.weekday, from: date))
    }

    private static func isMonthlyOccurrenceDay(
        _ date: Date,
        daysOfMonth: [Int],
        calendar: Calendar
    ) -> Bool {
        let dayCount = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
        let selectedDays = daysOfMonth.isEmpty ? [1] : daysOfMonth
        return selectedDays
            .map { min(max($0, 1), dayCount) }
            .contains(calendar.component(.day, from: date))
    }
}

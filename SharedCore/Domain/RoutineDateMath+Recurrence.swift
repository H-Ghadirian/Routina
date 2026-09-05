import Foundation

extension RoutineDateMath {
    static func softIntervalThresholdDate(
        for task: RoutineTask,
        calendar: Calendar = .current
    ) -> Date? {
        guard task.surfacesSoftIntervalNudges else { return nil }
        guard let lastDone = task.lastDone else { return nil }
        if let advanced = task.recurrenceRule.advanced {
            return nextAdvancedEffectiveOccurrence(
                for: advanced,
                after: lastDone,
                timeRange: task.recurrenceRule.timeRange,
                calendar: calendar
            )
        }
        if task.recurrenceRule.kind.repeatBasis == .calendar {
            return softCalendarThresholdDate(for: task, after: lastDone, calendar: calendar)
        }
        let threshold =
            calendar.date(
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
        let nextSearchBase =
            calendar.date(
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

    static func recurrenceReference(
        for task: RoutineTask,
        referenceDate: Date
    ) -> (base: Date, includeCurrentDate: Bool) {
        if let satisfiedOccurrence = task.lastSatisfiedScheduledOccurrenceAt {
            return (satisfiedOccurrence, false)
        }
        if let scheduleAnchor = task.scheduleAnchor,
            let lastDone = task.lastDone
        {
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

    static func scheduledTimeOfDay(for recurrenceRule: RoutineRecurrenceRule) -> RoutineTimeOfDay? {
        recurrenceRule.timeRange?.start ?? recurrenceRule.timeOfDay
    }

    static func intervalOccurrence(
        for task: RoutineTask,
        on day: Date,
        timeOfDay: RoutineTimeOfDay,
        calendar: Calendar
    ) -> Date? {
        let interval = max(task.recurrenceRule.interval, 1)
        let anchor = effectiveScheduleAnchor(for: task, referenceDate: day)
        let firstDueDate =
            calendar.date(
                byAdding: .day,
                value: interval,
                to: anchor
            ) ?? anchor
        let firstDueDay = calendar.startOfDay(for: firstDueDate)
        let targetDay = calendar.startOfDay(for: day)
        let daysSinceFirstDue =
            calendar.dateComponents(
                [.day],
                from: firstDueDay,
                to: targetDay
            ).day ?? 0

        guard daysSinceFirstDue >= 0, daysSinceFirstDue % interval == 0 else {
            return nil
        }
        return timeOfDay.date(on: targetDay, calendar: calendar)
    }

    static func nextDailyOccurrence(
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

    static func clampedDayOfMonth(
        _ dayOfMonth: Int,
        monthContaining date: Date,
        calendar: Calendar
    ) -> Int {
        let dayRange = calendar.range(of: .day, in: .month, for: date) ?? (1..<32)
        return min(max(dayOfMonth, 1), dayRange.count)
    }

    static func nextWeeklyOccurrence(
        after base: Date,
        weekdays: [Int],
        timeOfDay: RoutineTimeOfDay?,
        includeCurrentDate: Bool,
        calendar: Calendar
    ) -> Date {
        let selectedWeekdays = weekdays.isEmpty ? [calendar.firstWeekday] : weekdays
        return
            selectedWeekdays
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

    static func nextMonthlyOccurrence(
        after base: Date,
        daysOfMonth: [Int],
        timeOfDay: RoutineTimeOfDay?,
        includeCurrentDate: Bool,
        calendar: Calendar
    ) -> Date {
        let selectedDays = daysOfMonth.isEmpty ? [1] : daysOfMonth.map { min(max($0, 1), 31) }
        let monthAnchor =
            calendar.date(
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

    static func isWeeklyOccurrenceDay(
        _ date: Date,
        weekdays: [Int],
        calendar: Calendar
    ) -> Bool {
        let selectedWeekdays = weekdays.isEmpty ? [calendar.firstWeekday] : weekdays
        return selectedWeekdays.map { min(max($0, 1), 7) }.contains(calendar.component(.weekday, from: date))
    }

    static func isMonthlyOccurrenceDay(
        _ date: Date,
        daysOfMonth: [Int],
        calendar: Calendar
    ) -> Bool {
        let dayCount = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
        let selectedDays = daysOfMonth.isEmpty ? [1] : daysOfMonth
        return
            selectedDays
            .map { min(max($0, 1), dayCount) }
            .contains(calendar.component(.day, from: date))
    }
}

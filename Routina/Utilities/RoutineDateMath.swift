import Foundation

enum RoutineDateMath {
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
        if task.isChecklistDriven,
           let earliestChecklistDueDate = task.nextDueChecklistItem(referenceDate: referenceDate, calendar: calendar)
                .map({ dueDate(for: $0, referenceDate: referenceDate, calendar: calendar) }) {
            return earliestChecklistDueDate
        }

        switch task.recurrenceRule.kind {
        case .intervalDays:
            let anchor = effectiveScheduleAnchor(for: task, referenceDate: referenceDate)
            return calendar.date(
                byAdding: .day,
                value: max(task.recurrenceRule.interval, 1),
                to: anchor
            ) ?? anchor

        case .dailyTime:
            let reference = recurrenceReference(for: task, referenceDate: referenceDate)
            let base: Date
            if task.lastDone == nil {
                // For new tasks, search from start of day so today's occurrence is
                // found even if the task was created after the scheduled time.
                base = calendar.startOfDay(for: reference.base)
            } else {
                base = reference.base
            }
            return nextDailyOccurrence(
                after: base,
                timeOfDay: task.recurrenceRule.timeOfDay ?? .defaultValue,
                includeCurrentDate: task.lastDone == nil || reference.includeCurrentDate,
                calendar: calendar
            )

        case .weekly:
            let reference = recurrenceReference(for: task, referenceDate: referenceDate)
            let base: Date
            if task.lastDone == nil {
                // For new tasks, search from start of week so the current week's
                // occurrence is found even if the scheduled weekday has passed.
                base = calendar.date(
                    from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: reference.base)
                ) ?? reference.base
            } else {
                base = reference.base
            }
            return nextWeeklyOccurrence(
                after: base,
                weekday: task.recurrenceRule.weekday ?? calendar.firstWeekday,
                timeOfDay: task.recurrenceRule.timeOfDay,
                includeCurrentDate: task.lastDone == nil || reference.includeCurrentDate,
                calendar: calendar
            )

        case .monthlyDay:
            let reference = recurrenceReference(for: task, referenceDate: referenceDate)
            let base: Date
            if task.lastDone == nil {
                // For new tasks, search from start of month so the current month's
                // occurrence is found even if the scheduled day has passed.
                base = calendar.date(
                    from: calendar.dateComponents([.year, .month], from: reference.base)
                ) ?? reference.base
            } else {
                base = reference.base
            }
            return nextMonthlyOccurrence(
                after: base,
                dayOfMonth: task.recurrenceRule.dayOfMonth ?? 1,
                timeOfDay: task.recurrenceRule.timeOfDay,
                includeCurrentDate: task.lastDone == nil || reference.includeCurrentDate,
                calendar: calendar
            )
        }
    }

    static func daysUntilDue(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        if task.isOneOffTask {
            return task.isCompletedOneOff ? Int.max : 0
        }
        let todayStart = calendar.startOfDay(for: referenceDate)
        let dueStart = calendar.startOfDay(for: dueDate(for: task, referenceDate: referenceDate, calendar: calendar))
        return calendar.dateComponents([.day], from: todayStart, to: dueStart).day ?? 0
    }

    static func overdueDays(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        max(-daysUntilDue(for: task, referenceDate: referenceDate, calendar: calendar), 0)
    }

    static func canMarkDone(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard !task.isPaused else { return false }

        if task.isOneOffTask {
            return !task.isCompletedOneOff
        }

        if task.isChecklistDriven {
            return !task.dueChecklistItems(referenceDate: referenceDate, calendar: calendar).isEmpty
        }

        guard task.recurrenceRule.isFixedCalendar else { return true }
        return dueDate(for: task, referenceDate: referenceDate, calendar: calendar) <= referenceDate
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

    private static func nextWeeklyOccurrence(
        after base: Date,
        weekday: Int,
        timeOfDay: RoutineTimeOfDay?,
        includeCurrentDate: Bool,
        calendar: Calendar
    ) -> Date {
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

    private static func nextMonthlyOccurrence(
        after base: Date,
        dayOfMonth: Int,
        timeOfDay: RoutineTimeOfDay?,
        includeCurrentDate: Bool,
        calendar: Calendar
    ) -> Date {
        let resolvedDay = min(max(dayOfMonth, 1), 31)
        let monthAnchor = calendar.date(
            from: calendar.dateComponents([.year, .month], from: base)
        ) ?? base
        var currentMonth = monthAnchor

        while true {
            let dayCount = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 31
            let safeDay = min(resolvedDay, dayCount)
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
            if isAfterBase {
                return candidate
            }

            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
}

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
        let anchor = effectiveScheduleAnchor(for: task, referenceDate: referenceDate)
        return calendar.date(byAdding: .day, value: max(Int(task.interval), 1), to: anchor) ?? anchor
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

    static func resumedScheduleAnchor(
        for task: RoutineTask,
        resumedAt: Date
    ) -> Date {
        let baseAnchor = task.scheduleAnchor ?? task.lastDone ?? task.pausedAt ?? resumedAt
        guard let pausedAt = task.pausedAt else { return baseAnchor }
        let pauseDuration = max(resumedAt.timeIntervalSince(pausedAt), 0)
        return baseAnchor.addingTimeInterval(pauseDuration)
    }
}

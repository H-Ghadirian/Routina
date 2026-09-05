import Foundation

extension RoutineAssumedCompletion {
    struct ScheduledBlockCompletionTiming: Equatable, Sendable {
        let completedAt: Date
        let actualDurationMinutes: Int
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
        let actualDurationMinutes =
            calendar.dateComponents(
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
}

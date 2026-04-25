import Foundation

struct HomeTaskListMetrics<Display: HomeTaskListDisplay> {
    var configuration: HomeTaskListFilteringConfiguration

    func sectionDateForDeadlineGrouping(for task: Display) -> Date? {
        guard task.daysUntilDue != Int.max else { return nil }
        let today = configuration.calendar.startOfDay(for: configuration.referenceDate)
        return configuration.calendar.date(byAdding: .day, value: max(task.daysUntilDue, 0), to: today)
            .map { configuration.calendar.startOfDay(for: $0) }
    }

    func deadlineSectionTitle(for task: Display) -> String {
        guard let sectionDate = sectionDateForDeadlineGrouping(for: task) else {
            return "On Track"
        }
        return formattedDeadlineSectionTitle(for: sectionDate)
    }

    func formattedDeadlineSectionTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = configuration.calendar
        formatter.locale = .autoupdatingCurrent
        let referenceDate = configuration.referenceDate
        let includesYear = configuration.calendar.component(.year, from: date) != configuration.calendar.component(.year, from: referenceDate)
        formatter.setLocalizedDateFormatFromTemplate(includesYear ? "EEE MMM d yyyy" : "EEE MMM d")
        return formatter.string(from: date)
    }

    func isYellowUrgency(_ task: Display) -> Bool {
        if task.isOneOffTask {
            return false
        }
        if task.isInProgress
            || task.scheduleMode == .derivedFromChecklist
            || (task.scheduleMode == .fixedIntervalChecklist && task.completedChecklistItemCount > 0) {
            return false
        }
        if task.recurrenceRule.isFixedCalendar {
            return dueInDays(for: task) == 1
        }
        let progress = Double(daysSinceScheduleAnchor(task)) / Double(task.interval)
        return progress >= 0.75 && progress < 0.90
    }

    func dueInDays(for task: Display) -> Int {
        task.daysUntilDue
    }

    func overdueDays(for task: Display) -> Int {
        max(-dueInDays(for: task), 0)
    }

    func daysSinceLastRoutine(_ task: Display) -> Int {
        RoutineDateMath.elapsedDaysSinceLastDone(from: task.lastDone, referenceDate: configuration.referenceDate)
    }

    func daysSinceScheduleAnchor(_ task: Display) -> Int {
        RoutineDateMath.elapsedDaysSinceLastDone(
            from: task.scheduleAnchor ?? task.lastDone,
            referenceDate: configuration.referenceDate
        )
    }

    func urgencyLevel(for task: Display) -> Int {
        let dueIn = dueInDays(for: task)

        if dueIn < 0 { return 3 }
        if dueIn == 0 { return 2 }
        if dueIn == 1 { return 1 }
        return 0
    }
}

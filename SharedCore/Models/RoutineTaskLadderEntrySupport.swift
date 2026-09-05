import Foundation

enum RoutineTaskLadderEntryResolver {
    static func supportsEntryWindow(
        scheduleMode: RoutineScheduleMode,
        cadenceEnabled: Bool,
        hasDeadline: Bool
    ) -> Bool {
        if scheduleMode.taskType == .todo {
            return hasDeadline
        }
        return RoutineTaskTemporalWeightResolver.supportsTemporalWeight(
            scheduleMode: scheduleMode,
            cadenceEnabled: cadenceEnabled
        )
    }

    static func supportsEntryWindow(_ task: RoutineTask) -> Bool {
        supportsEntryWindow(
            scheduleMode: task.scheduleMode,
            cadenceEnabled: task.cadenceEnabled,
            hasDeadline: task.deadline != nil
        )
    }

    static func sanitizedWindow(
        _ window: RoutineTaskLadderEntryWindow,
        scheduleMode: RoutineScheduleMode,
        cadenceEnabled: Bool,
        hasDeadline: Bool,
        maximumBeforeDueDays: Int? = nil
    ) -> RoutineTaskLadderEntryWindow {
        guard
            supportsEntryWindow(
                scheduleMode: scheduleMode,
                cadenceEnabled: cadenceEnabled,
                hasDeadline: hasDeadline
            )
        else {
            return .throughoutCycle
        }
        return window.sanitized(maximumBeforeDueDays: maximumBeforeDueDays)
    }

    static func sanitizedWindow(
        _ window: RoutineTaskLadderEntryWindow,
        for task: RoutineTask
    ) -> RoutineTaskLadderEntryWindow {
        sanitizedWindow(
            window,
            scheduleMode: task.scheduleMode,
            cadenceEnabled: task.cadenceEnabled,
            hasDeadline: task.deadline != nil,
            maximumBeforeDueDays: task.isOneOffTask
                ? nil
                : RoutineTaskTemporalWeightResolver.maximumBeforeDueDays(
                    for: task.recurrenceRule
                )
        )
    }

    static func isEligible(
        _ task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let window = sanitizedWindow(task.taskLadderEntryWindow, for: task)
        guard window != .throughoutCycle else { return true }
        let daysUntilDue = RoutineDateMath.daysUntilDue(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        guard daysUntilDue != Int.max else { return true }
        switch window {
        case .throughoutCycle:
            return true
        case let .beforeDue(days):
            return daysUntilDue <= days
        case .onDueDate:
            return daysUntilDue <= 0
        }
    }

    static func exclusionReason(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> String? {
        let window = sanitizedWindow(task.taskLadderEntryWindow, for: task)
        guard window != .throughoutCycle,
            !isEligible(task, referenceDate: referenceDate, calendar: calendar)
        else {
            return nil
        }
        let daysUntilDue = RoutineDateMath.daysUntilDue(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        guard daysUntilDue != Int.max else {
            return "Outside its Task Ladder entry window"
        }
        let leadDays = window.storageLeadDays ?? daysUntilDue
        let daysUntilEntry = max(daysUntilDue - leadDays, 1)
        return daysUntilEntry == 1
            ? "Enters Task Ladder tomorrow"
            : "Enters Task Ladder in \(daysUntilEntry) days"
    }
}

enum RoutineTaskLadderEntryPresentation {
    static func title(for window: RoutineTaskLadderEntryWindow) -> String {
        switch window {
        case .throughoutCycle:
            return "Throughout"
        case let .beforeDue(days):
            return "\(days) \(days == 1 ? "day" : "days") before due"
        case .onDueDate:
            return "On due date"
        }
    }

    static func detailSummary(for task: RoutineTask) -> String? {
        let window = RoutineTaskLadderEntryResolver.sanitizedWindow(
            task.taskLadderEntryWindow,
            for: task
        )
        guard window != .throughoutCycle else { return nil }
        return "Enters Task Ladder \(title(for: window).lowercased())"
    }
}

struct RoutineTaskEffectiveWeights: Equatable, Sendable {
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let pressure: RoutineTaskPressure
    let progress: Double

    var isAdjusted: Bool { progress > 0 }
}

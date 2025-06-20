import Foundation
import SwiftUI

// SwiftUI-facing presentation helpers used by both iOS and macOS `TaskDetailTCAView`.
// Keep the view layer free of derived-color branching by funneling everything through
// these pure, platform-shared functions.
enum TaskDetailPresentation {

    // MARK: - Relationship + checklist status colors

    static func statusColor(for status: RoutineTaskRelationshipStatus) -> Color {
        switch status {
        case .doneToday, .completedOneOff:
            return .green
        case .overdue:
            return .red
        case .dueToday:
            return .orange
        case .paused:
            return .teal
        case .pendingTodo:
            return .blue
        case .canceledOneOff:
            return .secondary
        case .onTrack:
            return .secondary
        }
    }

    static func checklistStatusColor(
        for item: RoutineChecklistItem,
        task: RoutineTask,
        isMarkedDone: Bool,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Color {
        if task.isChecklistCompletionRoutine {
            return isMarkedDone ? .green : .secondary
        }
        let dueDate = RoutineDateMath.dueDate(for: item, referenceDate: referenceDate, calendar: calendar)
        let daysUntilDue = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: referenceDate),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? 0

        if daysUntilDue < 0 { return .red }
        if daysUntilDue == 0 { return .orange }
        return .secondary
    }

    static func checklistCompletionControlColor(isInteractive: Bool) -> Color {
        isInteractive ? .secondary : .secondary.opacity(0.45)
    }

    static func selectionStrokeColor(
        isSelected: Bool,
        isToday: Bool,
        isHighlightedDay: Bool
    ) -> Color {
        if isSelected { return .blue }
        if isToday && isHighlightedDay { return .blue }
        return .clear
    }

    // MARK: - Summary status color

    static func summaryTitleColor(
        pausedAt: Date?,
        isDoneToday: Bool,
        overdueDays: Int,
        task: RoutineTask,
        referenceDate: Date = Date()
    ) -> Color {
        if task.isSnoozed(referenceDate: referenceDate) { return .indigo }
        if pausedAt != nil { return .teal }
        if task.isOneOffTask {
            if task.isInProgress { return .orange }
            if task.isCompletedOneOff || isDoneToday { return .green }
            if task.isCanceledOneOff { return .orange }
            return .primary
        }
        if task.isChecklistCompletionRoutine {
            if task.isChecklistInProgress { return .orange }
            if isDoneToday { return .green }
            if overdueDays > 0 { return .red }
            if daysUntilDueIfActive(task, referenceDate: referenceDate) == 0 {
                return TaskDetailPlatformStyle.dueTodayTitleColor
            }
            if isOrangeUrgency(task, referenceDate: referenceDate) { return .orange }
            return .primary
        }
        if task.isChecklistDriven {
            if overdueDays > 0 { return .red }
            if daysUntilDueIfActive(task, referenceDate: referenceDate) == 0 {
                return TaskDetailPlatformStyle.dueTodayTitleColor
            }
            if isDoneToday { return .green }
            return .primary
        }
        if task.isInProgress { return .orange }
        if isDoneToday { return .green }
        if overdueDays > 0 { return .red }
        if daysUntilDueIfActive(task, referenceDate: referenceDate) == 0 {
            return TaskDetailPlatformStyle.dueTodayTitleColor
        }
        if isOrangeUrgency(task, referenceDate: referenceDate) { return .orange }
        return .primary
    }

    // MARK: - Urgency helpers

    static func isOrangeUrgency(_ task: RoutineTask, referenceDate: Date = Date()) -> Bool {
        guard !task.isArchived(referenceDate: referenceDate), !task.isChecklistDriven, !task.isOneOffTask else { return false }
        if task.recurrenceRule.isFixedCalendar {
            return daysUntilDueIfActive(task, referenceDate: referenceDate) == 1
        }
        let anchor = task.scheduleAnchor ?? task.lastDone
        let daysSinceAnchor = RoutineDateMath.elapsedDaysSinceLastDone(from: anchor, referenceDate: referenceDate)
        let progress = Double(daysSinceAnchor) / Double(task.interval)
        return progress >= 0.75 && progress < 0.90
    }

    static func daysUntilDueIfActive(_ task: RoutineTask, referenceDate: Date = Date()) -> Int? {
        guard !task.isArchived(referenceDate: referenceDate) else { return nil }
        return RoutineDateMath.daysUntilDue(for: task, referenceDate: referenceDate)
    }
}

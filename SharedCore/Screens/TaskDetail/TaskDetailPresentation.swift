import Foundation
import SwiftUI

// SwiftUI-facing presentation helpers used by both iOS and macOS `TaskDetailTCAView`.
// Keep the view layer free of derived-color branching by funneling everything through
// these pure, platform-shared functions.
enum TaskDetailPresentation {

    // MARK: - Relationship + checklist status colors

    static func statusColor(for status: RoutineTaskRelationshipStatus) -> Color {
        TaskDetailRelationshipPresentation.statusColor(for: status)
    }

    static func checklistStatusColor(
        for item: RoutineChecklistItem,
        task: RoutineTask,
        isMarkedDone: Bool,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Color {
        TaskDetailChecklistPresentation.statusColor(
            for: item,
            task: task,
            isMarkedDone: isMarkedDone,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    static func checklistCompletionControlColor(isInteractive: Bool) -> Color {
        TaskDetailChecklistPresentation.completionControlColor(isInteractive: isInteractive)
    }

    static func selectionStrokeColor(
        isSelected: Bool,
        isToday: Bool,
        isHighlightedDay: Bool
    ) -> Color {
        TaskDetailCalendarPresentation.selectionStrokeColor(
            isSelected: isSelected,
            isToday: isToday,
            isHighlightedDay: isHighlightedDay
        )
    }

    // MARK: - Summary status color

    static func summaryTitleColor(
        pausedAt: Date?,
        isDoneToday: Bool,
        isAssumedDoneToday: Bool,
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
        if isAssumedDoneToday { return .mint }
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

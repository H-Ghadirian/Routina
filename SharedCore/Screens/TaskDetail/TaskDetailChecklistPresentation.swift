import Foundation
import SwiftUI

enum TaskDetailChecklistPresentation {
    static func sortedItems(
        for task: RoutineTask,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [RoutineChecklistItem] {
        task.checklistItems
    }

    static func visibleItems(
        _ items: [RoutineChecklistItem],
        showDone: Bool,
        isMarkedDone: (RoutineChecklistItem) -> Bool
    ) -> [RoutineChecklistItem] {
        guard !showDone else { return items }
        return items.filter { !isMarkedDone($0) }
    }

    static func usesDoneVisibilityFilter(for task: RoutineTask) -> Bool {
        task.supportsOptionalChecklistProgress
    }

    static func isRunoutItemMarkedDone(
        _ item: RoutineChecklistItem,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let lastPurchasedAt = item.lastPurchasedAt else { return false }
        return calendar.isDate(lastPurchasedAt, inSameDayAs: referenceDate)
    }

    static func statusText(
        for item: RoutineChecklistItem,
        task: RoutineTask,
        isMarkedDone: Bool,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        if !task.isChecklistDriven {
            return isMarkedDone ? "Done" : "Pending"
        }
        let dueDate = RoutineDateMath.dueDate(for: item, referenceDate: referenceDate, calendar: calendar)
        let daysUntilDue = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: referenceDate),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? 0

        if daysUntilDue < 0 {
            return "Overdue by \(abs(daysUntilDue)) \(dayWord(abs(daysUntilDue)))"
        }
        if daysUntilDue == 0 {
            return "Due today"
        }
        if daysUntilDue == 1 {
            return "Due tomorrow"
        }
        return "Due in \(daysUntilDue) days"
    }

    static func canToggleItem(
        _ item: RoutineChecklistItem,
        task: RoutineTask,
        selectedDate: Date,
        isSelectedDateCompleted: Bool,
        calendar: Calendar = .current
    ) -> Bool {
        guard !task.isArchived(),
              calendar.isDateInToday(selectedDate) else {
            return false
        }

        guard task.isChecklistCompletionRoutine else {
            return task.supportsOptionalChecklistProgress
                && !task.isCompletedOneOff
                && !task.isCanceledOneOff
        }

        if isSelectedDateCompleted {
            return false
        }

        let isChecklistInProgress = task.isChecklistInProgress(referenceDate: selectedDate, calendar: calendar)
        if task.isChecklistItemCompleted(item.id, referenceDate: selectedDate, calendar: calendar) {
            return isChecklistInProgress
        }

        return true
    }

    static func statusColor(
        for item: RoutineChecklistItem,
        task: RoutineTask,
        isMarkedDone: Bool,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Color {
        if !task.isChecklistDriven {
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

    static func completionControlColor(isInteractive: Bool) -> Color {
        isInteractive ? .secondary : .secondary.opacity(0.45)
    }

    private static func dayWord(_ count: Int) -> String {
        abs(count) == 1 ? "day" : "days"
    }
}

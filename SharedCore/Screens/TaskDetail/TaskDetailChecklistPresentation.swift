import Foundation

enum TaskDetailChecklistPresentation {
    static func sortedItems(
        for task: RoutineTask,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [RoutineChecklistItem] {
        if task.isChecklistCompletionRoutine {
            return task.checklistItems
        }
        return task.checklistItems.sorted {
            RoutineDateMath.dueDate(for: $0, referenceDate: referenceDate, calendar: calendar)
                < RoutineDateMath.dueDate(for: $1, referenceDate: referenceDate, calendar: calendar)
        }
    }

    static func statusText(
        for item: RoutineChecklistItem,
        task: RoutineTask,
        isMarkedDone: Bool,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        if task.isChecklistCompletionRoutine {
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
        isDoneToday: Bool,
        calendar: Calendar = .current
    ) -> Bool {
        guard task.isChecklistCompletionRoutine,
              !task.isArchived(),
              calendar.isDateInToday(selectedDate) else {
            return false
        }

        if isDoneToday && !task.isChecklistInProgress {
            return false
        }

        if task.isChecklistItemCompleted(item.id) {
            return task.isChecklistInProgress
        }

        return true
    }

    private static func dayWord(_ count: Int) -> String {
        abs(count) == 1 ? "day" : "days"
    }
}

import SwiftUI

struct TaskDetailCalendarCardContent: View {
    let displayedMonthStart: Date
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let logs: [RoutineLog]
    let task: RoutineTask
    let dueDate: Date?
    let softDueDate: Date?
    let isOrangeUrgencyToday: Bool
    let selectedDate: Date
    let onSelectDate: (Date) -> Void

    var body: some View {
        TaskDetailCalendarSectionView(
            displayedMonthStart: displayedMonthStart,
            onPreviousMonth: onPreviousMonth,
            onNextMonth: onNextMonth,
            showsAssumedLegend: task.autoAssumeDailyDone,
            showsSoftDueLegend: softDueDate != nil,
            showsPausedLegend: task.pausedAt != nil,
            showsCreatedLegend: task.createdAt != nil
        ) {
            TaskDetailCalendarGridView(
                displayedMonthStart: displayedMonthStart,
                doneDates: TaskDetailCalendarPresentation.doneDates(from: logs, task: task),
                assumedDates: TaskDetailCalendarPresentation.assumedDates(from: logs, task: task),
                dueDate: dueDate,
                softDueDate: softDueDate,
                createdAt: task.createdAt,
                pausedAt: task.pausedAt,
                isOrangeUrgencyToday: isOrangeUrgencyToday,
                selectedDate: selectedDate,
                onSelectDate: onSelectDate
            )
        }
    }
}

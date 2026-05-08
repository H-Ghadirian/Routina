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
            showsMissedLegend: missedDate != nil,
            showsDueLegend: dueDate != nil,
            showsOverdueLegend: isOverdueRangeVisible,
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
                missedDate: missedDate,
                createdAt: task.createdAt,
                pausedAt: task.pausedAt,
                isOrangeUrgencyToday: isOrangeUrgencyToday,
                selectedDate: selectedDate,
                onSelectDate: onSelectDate
            )
        }
    }

    private var missedDate: Date? {
        RoutineDateMath.missedExactTimedOccurrenceDate(for: task, referenceDate: Date())
    }

    private var isOverdueRangeVisible: Bool {
        guard let dueDate else { return false }
        let calendar = Calendar.current
        return calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: Date())
    }
}

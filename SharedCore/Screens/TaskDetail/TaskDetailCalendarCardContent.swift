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
    let onToday: () -> Void

    var body: some View {
        TaskDetailCalendarSectionView(
            displayedMonthStart: displayedMonthStart,
            onPreviousMonth: onPreviousMonth,
            onNextMonth: onNextMonth,
            isTodaySelected: Calendar.current.isDateInToday(selectedDate),
            onToday: onToday,
            showsAssumedLegend: task.autoAssumeDailyDone,
            showsMissedLegend: !missedDates.isEmpty,
            showsCanceledLegend: !canceledDates.isEmpty,
            showsDueLegend: dueDate != nil,
            showsOverdueLegend: isOverdueRangeVisible,
            showsSoftDueLegend: softDueDate != nil,
            showsPausedLegend: task.pausedAt != nil,
            showsOngoingLegend: task.ongoingSince != nil,
            showsCompletedMultiDaySpanLegend: !completedMultiDaySpanDates.isEmpty,
            showsCreatedLegend: task.createdAt != nil
        ) {
            TaskDetailCalendarGridView(
                displayedMonthStart: displayedMonthStart,
                doneDates: TaskDetailCalendarPresentation.doneDates(from: logs, task: task),
                assumedDates: TaskDetailCalendarPresentation.assumedDates(from: logs, task: task),
                dueDate: dueDate,
                softDueDate: softDueDate,
                missedDates: missedDates,
                canceledDates: canceledDates,
                completedMultiDaySpanDates: completedMultiDaySpanDates,
                createdAt: task.createdAt,
                pausedAt: task.pausedAt,
                ongoingSince: task.ongoingSince,
                isOrangeUrgencyToday: isOrangeUrgencyToday,
                selectedDate: selectedDate,
                onSelectDate: onSelectDate
            )
        }
    }

    private var missedDates: Set<Date> {
        let loggedMissedDates: [Date] = logs.compactMap { log in
            guard log.kind == .missed, let timestamp = log.timestamp else { return nil }
            return Calendar.current.startOfDay(for: timestamp)
        }
        var dates = Set(loggedMissedDates)
        if let unresolvedMissedDate = RoutineDateMath.unresolvedMissedExactTimedOccurrenceDate(
            for: task,
            referenceDate: Date(),
            logs: logs
        ) {
            dates.insert(Calendar.current.startOfDay(for: unresolvedMissedDate))
        }
        return dates
    }

    private var canceledDates: Set<Date> {
        let loggedCanceledDates: [Date] = logs.compactMap { log in
            guard log.kind == .canceled, let timestamp = log.timestamp else { return nil }
            return Calendar.current.startOfDay(for: timestamp)
        }
        var dates = Set(loggedCanceledDates)
        if let canceledAt = task.canceledAt {
            dates.insert(Calendar.current.startOfDay(for: canceledAt))
        }
        return dates
    }

    private var completedMultiDaySpanDates: Set<Date> {
        TaskDetailCalendarPresentation.completedMultiDaySpanDates(from: task.changeLogEntries)
    }

    private var isOverdueRangeVisible: Bool {
        guard let dueDate else { return false }
        let calendar = Calendar.current
        return calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: Date())
    }
}

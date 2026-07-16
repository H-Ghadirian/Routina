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
        let doneDates = TaskDetailCalendarPresentation.doneDates(from: logs, task: task)
        let assumedDates = TaskDetailCalendarPresentation.assumedDates(from: logs, task: task)
        TaskDetailCalendarSectionView(
            displayedMonthStart: displayedMonthStart,
            onPreviousMonth: onPreviousMonth,
            onNextMonth: onNextMonth,
            showsTodayButton: TaskDetailCalendarTodayButtonVisibility.showsButton(
                selectedDate: selectedDate,
                displayedMonthStart: displayedMonthStart
            ),
            onToday: onToday,
            showsAssumedLegend: RoutineAssumedCompletion.isEligible(task),
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
                doneDates: doneDates,
                assumedDates: assumedDates,
                dueDate: dueDate,
                softDueDate: softDueDate,
                missedDates: missedDates,
                canceledDates: canceledDates,
                completedMultiDaySpanDates: completedMultiDaySpanDates,
                createdAt: task.createdAt,
                pausedAt: task.pausedAt,
                ongoingSince: task.ongoingSince,
                isOrangeUrgencyToday: isOrangeUrgencyToday,
                resolvesOverdueBeforeDueDate: task.isOneOffTask,
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
        dates.formUnion(RoutineDateMath.unresolvedMissedExactTimedOccurrenceDates(
            for: task,
            referenceDate: Date(),
            logs: logs
        ).map { Calendar.current.startOfDay(for: $0) })
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
        TaskDetailCalendarPresentation.hasVisibleOverdueRange(
            dueDate: dueDate,
            doneDates: TaskDetailCalendarPresentation.doneDates(from: logs, task: task),
            missedDates: missedDates,
            canceledDates: canceledDates,
            resolvesBeforeDueDate: task.isOneOffTask
        )
    }
}

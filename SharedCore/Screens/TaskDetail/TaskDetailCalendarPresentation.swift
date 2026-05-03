import Foundation
import SwiftUI

struct TaskDetailCalendarDayPresentation: Equatable {
    let isDueDate: Bool
    let isCreatedDate: Bool
    let isDoneDate: Bool
    let isAssumedDate: Bool
    let isToday: Bool
    let isDueToTodayRangeDate: Bool
    let isPausedDate: Bool
    let isOrangeUrgencyToday: Bool

    var isHighlightedDay: Bool {
        isDoneDate || isAssumedDate || isDueToTodayRangeDate || isDueDate || isPausedDate || isCreatedDate
    }

    var backgroundColor: Color {
        if isDoneDate { return .green }
        if isAssumedDate { return .mint }
        if isPausedDate { return .teal }
        if isDueToTodayRangeDate || isDueDate { return .red }
        if isCreatedDate { return .purple }
        if isToday && isOrangeUrgencyToday { return .orange }
        if isToday { return .blue }
        return .clear
    }

    var foregroundColor: Color {
        isDueDate || isDoneDate || isAssumedDate || isDueToTodayRangeDate || isPausedDate || isCreatedDate || isToday
            ? .white
            : .primary
    }
}

enum TaskDetailCalendarPresentation {
    static func selectionStrokeColor(
        isSelected: Bool,
        isToday: Bool,
        isHighlightedDay: Bool
    ) -> Color {
        if isSelected { return .blue }
        if isToday && isHighlightedDay { return .blue }
        return .clear
    }

    static func doneDates(
        from logs: [RoutineLog],
        task: RoutineTask,
        calendar: Calendar = .current
    ) -> Set<Date> {
        var dates = Set<Date>(logs.compactMap { log in
            guard let timestamp = log.timestamp, log.kind == .completed else { return nil }
            return RoutineDateMath.completionDisplayDay(for: task, completionDate: timestamp, calendar: calendar)
        })
        if let lastDone = task.lastDone,
           let displayDay = RoutineDateMath.completionDisplayDay(
               for: task,
               completionDate: lastDone,
               calendar: calendar
           ) {
            dates.insert(displayDay)
        }
        return dates
    }

    static func assumedDates(
        from logs: [RoutineLog],
        task: RoutineTask,
        calendar: Calendar = .current
    ) -> Set<Date> {
        Set(
            RoutineAssumedCompletion.assumedDates(for: task, logs: logs)
                .map { calendar.startOfDay(for: $0) }
        )
    }

    static func dayPresentation(
        day: Date,
        doneDates: Set<Date>,
        assumedDates: Set<Date>,
        dueDate: Date?,
        createdAt: Date?,
        pausedAt: Date?,
        isOrangeUrgencyToday: Bool,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskDetailCalendarDayPresentation {
        let isDueDate = dueDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isCreatedDate = createdAt.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isDoneDate = doneDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isAssumedDate = !isDoneDate && assumedDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isToday = calendar.isDate(day, inSameDayAs: referenceDate)
        let isDueToTodayRangeDate = isInDueToTodayRange(
            day: day,
            dueDate: dueDate,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let isPausedDate = isInPausedRange(
            day: day,
            pausedAt: pausedAt,
            referenceDate: referenceDate,
            calendar: calendar
        )

        return TaskDetailCalendarDayPresentation(
            isDueDate: isDueDate,
            isCreatedDate: isCreatedDate,
            isDoneDate: isDoneDate,
            isAssumedDate: isAssumedDate,
            isToday: isToday,
            isDueToTodayRangeDate: isDueToTodayRangeDate,
            isPausedDate: isPausedDate,
            isOrangeUrgencyToday: isOrangeUrgencyToday
        )
    }

    static func isInDueToTodayRange(
        day: Date,
        dueDate: Date?,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let dueDate else { return false }
        let dayStart = calendar.startOfDay(for: day)
        let dueStart = calendar.startOfDay(for: dueDate)
        let referenceStart = calendar.startOfDay(for: referenceDate)

        guard dueStart <= referenceStart else { return false }
        return dayStart >= dueStart && dayStart <= referenceStart
    }

    static func isInPausedRange(
        day: Date,
        pausedAt: Date?,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let pausedAt else { return false }
        let dayStart = calendar.startOfDay(for: day)
        let pausedStart = calendar.startOfDay(for: pausedAt)
        let referenceStart = calendar.startOfDay(for: referenceDate)
        return dayStart >= pausedStart && dayStart <= referenceStart
    }
}

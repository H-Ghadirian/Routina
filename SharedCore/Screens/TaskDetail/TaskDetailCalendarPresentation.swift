import Foundation
import SwiftUI

enum TaskDetailStatusPalette {
    static let created: Color = .purple
    static let done: Color = .green
    static let assumed: Color = .mint
    static let missed: Color = .yellow
    static let canceled: Color = .gray
    static let due: Color = .orange
    static let overdue: Color = .red
    static let paused: Color = .teal
    static let today: Color = .blue
}

struct TaskDetailCalendarDayPresentation: Equatable {
    let isDueDate: Bool
    let isSoftDueDate: Bool
    let isCreatedDate: Bool
    let isDoneDate: Bool
    let isAssumedDate: Bool
    let isMissedDate: Bool
    let isCanceledDate: Bool
    let isToday: Bool
    let isDueToTodayRangeDate: Bool
    let isPausedDate: Bool
    let isOrangeUrgencyToday: Bool

    var isHighlightedDay: Bool {
        isDoneDate || isAssumedDate || isMissedDate || isCanceledDate || isDueToTodayRangeDate || isDueDate || isSoftDueDate || isPausedDate || isCreatedDate
    }

    var backgroundColor: Color {
        if isDoneDate { return TaskDetailStatusPalette.done }
        if isAssumedDate { return TaskDetailStatusPalette.assumed }
        if isCanceledDate { return TaskDetailStatusPalette.canceled }
        if isMissedDate { return TaskDetailStatusPalette.missed }
        if isPausedDate { return TaskDetailStatusPalette.paused }
        if isDueToTodayRangeDate { return TaskDetailStatusPalette.overdue }
        if isDueDate { return TaskDetailStatusPalette.due }
        if isSoftDueDate { return TaskDetailStatusPalette.due }
        if isCreatedDate { return TaskDetailStatusPalette.created }
        if isToday && isOrangeUrgencyToday { return TaskDetailStatusPalette.due }
        if isToday { return TaskDetailStatusPalette.today }
        return .clear
    }

    var foregroundColor: Color {
        if isMissedDate { return .black }
        return isDueDate || isSoftDueDate || isDoneDate || isAssumedDate || isCanceledDate || isDueToTodayRangeDate || isPausedDate || isCreatedDate || isToday
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
        if isSelected { return .accentColor }
        if isToday && isHighlightedDay { return .primary.opacity(0.75) }
        return .clear
    }

    static func selectionStrokeLineWidth(
        isSelected: Bool,
        isToday: Bool,
        isHighlightedDay: Bool
    ) -> CGFloat {
        if isSelected { return 3.5 }
        if isToday && isHighlightedDay { return 1.5 }
        return 0
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
        softDueDate: Date? = nil,
        missedDates: Set<Date> = [],
        canceledDates: Set<Date> = [],
        createdAt: Date?,
        pausedAt: Date?,
        isOrangeUrgencyToday: Bool,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskDetailCalendarDayPresentation {
        let isDueDate = dueDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isSoftDueDate = softDueDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isCreatedDate = createdAt.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isDoneDate = doneDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isAssumedDate = !isDoneDate && assumedDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isCanceledDate = !isDoneDate && canceledDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isMissedDate = !isDoneDate && !isCanceledDate && missedDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isToday = calendar.isDate(day, inSameDayAs: referenceDate)
        let isDueToTodayRangeDate = isInDueToTodayRange(
            day: day,
            dueDate: dueDate,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let isPausedDate = !isDoneDate && !isAssumedDate && !isCanceledDate && !isMissedDate && isInPausedRange(
            day: day,
            pausedAt: pausedAt,
            referenceDate: referenceDate,
            calendar: calendar
        )

        return TaskDetailCalendarDayPresentation(
            isDueDate: isDueDate,
            isSoftDueDate: isSoftDueDate,
            isCreatedDate: isCreatedDate,
            isDoneDate: isDoneDate,
            isAssumedDate: isAssumedDate,
            isMissedDate: isMissedDate,
            isCanceledDate: isCanceledDate,
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

        guard dueStart < referenceStart else { return false }
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

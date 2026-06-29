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
    static let ongoing: Color = .cyan
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
    let isCompletedMultiDaySpanDate: Bool
    let isToday: Bool
    let isDueToTodayRangeDate: Bool
    let isPausedDate: Bool
    let isOngoingDate: Bool
    let isOrangeUrgencyToday: Bool

    var isHighlightedDay: Bool {
        isDoneDate || isAssumedDate || isMissedDate || isCanceledDate || isCompletedMultiDaySpanDate || isDueToTodayRangeDate || isDueDate || isSoftDueDate || isPausedDate || isOngoingDate || isCreatedDate
    }

    var backgroundColor: Color {
        if isDoneDate { return TaskDetailStatusPalette.done }
        if isCompletedMultiDaySpanDate { return TaskDetailStatusPalette.ongoing }
        if isAssumedDate { return TaskDetailStatusPalette.assumed }
        if isCanceledDate { return TaskDetailStatusPalette.canceled }
        if isMissedDate { return TaskDetailStatusPalette.missed }
        if isPausedDate { return TaskDetailStatusPalette.paused }
        if isOngoingDate { return TaskDetailStatusPalette.ongoing }
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
        return isDueDate || isSoftDueDate || isDoneDate || isAssumedDate || isCanceledDate || isCompletedMultiDaySpanDate || isDueToTodayRangeDate || isPausedDate || isOngoingDate || isCreatedDate || isToday
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

    static func completedMultiDaySpanDates(
        from changes: [RoutineTaskChangeLogEntry],
        calendar: Calendar = .current
    ) -> Set<Date> {
        changes.reduce(into: Set<Date>()) { dates, change in
            guard change.kind == .ongoingStopped else { return }
            guard let startedAt = RoutineTaskMultiDaySpanDateStorage.decode(change.previousValue) else { return }
            let finishedAt = RoutineTaskMultiDaySpanDateStorage.decode(change.newValue) ?? change.timestamp
            for day in daysInClosedRange(from: startedAt, through: finishedAt, calendar: calendar) {
                dates.insert(day)
            }
        }
    }

    static func dayPresentation(
        day: Date,
        doneDates: Set<Date>,
        assumedDates: Set<Date>,
        dueDate: Date?,
        softDueDate: Date? = nil,
        missedDates: Set<Date> = [],
        canceledDates: Set<Date> = [],
        completedMultiDaySpanDates: Set<Date> = [],
        createdAt: Date?,
        pausedAt: Date?,
        ongoingSince: Date? = nil,
        isOrangeUrgencyToday: Bool,
        resolvesOverdueBeforeDueDate: Bool = false,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskDetailCalendarDayPresentation {
        let isDueDate = dueDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isSoftDueDate = softDueDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isCreatedDate = createdAt.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isDoneDate = doneDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isCompletedMultiDaySpanDate = !isDoneDate && completedMultiDaySpanDates.contains {
            calendar.isDate($0, inSameDayAs: day)
        }
        let isAssumedDate = !isDoneDate && assumedDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isCanceledDate = !isDoneDate && canceledDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isMissedDate = !isDoneDate && !isCanceledDate && missedDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isToday = calendar.isDate(day, inSameDayAs: referenceDate)
        let isDueDateMissed = dueDate.map { dueDate in
            missedDates.contains { calendar.isDate($0, inSameDayAs: dueDate) }
        } ?? false
        let overdueResolutionDates = doneDates.union(canceledDates).union(missedDates)
        let isDueToTodayRangeDate = !isMissedDate && !isDueDateMissed && isInDueToTodayRange(
            day: day,
            dueDate: dueDate,
            resolutionDates: overdueResolutionDates,
            resolvesBeforeDueDate: resolvesOverdueBeforeDueDate,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let isPausedDate = !isDoneDate && !isAssumedDate && !isCanceledDate && !isMissedDate && isInPausedRange(
            day: day,
            pausedAt: pausedAt,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let isOngoingDate = !isDoneDate && !isCompletedMultiDaySpanDate && !isAssumedDate && !isCanceledDate && !isMissedDate && !isPausedDate && isInOngoingRange(
            day: day,
            ongoingSince: ongoingSince,
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
            isCompletedMultiDaySpanDate: isCompletedMultiDaySpanDate,
            isToday: isToday,
            isDueToTodayRangeDate: isDueToTodayRangeDate,
            isPausedDate: isPausedDate,
            isOngoingDate: isOngoingDate,
            isOrangeUrgencyToday: isOrangeUrgencyToday
        )
    }

    static func isInDueToTodayRange(
        day: Date,
        dueDate: Date?,
        resolutionDates: Set<Date> = [],
        resolvesBeforeDueDate: Bool = false,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let dueDate else { return false }
        let dayStart = calendar.startOfDay(for: day)
        let dueStart = calendar.startOfDay(for: dueDate)
        let referenceStart = calendar.startOfDay(for: referenceDate)

        guard dueStart < referenceStart else { return false }
        let rangeEnd = dueToTodayRangeEndDate(
            dueStart: dueStart,
            referenceStart: referenceStart,
            resolutionDates: resolutionDates,
            resolvesBeforeDueDate: resolvesBeforeDueDate,
            calendar: calendar
        )
        return dayStart >= dueStart && dayStart <= rangeEnd
    }

    static func hasVisibleOverdueRange(
        dueDate: Date?,
        doneDates: Set<Date>,
        missedDates: Set<Date>,
        canceledDates: Set<Date>,
        resolvesBeforeDueDate: Bool = false,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let dueDate else { return false }
        let dueStart = calendar.startOfDay(for: dueDate)
        let referenceStart = calendar.startOfDay(for: referenceDate)
        guard dueStart < referenceStart else { return false }
        guard !containsDate(missedDates, matching: dueStart, calendar: calendar) else { return false }

        let resolutionDates = doneDates.union(missedDates).union(canceledDates)
        let rangeEnd = dueToTodayRangeEndDate(
            dueStart: dueStart,
            referenceStart: referenceStart,
            resolutionDates: resolutionDates,
            resolvesBeforeDueDate: resolvesBeforeDueDate,
            calendar: calendar
        )
        var currentDay = dueStart
        while currentDay <= rangeEnd {
            let isResolved = containsDate(doneDates, matching: currentDay, calendar: calendar)
                || containsDate(missedDates, matching: currentDay, calendar: calendar)
                || containsDate(canceledDates, matching: currentDay, calendar: calendar)
            if !isResolved {
                return true
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }
        return false
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

    static func isInOngoingRange(
        day: Date,
        ongoingSince: Date?,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let ongoingSince else { return false }
        let dayStart = calendar.startOfDay(for: day)
        let ongoingStart = calendar.startOfDay(for: ongoingSince)
        let referenceStart = calendar.startOfDay(for: referenceDate)
        return dayStart >= ongoingStart && dayStart <= referenceStart
    }

    private static func daysInClosedRange(
        from startDate: Date,
        through endDate: Date,
        calendar: Calendar
    ) -> [Date] {
        let startDay = calendar.startOfDay(for: min(startDate, endDate))
        let endDay = calendar.startOfDay(for: max(startDate, endDate))
        var days: [Date] = []
        var currentDay = startDay
        while currentDay <= endDay {
            days.append(currentDay)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }
        return days
    }

    private static func dueToTodayRangeEndDate(
        dueStart: Date,
        referenceStart: Date,
        resolutionDates: Set<Date>,
        resolvesBeforeDueDate: Bool,
        calendar: Calendar
    ) -> Date {
        let lowerBound = resolvesBeforeDueDate ? Date.distantPast : dueStart
        return resolutionDates
            .map { calendar.startOfDay(for: $0) }
            .filter { $0 >= lowerBound && $0 <= referenceStart }
            .min() ?? referenceStart
    }

    private static func containsDate(
        _ dates: Set<Date>,
        matching day: Date,
        calendar: Calendar
    ) -> Bool {
        dates.contains { calendar.isDate($0, inSameDayAs: day) }
    }
}

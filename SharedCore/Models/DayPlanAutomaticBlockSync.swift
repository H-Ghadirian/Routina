import Foundation
import SwiftData

enum DayPlanAutomaticBlockSync {
    private struct Placement: Equatable {
        enum Kind: Equatable {
            case scheduled
            case availabilityWindow
        }

        var kind: Kind
        var startMinute: Int
        var durationMinutes: Int
    }

    @discardableResult
    static func rebaseAutomaticallyScheduledBlocks(
        from previousTask: RoutineTask,
        to updatedTask: RoutineTask,
        calendar: Calendar,
        context: ModelContext
    ) throws -> Bool {
        guard previousTask.id == updatedTask.id else { return false }

        let taskID = updatedTask.id
        let records = try context.fetch(
            FetchDescriptor<DayPlanBlockRecord>(
                predicate: #Predicate<DayPlanBlockRecord> { record in
                    record.taskID == taskID
                }
            )
        )
        var didChange = false

        for record in records {
            guard let date = date(forDayKey: record.dayKey, calendar: calendar),
                let previousPlacement = automaticPlacement(
                    for: previousTask,
                    on: date,
                    calendar: calendar
                ),
                isAutomaticallyManaged(record, matching: previousPlacement)
            else {
                continue
            }

            guard
                let updatedPlacement = scheduledPlacement(
                    for: updatedTask,
                    on: date,
                    calendar: calendar
                ),
                !updatedTask.isArchived(
                    referenceDate: date,
                    calendar: calendar
                )
            else {
                context.delete(record)
                didChange = true
                continue
            }

            record.apply(
                DayPlanBlock(
                    id: record.id,
                    taskID: record.taskID,
                    dayKey: record.dayKey,
                    startMinute: updatedPlacement.startMinute,
                    durationMinutes: updatedPlacement.durationMinutes,
                    titleSnapshot: record.titleSnapshot,
                    emojiSnapshot: record.emojiSnapshot,
                    createdAt: record.createdAt,
                    updatedAt: Date(),
                    placementSource: .automatic,
                    minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
                )
            )
            didChange = true
        }

        return didChange
    }

    private static func isAutomaticallyManaged(
        _ record: DayPlanBlockRecord,
        matching previousPlacement: Placement
    ) -> Bool {
        switch record.placementSource {
        case .automatic:
            return true
        case .manual:
            return false
        case .legacy:
            let matchesPreviousPlacement =
                record.startMinute == previousPlacement.startMinute
                && record.durationMinutes == previousPlacement.durationMinutes
            return matchesPreviousPlacement || record.createdAt == record.updatedAt
        }
    }

    private static func automaticPlacement(
        for task: RoutineTask,
        on date: Date,
        calendar: Calendar
    ) -> Placement? {
        if let scheduled = scheduledBlock(for: task, on: date, calendar: calendar) {
            return scheduled
        }

        guard let window = availabilityWindow(for: task, on: date, calendar: calendar) else {
            return nil
        }
        return window
    }

    private static func scheduledPlacement(
        for task: RoutineTask,
        on date: Date,
        calendar: Calendar
    ) -> Placement? {
        guard let placement = scheduledBlock(for: task, on: date, calendar: calendar) else {
            return nil
        }
        return placement.kind == .scheduled ? placement : nil
    }

    private static func scheduledBlock(
        for task: RoutineTask,
        on date: Date,
        calendar: Calendar
    ) -> Placement? {
        guard !task.isAllDay else { return nil }

        if task.isOneOffTask {
            if isDateWithinAvailabilityDateBounds(date, for: task, calendar: calendar) {
                if let timeRange = task.recurrenceRule.timeRange,
                    task.recurrenceTimeRangeRole == .scheduledBlock
                {
                    let startDate = timeRange.startDate(on: date, calendar: calendar)
                    let endDate = timeRange.endDate(on: date, calendar: calendar)
                    return placement(
                        kind: .scheduled,
                        startDate: startDate,
                        durationMinutes: availabilityWindowDuration(start: startDate, end: endDate),
                        task: task,
                        calendar: calendar
                    )
                }
                if let timeOfDay = task.recurrenceRule.timeOfDay {
                    return placement(
                        kind: .scheduled,
                        startDate: timeOfDay.date(on: date, calendar: calendar),
                        durationMinutes: nil,
                        task: task,
                        calendar: calendar
                    )
                }
            }

            guard let deadline = task.deadline,
                calendar.isDate(deadline, inSameDayAs: date),
                hasExplicitTime(deadline, calendar: calendar)
            else {
                return nil
            }
            return placement(
                kind: .scheduled,
                startDate: deadline,
                durationMinutes: nil,
                task: task,
                calendar: calendar
            )
        }

        guard
            let occurrence = RoutineDateMath.scheduledOccurrence(
                for: task,
                on: date,
                calendar: calendar
            )
        else {
            return nil
        }
        if let timeRange = task.recurrenceRule.timeRange {
            guard task.recurrenceTimeRangeRole == .scheduledBlock else { return nil }
            let rangeStart = timeRange.startDate(on: occurrence, calendar: calendar)
            return placement(
                kind: .scheduled,
                startDate: rangeStart,
                durationMinutes: availabilityWindowDuration(
                    start: rangeStart,
                    end: timeRange.endDate(on: rangeStart, calendar: calendar)
                ),
                task: task,
                calendar: calendar
            )
        }
        return placement(
            kind: .scheduled,
            startDate: occurrence,
            durationMinutes: nil,
            task: task,
            calendar: calendar
        )
    }

    private static func availabilityWindow(
        for task: RoutineTask,
        on date: Date,
        calendar: Calendar
    ) -> Placement? {
        guard !task.isAllDay,
            task.recurrenceTimeRangeRole == .availability,
            let timeRange = task.recurrenceRule.timeRange
        else {
            return nil
        }

        if task.isOneOffTask {
            guard isDateWithinAvailabilityDateBounds(date, for: task, calendar: calendar) else {
                return nil
            }
            let startDate = timeRange.startDate(on: date, calendar: calendar)
            let endDate = timeRange.endDate(on: date, calendar: calendar)
            return placement(
                kind: .availabilityWindow,
                startDate: startDate,
                durationMinutes: availabilityWindowDuration(start: startDate, end: endDate),
                task: task,
                calendar: calendar
            )
        }

        guard
            let occurrence = RoutineDateMath.scheduledOccurrence(
                for: task,
                on: date,
                calendar: calendar
            )
        else {
            return nil
        }
        let rangeStart = timeRange.startDate(on: occurrence, calendar: calendar)
        let windowDuration = availabilityWindowDuration(
            start: rangeStart,
            end: timeRange.endDate(on: rangeStart, calendar: calendar)
        )
        return placement(
            kind: .availabilityWindow,
            startDate: rangeStart,
            durationMinutes: task.estimatedDurationMinutes ?? windowDuration,
            task: task,
            calendar: calendar
        )
    }

    private static func placement(
        kind: Placement.Kind,
        startDate: Date,
        durationMinutes: Int?,
        task: RoutineTask,
        calendar: Calendar
    ) -> Placement {
        let startMinute = startMinute(for: startDate, calendar: calendar)
        return Placement(
            kind: kind,
            startMinute: startMinute,
            durationMinutes: DayPlanBlock.clampedDuration(
                durationMinutes ?? task.estimatedDurationMinutes ?? 60,
                startMinute: startMinute,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            )
        )
    }

    private static func date(forDayKey dayKey: String, calendar: Calendar) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(
            from: DateComponents(year: parts[0], month: parts[1], day: parts[2])
        )
    }

    private static func startMinute(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        return DayPlanBlock.clampedStartMinute(minute)
    }

    private static func availabilityWindowDuration(start: Date, end: Date) -> Int? {
        guard end > start else { return nil }
        return max(
            Int((end.timeIntervalSince(start) / 60).rounded()),
            DayPlanBlock.minimumDurationMinutes
        )
    }

    private static func isDateWithinAvailabilityDateBounds(
        _ date: Date,
        for task: RoutineTask,
        calendar: Calendar
    ) -> Bool {
        guard let availabilityStartDate = task.availabilityStartDate else { return false }
        let day = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: availabilityStartDate)
        let endDay = calendar.startOfDay(for: task.availabilityEndDate ?? availabilityStartDate)
        return day >= startDay && day <= endDay
    }

    private static func hasExplicitTime(_ date: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        return (components.hour ?? 0) != 0
            || (components.minute ?? 0) != 0
            || (components.second ?? 0) != 0
            || (components.nanosecond ?? 0) != 0
    }
}

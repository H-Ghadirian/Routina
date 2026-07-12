import Foundation

enum AddRoutineScheduleEditor {
    static func setScheduleMode(
        _ mode: RoutineScheduleMode,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.scheduleMode = mode
    }

    static func setFrequency(
        _ frequency: AddRoutineFeature.Frequency,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.frequency = frequency
    }

    static func setFrequencyValue(
        _ value: Int,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.frequencyValue = value
    }

    static func setRecurrenceKind(
        _ kind: RoutineRecurrenceRule.Kind,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.recurrenceKind = kind
    }

    static func setRecurrenceHasExplicitTime(
        _ hasExplicitTime: Bool,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.recurrenceHasExplicitTime = hasExplicitTime
        if hasExplicitTime {
            schedule.recurrenceHasTimeRange = false
        }
    }

    static func setRecurrenceHasTimeRange(
        _ hasTimeRange: Bool,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.recurrenceHasTimeRange = hasTimeRange
        if hasTimeRange {
            schedule.recurrenceHasExplicitTime = false
        } else {
            schedule.recurrenceTimeRangeRole = .availability
        }
    }

    static func setRecurrenceTimeRangeRole(
        _ role: RoutineTimeRangeRole,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.recurrenceTimeRangeRole = role
    }

    static func setRecurrenceTimeOfDay(
        _ timeOfDay: RoutineTimeOfDay,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.recurrenceTimeOfDay = timeOfDay
    }

    static func setRecurrenceTimeRangeStart(
        _ timeOfDay: RoutineTimeOfDay,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.recurrenceTimeRangeStart = timeOfDay
    }

    static func setRecurrenceTimeRangeEnd(
        _ timeOfDay: RoutineTimeOfDay,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.recurrenceTimeRangeEnd = timeOfDay
    }

    static func setRecurrenceWeekday(
        _ weekday: Int,
        schedule: inout AddRoutineScheduleState
    ) {
        let selectedWeekday = min(max(weekday, 1), 7)
        schedule.recurrenceWeekday = selectedWeekday
        schedule.recurrenceWeekdays = [selectedWeekday]
    }

    static func setRecurrenceWeekdays(
        _ weekdays: [Int],
        schedule: inout AddRoutineScheduleState
    ) {
        let selectedWeekdays = Array(Set(weekdays.map { min(max($0, 1), 7) })).sorted()
        schedule.recurrenceWeekdays = selectedWeekdays
        if let firstWeekday = selectedWeekdays.first {
            schedule.recurrenceWeekday = firstWeekday
        }
    }

    static func setRecurrenceDayOfMonth(
        _ dayOfMonth: Int,
        schedule: inout AddRoutineScheduleState
    ) {
        let selectedDay = min(max(dayOfMonth, 1), 31)
        schedule.recurrenceDayOfMonth = selectedDay
        schedule.recurrenceDaysOfMonth = [selectedDay]
    }

    static func setRecurrenceDaysOfMonth(
        _ daysOfMonth: [Int],
        schedule: inout AddRoutineScheduleState
    ) {
        let selectedDays = Array(Set(daysOfMonth.map { min(max($0, 1), 31) })).sorted()
        schedule.recurrenceDaysOfMonth = selectedDays
        if let firstDay = selectedDays.first {
            schedule.recurrenceDayOfMonth = firstDay
        }
    }
}

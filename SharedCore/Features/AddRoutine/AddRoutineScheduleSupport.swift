import Foundation

enum AddRoutineScheduleEditor {
    static func setScheduleMode(
        _ mode: RoutineScheduleMode,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.scheduleMode = mode
        if mode.isSoftIntervalRoutine {
            schedule.recurrenceKind = .intervalDays
            schedule.recurrenceHasExplicitTime = false
            schedule.recurrenceHasTimeRange = false
        }
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
        }
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
        schedule.recurrenceWeekday = min(max(weekday, 1), 7)
    }

    static func setRecurrenceDayOfMonth(
        _ dayOfMonth: Int,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.recurrenceDayOfMonth = min(max(dayOfMonth, 1), 31)
    }
}

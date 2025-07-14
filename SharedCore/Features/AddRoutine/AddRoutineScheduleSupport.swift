import Foundation

enum AddRoutineScheduleEditor {
    static func setScheduleMode(
        _ mode: RoutineScheduleMode,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.scheduleMode = mode
        if mode == .softInterval {
            schedule.recurrenceKind = .intervalDays
            schedule.recurrenceHasExplicitTime = false
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
        let previousHasExplicitTime = schedule.recurrenceHasExplicitTime
        schedule.recurrenceKind = kind
        switch kind {
        case .intervalDays:
            schedule.recurrenceHasExplicitTime = false
        case .dailyTime:
            schedule.recurrenceHasExplicitTime = true
        case .weekly, .monthlyDay:
            schedule.recurrenceHasExplicitTime = previousHasExplicitTime
        }
    }

    static func setRecurrenceHasExplicitTime(
        _ hasExplicitTime: Bool,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.recurrenceHasExplicitTime = hasExplicitTime
    }

    static func setRecurrenceTimeOfDay(
        _ timeOfDay: RoutineTimeOfDay,
        schedule: inout AddRoutineScheduleState
    ) {
        schedule.recurrenceTimeOfDay = timeOfDay
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

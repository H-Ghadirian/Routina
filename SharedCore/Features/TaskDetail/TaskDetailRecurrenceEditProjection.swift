import Foundation

enum TaskDetailRecurrenceEditProjection {
    typealias State = TaskDetailFeature.State

    static func applyCadence(
        _ cadence: RoutineRecurrenceDraft.Cadence,
        state: inout State
    ) {
        guard state.editScheduleMode.taskType != .todo else { return }

        switch cadence {
        case .none:
            state.editCadenceEnabled = false
            state.editAutoPauseAfterCompletion = false
            state.editNudgesEnabled = false
            state.editScheduleMode = nonRunoutScheduleMode(from: state.editScheduleMode)

        case .manual:
            state.editCadenceEnabled = false
            state.editAutoPauseAfterCompletion = true
            state.editNudgesEnabled = false
            state.editScheduleMode = nonRunoutScheduleMode(from: state.editScheduleMode)

        case .itemRunout:
            state.editCadenceEnabled = true
            state.editAutoPauseAfterCompletion = false
            state.editScheduleMode = state.editScheduleMode.replacingChecklistTimingMode(.runout)

        case .afterCompletion, .scheduled:
            state.editCadenceEnabled = true
            state.editAutoPauseAfterCompletion = false
            state.editScheduleMode = nonRunoutScheduleMode(from: state.editScheduleMode)
        }
    }

    static func applyLegacyProjection(
        _ recurrenceDraft: RoutineRecurrenceDraft,
        recurrenceRule: RoutineRecurrenceRule,
        calendar: Calendar,
        state: inout State
    ) {
        if let advanced = recurrenceRule.advanced {
            state.editRecurrenceEditorMode = .advanced
            state.editAdvancedRecurrenceRule = advanced
        } else {
            state.editRecurrenceEditorMode = .simple
            state.editRecurrenceKind = recurrenceRule.kind
        }

        if recurrenceDraft.cadence == .afterCompletion {
            switch recurrenceDraft.frequency {
            case .daily:
                state.editFrequency = .day
            case .weekly:
                state.editFrequency = .week
            case .monthly:
                state.editFrequency = .month
            case .hourly, .yearly:
                break
            }
            state.editFrequencyValue = max(recurrenceDraft.interval, 1)
        }

        state.editRecurrenceHasExplicitTime = recurrenceDraft.availability.timeOfDay != nil
        state.editRecurrenceHasTimeRange = recurrenceDraft.availability.timeRange != nil
        state.editRecurrenceTimeRangeRole =
            recurrenceDraft.availability.timeRange == nil
            ? .availability
            : recurrenceDraft.timeRangeRole
        if let timeOfDay = recurrenceDraft.availability.timeOfDay {
            state.editIsAllDay = false
            state.editRecurrenceTimeOfDay = timeOfDay
        }
        if let timeRange = recurrenceDraft.availability.timeRange {
            state.editIsAllDay = false
            state.editRecurrenceTimeRangeStart = timeRange.start
            state.editRecurrenceTimeRangeEnd = timeRange.end
        }

        if recurrenceRule.kind == .weekly {
            state.editRecurrenceWeekdays = recurrenceRule.resolvedWeekdays(calendar: calendar)
            if let firstWeekday = state.editRecurrenceWeekdays.first {
                state.editRecurrenceWeekday = firstWeekday
            }
        }
        if recurrenceRule.kind == .monthlyDay {
            state.editRecurrenceDaysOfMonth = recurrenceRule.resolvedDaysOfMonth(calendar: calendar)
            if let firstDay = state.editRecurrenceDaysOfMonth.first {
                state.editRecurrenceDayOfMonth = firstDay
            }
        }
    }

    private static func nonRunoutScheduleMode(
        from scheduleMode: RoutineScheduleMode
    ) -> RoutineScheduleMode {
        guard scheduleMode.isChecklistDrivenMode else { return scheduleMode }
        return RoutineScheduleMode.routineMode(
            behavior: scheduleMode.scheduleBehavior,
            format: .checklist
        )
    }
}

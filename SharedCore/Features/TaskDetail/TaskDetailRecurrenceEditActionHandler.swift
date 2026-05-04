import ComposableArchitecture
import Foundation

struct TaskDetailRecurrenceEditActionHandler {
    typealias State = TaskDetailFeature.State
    typealias Action = TaskDetailFeature.Action

    var now: () -> Date
    var calendar: Calendar

    func editDeadlineEnabledChanged(_ isEnabled: Bool, state: inout State) -> Effect<Action> {
        state.editDeadline = isEnabled ? (state.editDeadline ?? now()) : nil
        return .none
    }

    func editDeadlineDateChanged(_ deadline: Date, state: inout State) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editDeadline = deadline
        }
        return .none
    }

    func editReminderEnabledChanged(_ isEnabled: Bool, state: inout State) -> Effect<Action> {
        state.editReminderAt = isEnabled
            ? (state.editReminderAt ?? editReminderEventDate(for: state) ?? now())
            : nil
        return .none
    }

    func editReminderDateChanged(_ reminderDate: Date, state: inout State) -> Effect<Action> {
        state.editReminderAt = reminderDate
        return .none
    }

    func editReminderLeadMinutesChanged(
        _ leadMinutes: Int?,
        state: inout State
    ) -> Effect<Action> {
        guard let leadMinutes,
              let eventDate = editReminderEventDate(for: state) else {
            return .none
        }
        state.editReminderAt = TaskFormReminderLeadTime.reminderDate(
            eventDate: eventDate,
            leadMinutes: leadMinutes
        )
        return .none
    }

    func editScheduleModeChanged(_ mode: RoutineScheduleMode, state: inout State) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editScheduleMode = mode
            if mode != .oneOff {
                state.editDeadline = nil
            }
            if mode == .softInterval {
                state.editRecurrenceKind = .intervalDays
                state.editRecurrenceHasExplicitTime = false
            }
        }
        disableAutoAssumeIfNeeded(state: &state)
        return .none
    }

    func editFrequencyChanged(_ frequency: TaskDetailFeature.EditFrequency, state: inout State) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editFrequency = frequency
        }
        disableAutoAssumeIfNeeded(state: &state)
        return .none
    }

    func editFrequencyValueChanged(_ value: Int, state: inout State) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editFrequencyValue = value
        }
        disableAutoAssumeIfNeeded(state: &state)
        return .none
    }

    func editRecurrenceKindChanged(
        _ kind: RoutineRecurrenceRule.Kind,
        state: inout State
    ) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            let previousHasExplicitTime = state.editRecurrenceHasExplicitTime
            state.editRecurrenceKind = kind
            switch kind {
            case .intervalDays:
                state.editRecurrenceHasExplicitTime = false
            case .dailyTime:
                state.editRecurrenceHasExplicitTime = true
            case .weekly, .monthlyDay:
                state.editRecurrenceHasExplicitTime = previousHasExplicitTime
            }
        }
        disableAutoAssumeIfNeeded(state: &state)
        return .none
    }

    func editRecurrenceHasExplicitTimeChanged(
        _ hasExplicitTime: Bool,
        state: inout State
    ) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editRecurrenceHasExplicitTime = hasExplicitTime
        }
        return .none
    }

    func editRecurrenceTimeOfDayChanged(
        _ timeOfDay: RoutineTimeOfDay,
        state: inout State
    ) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editRecurrenceTimeOfDay = timeOfDay
        }
        disableAutoAssumeIfNeeded(state: &state)
        return .none
    }

    func editRecurrenceWeekdayChanged(_ weekday: Int, state: inout State) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editRecurrenceWeekday = min(max(weekday, 1), 7)
        }
        return .none
    }

    func editRecurrenceDayOfMonthChanged(_ dayOfMonth: Int, state: inout State) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editRecurrenceDayOfMonth = min(max(dayOfMonth, 1), 31)
        }
        return .none
    }

    func editAutoAssumeDailyDoneChanged(_ isEnabled: Bool, state: inout State) -> Effect<Action> {
        state.editAutoAssumeDailyDone = isEnabled && state.canAutoAssumeDailyDone
        return .none
    }

    private func rebaseEditReminderIfUsingLeadTime(
        _ state: inout State,
        mutate: (inout State) -> Void
    ) {
        let leadMinutes = TaskFormReminderLeadTime.matchedLeadMinutes(
            eventDate: editReminderEventDate(for: state),
            reminderAt: state.editReminderAt
        )

        mutate(&state)

        guard let leadMinutes,
              let eventDate = editReminderEventDate(for: state) else {
            return
        }

        state.editReminderAt = TaskFormReminderLeadTime.reminderDate(
            eventDate: eventDate,
            leadMinutes: leadMinutes
        )
    }

    private func editReminderEventDate(for state: State) -> Date? {
        TaskFormReminderLeadTime.eventDate(
            scheduleMode: state.editScheduleMode,
            deadline: state.editDeadline,
            recurrenceRule: state.candidateRecurrenceRule,
            referenceDate: now(),
            calendar: calendar
        )
    }

    private func disableAutoAssumeIfNeeded(state: inout State) {
        if !state.canAutoAssumeDailyDone {
            state.editAutoAssumeDailyDone = false
        }
    }
}

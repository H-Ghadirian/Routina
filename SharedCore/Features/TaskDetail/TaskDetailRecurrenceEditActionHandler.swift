import ComposableArchitecture
import Foundation

struct TaskDetailRecurrenceEditActionHandler {
    typealias State = TaskDetailFeature.State
    typealias Action = TaskDetailFeature.Action

    var now: () -> Date
    var calendar: Calendar

    func editDeadlineEnabledChanged(_ isEnabled: Bool, state: inout State) -> Effect<Action> {
        if isEnabled {
            let deadline = state.editDeadline ?? now()
            state.editDeadline = state.editIsAllDay ? calendar.startOfDay(for: deadline) : deadline
        } else {
            state.editDeadline = nil
        }
        return .none
    }

    func editDeadlineDateChanged(_ deadline: Date, state: inout State) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editDeadline = state.editIsAllDay
                ? calendar.startOfDay(for: deadline)
                : deadline
        }
        return .none
    }

    func editAllDayChanged(_ isAllDay: Bool, state: inout State) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editIsAllDay = isAllDay
            if isAllDay, state.editScheduleMode == .oneOff, let deadline = state.editDeadline {
                state.editDeadline = calendar.startOfDay(for: deadline)
            }
            if isAllDay {
                state.editRecurrenceHasExplicitTime = false
                state.editRecurrenceHasTimeRange = false
                state.editRecurrenceTimeRangeRole = .availability
            }
        }
        disableAutoAssumeIfNeeded(state: &state)
        return .none
    }

    func editRoutineDurationModeChanged(
        _ durationMode: RoutineDurationMode,
        state: inout State
    ) -> Effect<Action> {
        state.editRoutineDurationMode = state.editScheduleMode.taskType == .todo ? .oneDay : durationMode
        enforceRecurrenceConstraints(state: &state)
        clearPlanningIfDailyRoutine(state: &state)
        return .none
    }

    func editAvailabilityStartDateChanged(_ availabilityStartDate: Date?, state: inout State) -> Effect<Action> {
        let bounds = RoutineTask.normalizedAvailabilityDateBounds(
            startDate: availabilityStartDate,
            endDate: state.editAvailabilityEndDate,
            calendar: calendar
        )
        state.editAvailabilityStartDate = bounds.startDate
        state.editAvailabilityEndDate = bounds.endDate
        return .none
    }

    func editAvailabilityEndDateChanged(_ availabilityEndDate: Date?, state: inout State) -> Effect<Action> {
        let bounds = RoutineTask.normalizedAvailabilityDateBounds(
            startDate: state.editAvailabilityStartDate,
            endDate: availabilityEndDate,
            calendar: calendar
        )
        state.editAvailabilityStartDate = bounds.startDate
        state.editAvailabilityEndDate = bounds.endDate
        return .none
    }

    func editPlannedDateChanged(_ plannedDate: Date?, state: inout State) -> Effect<Action> {
        state.editPlannedDate = supportsPlanning(state)
            ? RoutineTask.normalizedPlannedDate(plannedDate, calendar: calendar)
            : nil
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
                state.editAvailabilityStartDate = nil
                state.editAvailabilityEndDate = nil
            }
            if mode.taskType != .todo {
                state.editReminderAt = nil
            }
            if mode.taskType == .todo {
                state.editRoutineDurationMode = .oneDay
            }
            enforceRecurrenceConstraints(state: &state)
        }
        if state.editChecklistValidationMessage != nil {
            state.editChecklistValidationMessage = AddRoutineChecklistValidator.validationMessage(
                scheduleMode: state.editScheduleMode,
                checklistItems: state.editRoutineChecklistItems,
                checklistItemDraftTitle: state.editChecklistItemDraftTitle
            )
        }
        disableAutoAssumeIfNeeded(state: &state)
        clearPlanningIfDailyRoutine(state: &state)
        return .none
    }

    func editFrequencyChanged(_ frequency: TaskDetailFeature.EditFrequency, state: inout State) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editFrequency = frequency
            enforceRecurrenceConstraints(state: &state)
        }
        disableAutoAssumeIfNeeded(state: &state)
        clearPlanningIfDailyRoutine(state: &state)
        return .none
    }

    func editFrequencyValueChanged(_ value: Int, state: inout State) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editFrequencyValue = value
            enforceRecurrenceConstraints(state: &state)
        }
        disableAutoAssumeIfNeeded(state: &state)
        clearPlanningIfDailyRoutine(state: &state)
        return .none
    }

    func editRecurrenceKindChanged(
        _ kind: RoutineRecurrenceRule.Kind,
        state: inout State
    ) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editRecurrenceKind = kind
            enforceRecurrenceConstraints(state: &state)
        }
        disableAutoAssumeIfNeeded(state: &state)
        clearPlanningIfDailyRoutine(state: &state)
        return .none
    }

    func editRecurrenceHasExplicitTimeChanged(
        _ hasExplicitTime: Bool,
        state: inout State
    ) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editRecurrenceHasExplicitTime = hasExplicitTime
            if hasExplicitTime {
                state.editRecurrenceHasTimeRange = false
                state.editRecurrenceTimeRangeRole = .availability
            }
        }
        return .none
    }

    func editRecurrenceHasTimeRangeChanged(
        _ hasTimeRange: Bool,
        state: inout State
    ) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editRecurrenceHasTimeRange = hasTimeRange
            if hasTimeRange {
                state.editRecurrenceHasExplicitTime = false
            } else {
                state.editRecurrenceTimeRangeRole = .availability
            }
        }
        disableAutoAssumeIfNeeded(state: &state)
        return .none
    }

    func editRecurrenceTimeRangeRoleChanged(
        _ role: RoutineTimeRangeRole,
        state: inout State
    ) -> Effect<Action> {
        state.editRecurrenceTimeRangeRole = role
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

    func editRecurrenceTimeRangeStartChanged(
        _ timeOfDay: RoutineTimeOfDay,
        state: inout State
    ) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editRecurrenceTimeRangeStart = timeOfDay
        }
        disableAutoAssumeIfNeeded(state: &state)
        return .none
    }

    func editRecurrenceTimeRangeEndChanged(
        _ timeOfDay: RoutineTimeOfDay,
        state: inout State
    ) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            state.editRecurrenceTimeRangeEnd = timeOfDay
        }
        disableAutoAssumeIfNeeded(state: &state)
        return .none
    }

    func editRecurrenceWeekdayChanged(_ weekday: Int, state: inout State) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            let selectedWeekday = min(max(weekday, 1), 7)
            state.editRecurrenceWeekday = selectedWeekday
            state.editRecurrenceWeekdays = [selectedWeekday]
        }
        return .none
    }

    func editRecurrenceWeekdaysChanged(_ weekdays: [Int], state: inout State) -> Effect<Action> {
        rebaseEditReminderIfUsingLeadTime(&state) { state in
            let selectedWeekdays = Array(Set(weekdays.map { min(max($0, 1), 7) })).sorted()
            state.editRecurrenceWeekdays = selectedWeekdays
            if let firstWeekday = selectedWeekdays.first {
                state.editRecurrenceWeekday = firstWeekday
            }
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

    func editAutoAssumeDoneTimeOfDayChanged(
        _ timeOfDay: RoutineTimeOfDay,
        state: inout State
    ) -> Effect<Action> {
        state.editAutoAssumeDoneTimeOfDay = timeOfDay
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

    private func supportsPlanning(_ state: State) -> Bool {
        RoutineTaskPlanningSupport.supportsStoredPlanning(
            scheduleMode: state.editScheduleMode,
            recurrenceRule: state.candidateRecurrenceRule,
            checklistItems: candidateChecklistItems(for: state),
            trackingCadenceEnabled: state.editScheduleMode.taskType == .record
                ? state.editTrackingCadenceEnabled
                : true
        )
    }

    private func clearPlanningIfDailyRoutine(state: inout State) {
        if !supportsPlanning(state) {
            state.editPlannedDate = nil
        }
    }

    private func candidateChecklistItems(for state: State) -> [RoutineChecklistItem] {
        if let pendingTitle = RoutineChecklistItem.normalizedTitle(state.editChecklistItemDraftTitle) {
            return state.editRoutineChecklistItems + [
                RoutineChecklistItem(
                    title: pendingTitle,
                    intervalDays: state.editScheduleMode.normalizedChecklistItemIntervalDays(
                        state.editChecklistItemDraftInterval
                    )
                )
            ]
        }
        return state.editRoutineChecklistItems
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

    private func enforceRecurrenceConstraints(state: inout State) {
        if state.editRoutineDurationMode == .multiDay,
           state.editRecurrenceKind == .dailyTime {
            state.editRecurrenceKind = .intervalDays
        }
        state.editFrequencyValue = TaskFormRecurrenceConstraints.clampedFrequencyValue(
            state.editFrequencyValue,
            scheduleMode: state.editScheduleMode,
            routineDurationMode: state.editRoutineDurationMode,
            recurrenceKind: state.editRecurrenceKind,
            frequencyUnit: state.editFrequency
        )
    }
}

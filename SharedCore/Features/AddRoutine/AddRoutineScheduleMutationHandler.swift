import Foundation

struct AddRoutineScheduleMutationHandler {
    let now: () -> Date
    var calendar: Calendar = .current

    func setTaskType(
        _ taskType: RoutineTaskType,
        state: inout AddRoutineFeature.State
    ) {
        var basics = state.basics
        var schedule = state.schedule
        AddRoutineFormEditor.setTaskType(
            taskType,
            basics: &basics,
            schedule: &schedule
        )
        state.basics = basics
        state.schedule = schedule
        if taskType == .todo {
            state.basics.autoPauseAfterCompletion = false
        }
        synchronizeRecurrenceDraft(state: &state)
        enforceAutoAssumeEligibility(state: &state)
    }

    func setScheduleMode(
        _ mode: RoutineScheduleMode,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setScheduleMode(
            mode,
            schedule: &state.schedule
        )
        if mode.taskType == .todo {
            state.basics.routineDurationMode = .oneDay
            state.basics.autoPauseAfterCompletion = false
        }
        if mode.taskType == .record {
            state.basics.deadline = nil
            state.basics.availabilityStartDate = nil
            state.basics.availabilityEndDate = nil
            state.basics.reminderAt = nil
        }
        normalizeChecklistItemIntervals(state: &state)
        enforceRecurrenceConstraints(state: &state)
        synchronizeRecurrenceDraft(state: &state)
        enforceAutoAssumeEligibility(state: &state)
    }

    func addStep(state: inout AddRoutineFeature.State) {
        AddRoutineChecklistEditor.addStep(
            checklist: &state.checklist
        )
        enforceAutoAssumeEligibility(state: &state)
    }

    func removeStep(
        _ stepID: UUID,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineChecklistEditor.removeStep(
            stepID,
            checklist: &state.checklist
        )
        enforceAutoAssumeEligibility(state: &state)
    }

    func addChecklistItem(state: inout AddRoutineFeature.State) {
        AddRoutineChecklistEditor.addChecklistItem(
            createdAt: now(),
            scheduleMode: state.schedule.scheduleMode,
            checklist: &state.checklist
        )
        enforceAutoAssumeEligibility(state: &state)
    }

    func removeChecklistItem(
        _ itemID: UUID,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineChecklistEditor.removeChecklistItem(
            itemID,
            checklist: &state.checklist
        )
        enforceAutoAssumeEligibility(state: &state)
    }

    func setFrequency(
        _ frequency: AddRoutineFeature.Frequency,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setFrequency(
            frequency,
            schedule: &state.schedule
        )
        enforceRecurrenceConstraints(state: &state)
        synchronizeRecurrenceDraft(state: &state)
        enforceAutoAssumeEligibility(state: &state)
    }

    func setFrequencyValue(
        _ value: Int,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setFrequencyValue(
            value,
            schedule: &state.schedule
        )
        enforceRecurrenceConstraints(state: &state)
        synchronizeRecurrenceDraft(state: &state)
        enforceAutoAssumeEligibility(state: &state)
    }

    func setRecurrenceEditorMode(
        _ mode: RoutineRecurrenceEditorMode,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setRecurrenceEditorMode(mode, schedule: &state.schedule)
        if mode == .advanced {
            state.basics.trackingCadenceEnabled = true
            state.basics.autoPauseAfterCompletion = false
        }
        synchronizeRecurrenceDraft(state: &state)
        enforceAutoAssumeEligibility(state: &state)
    }

    func setAdvancedRecurrenceRule(
        _ rule: RoutineAdvancedRecurrenceRule,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setAdvancedRecurrenceRule(rule, schedule: &state.schedule)
        synchronizeRecurrenceDraft(state: &state)
        enforceAutoAssumeEligibility(state: &state)
    }

    func setRecurrenceKind(
        _ kind: RoutineRecurrenceRule.Kind,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setRecurrenceKind(
            kind,
            schedule: &state.schedule
        )
        enforceRecurrenceConstraints(state: &state)
        synchronizeRecurrenceDraft(state: &state)
        enforceAutoAssumeEligibility(state: &state)
    }

    func setRecurrenceHasExplicitTime(
        _ hasExplicitTime: Bool,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setRecurrenceHasExplicitTime(
            hasExplicitTime,
            schedule: &state.schedule
        )
        synchronizeRecurrenceDraft(state: &state)
        enforceAutoAssumeEligibility(state: &state)
    }

    func setRecurrenceHasTimeRange(
        _ hasTimeRange: Bool,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setRecurrenceHasTimeRange(
            hasTimeRange,
            schedule: &state.schedule
        )
        synchronizeRecurrenceDraft(state: &state)
        enforceAutoAssumeEligibility(state: &state)
    }

    func setRecurrenceTimeRangeRole(
        _ role: RoutineTimeRangeRole,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setRecurrenceTimeRangeRole(
            role,
            schedule: &state.schedule
        )
        synchronizeRecurrenceDraft(state: &state)
    }

    func setRecurrenceTimeOfDay(
        _ timeOfDay: RoutineTimeOfDay,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setRecurrenceTimeOfDay(
            timeOfDay,
            schedule: &state.schedule
        )
        synchronizeRecurrenceDraft(state: &state)
        enforceAutoAssumeEligibility(state: &state)
    }

    func setRecurrenceTimeRangeStart(
        _ timeOfDay: RoutineTimeOfDay,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setRecurrenceTimeRangeStart(
            timeOfDay,
            schedule: &state.schedule
        )
        synchronizeRecurrenceDraft(state: &state)
        enforceAutoAssumeEligibility(state: &state)
    }

    func setRecurrenceTimeRangeEnd(
        _ timeOfDay: RoutineTimeOfDay,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setRecurrenceTimeRangeEnd(
            timeOfDay,
            schedule: &state.schedule
        )
        synchronizeRecurrenceDraft(state: &state)
        enforceAutoAssumeEligibility(state: &state)
    }

    func setRecurrenceWeekday(
        _ weekday: Int,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setRecurrenceWeekday(
            weekday,
            schedule: &state.schedule
        )
        synchronizeRecurrenceDraft(state: &state)
    }

    func setRecurrenceWeekdays(
        _ weekdays: [Int],
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setRecurrenceWeekdays(
            weekdays,
            schedule: &state.schedule
        )
        synchronizeRecurrenceDraft(state: &state)
    }

    func setRecurrenceDayOfMonth(
        _ dayOfMonth: Int,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setRecurrenceDayOfMonth(
            dayOfMonth,
            schedule: &state.schedule
        )
        synchronizeRecurrenceDraft(state: &state)
    }

    func setRecurrenceDaysOfMonth(
        _ daysOfMonth: [Int],
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setRecurrenceDaysOfMonth(
            daysOfMonth,
            schedule: &state.schedule
        )
        synchronizeRecurrenceDraft(state: &state)
    }

    func setRecurrenceDraft(
        _ recurrenceDraft: RoutineRecurrenceDraft,
        state: inout AddRoutineFeature.State
    ) {
        let recurrenceDraft = recurrenceDraft.normalized()
        state.schedule.recurrenceDraft = recurrenceDraft
        state.schedule.recurrenceDraftIsAuthoritative = true
        state.basics.autoPauseAfterCompletion = recurrenceDraft.cadence == .manual
        applyCadence(recurrenceDraft.cadence, state: &state)

        guard let recurrenceRule = recurrenceDraft.resolvedRecurrenceRule(calendar: calendar) else {
            enforceAutoAssumeEligibility(state: &state)
            return
        }

        applyLegacyProjection(
            recurrenceDraft,
            recurrenceRule: recurrenceRule,
            state: &state
        )
        enforceRecurrenceConstraints(state: &state)
        enforceAutoAssumeEligibility(state: &state)
    }

    func setAutoAssumeDailyDone(
        _ isEnabled: Bool,
        state: inout AddRoutineFeature.State
    ) {
        state.schedule.autoAssumeDailyDone = isEnabled && state.canAutoAssumeDailyDone
        if !state.schedule.autoAssumeDailyDone {
            state.schedule.hidesAssumedDoneCalendarBlock = false
        }
    }

    func setHidesAssumedDoneCalendarBlock(
        _ isEnabled: Bool,
        state: inout AddRoutineFeature.State
    ) {
        state.schedule.hidesAssumedDoneCalendarBlock = isEnabled
            && state.schedule.autoAssumeDailyDone
    }

    func setAutoAssumeDoneTimeOfDay(
        _ timeOfDay: RoutineTimeOfDay,
        state: inout AddRoutineFeature.State
    ) {
        state.schedule.autoAssumeDoneTimeOfDay = timeOfDay
    }

    private func enforceAutoAssumeEligibility(state: inout AddRoutineFeature.State) {
        guard !state.canAutoAssumeDailyDone else { return }
        state.schedule.autoAssumeDailyDone = false
        state.schedule.hidesAssumedDoneCalendarBlock = false
    }

    private func synchronizeRecurrenceDraft(state: inout AddRoutineFeature.State) {
        state.synchronizeRecurrenceDraftFromLegacy()
    }

    private func applyCadence(
        _ cadence: RoutineRecurrenceDraft.Cadence,
        state: inout AddRoutineFeature.State
    ) {
        guard state.schedule.scheduleMode.taskType != .todo else { return }

        switch cadence {
        case .none:
            state.basics.trackingCadenceEnabled = false
            state.basics.autoPauseAfterCompletion = false
            state.basics.trackingNudgesEnabled = false
            state.schedule.scheduleMode = nonRunoutScheduleMode(from: state.schedule.scheduleMode)

        case .manual:
            state.basics.trackingCadenceEnabled = false
            state.basics.autoPauseAfterCompletion = true
            state.basics.trackingNudgesEnabled = false
            state.schedule.scheduleMode = nonRunoutScheduleMode(from: state.schedule.scheduleMode)

        case .itemRunout:
            state.basics.trackingCadenceEnabled = true
            state.basics.autoPauseAfterCompletion = false
            state.schedule.scheduleMode = state.schedule.scheduleMode.replacingChecklistTimingMode(.runout)

        case .afterCompletion, .scheduled:
            state.basics.trackingCadenceEnabled = true
            state.basics.autoPauseAfterCompletion = false
            state.schedule.scheduleMode = nonRunoutScheduleMode(from: state.schedule.scheduleMode)
        }
    }

    private func applyLegacyProjection(
        _ recurrenceDraft: RoutineRecurrenceDraft,
        recurrenceRule: RoutineRecurrenceRule,
        state: inout AddRoutineFeature.State
    ) {
        if let advanced = recurrenceRule.advanced {
            state.schedule.recurrenceEditorMode = .advanced
            state.schedule.advancedRecurrenceRule = advanced
        } else {
            state.schedule.recurrenceEditorMode = .simple
            state.schedule.recurrenceKind = recurrenceRule.kind
        }

        if recurrenceDraft.cadence == .afterCompletion {
            switch recurrenceDraft.frequency {
            case .daily:
                state.schedule.frequency = .day
            case .weekly:
                state.schedule.frequency = .week
            case .monthly:
                state.schedule.frequency = .month
            case .hourly, .yearly:
                break
            }
            state.schedule.frequencyValue = max(recurrenceDraft.interval, 1)
        }

        state.schedule.recurrenceHasExplicitTime = recurrenceDraft.availability.timeOfDay != nil
        state.schedule.recurrenceHasTimeRange = recurrenceDraft.availability.timeRange != nil
        state.schedule.recurrenceTimeRangeRole = recurrenceDraft.availability.timeRange == nil
            ? .availability
            : recurrenceDraft.timeRangeRole
        if let timeOfDay = recurrenceDraft.availability.timeOfDay {
            state.basics.isAllDay = false
            state.schedule.recurrenceTimeOfDay = timeOfDay
        }
        if let timeRange = recurrenceDraft.availability.timeRange {
            state.basics.isAllDay = false
            state.schedule.recurrenceTimeRangeStart = timeRange.start
            state.schedule.recurrenceTimeRangeEnd = timeRange.end
        }

        if recurrenceRule.kind == .weekly {
            state.schedule.recurrenceWeekdays = recurrenceRule.resolvedWeekdays(calendar: calendar)
            if let firstWeekday = state.schedule.recurrenceWeekdays.first {
                state.schedule.recurrenceWeekday = firstWeekday
            }
        }
        if recurrenceRule.kind == .monthlyDay {
            state.schedule.recurrenceDaysOfMonth = recurrenceRule.resolvedDaysOfMonth(calendar: calendar)
            if let firstDay = state.schedule.recurrenceDaysOfMonth.first {
                state.schedule.recurrenceDayOfMonth = firstDay
            }
        }
    }

    private func nonRunoutScheduleMode(
        from scheduleMode: RoutineScheduleMode
    ) -> RoutineScheduleMode {
        guard scheduleMode.isChecklistDrivenMode else { return scheduleMode }
        if scheduleMode.taskType == .record {
            return .recordChecklist
        }
        return RoutineScheduleMode.routineMode(
            behavior: scheduleMode.scheduleBehavior,
            format: .checklist
        )
    }

    private func normalizeChecklistItemIntervals(state: inout AddRoutineFeature.State) {
        state.checklist.routineChecklistItems = RoutineChecklistItem.sanitized(
            state.checklist.routineChecklistItems,
            for: state.schedule.scheduleMode
        )
    }

    private func enforceRecurrenceConstraints(state: inout AddRoutineFeature.State) {
        if state.basics.routineDurationMode == .multiDay,
           state.schedule.recurrenceKind == .dailyTime {
            state.schedule.recurrenceKind = .intervalDays
        }
        state.schedule.frequencyValue = TaskFormRecurrenceConstraints.clampedFrequencyValue(
            state.schedule.frequencyValue,
            scheduleMode: state.schedule.scheduleMode,
            routineDurationMode: state.basics.routineDurationMode,
            recurrenceKind: state.schedule.recurrenceKind,
            frequencyUnit: state.schedule.frequency
        )
    }
}

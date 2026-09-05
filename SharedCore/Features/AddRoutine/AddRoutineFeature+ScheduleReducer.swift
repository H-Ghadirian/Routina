import ComposableArchitecture

extension AddRoutineFeature {
    func reduceScheduleModeActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        guard case let .scheduleModeChanged(mode) = action else { return .none }

        scheduleMutationHandler().setScheduleMode(mode, state: &state)
        if mode.taskType == .todo {
            state.basics.taskLadderGroupEnabled = false
        }
        if state.checklist.checklistValidationMessage != nil {
            AddRoutineValidationEditor.refreshChecklistValidation(state: &state)
        }
        enforcePlanningRules(state: &state)
        sanitizeTemporalWeightRule(state: &state)
        sanitizeTaskLadderEntryWindow(state: &state)
        return .none
    }

    func reduceScheduleStructureActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .stepDraftChanged(value):
            AddRoutineChecklistEditor.setStepDraft(
                value,
                checklist: &state.checklist
            )
            return .none
        case .addStepTapped:
            scheduleMutationHandler().addStep(state: &state)
            return .none
        case let .removeStep(stepID):
            scheduleMutationHandler().removeStep(stepID, state: &state)
            return .none
        case let .moveStepUp(stepID):
            AddRoutineChecklistEditor.moveStep(
                stepID,
                by: -1,
                checklist: &state.checklist
            )
            return .none
        case let .moveStepDown(stepID):
            AddRoutineChecklistEditor.moveStep(
                stepID,
                by: 1,
                checklist: &state.checklist
            )
            return .none
        case let .checklistItemDraftTitleChanged(value):
            AddRoutineChecklistEditor.setChecklistItemDraftTitle(
                value,
                checklist: &state.checklist
            )
            if state.checklist.checklistValidationMessage != nil {
                AddRoutineValidationEditor.refreshChecklistValidation(state: &state)
            }
            enforcePlanningRules(state: &state)
            return .none
        case let .checklistItemDraftIntervalChanged(value):
            AddRoutineChecklistEditor.setChecklistItemDraftInterval(
                value,
                checklist: &state.checklist
            )
            if state.checklist.checklistValidationMessage != nil {
                AddRoutineValidationEditor.refreshChecklistValidation(state: &state)
            }
            enforcePlanningRules(state: &state)
            return .none
        case .addChecklistItemTapped:
            scheduleMutationHandler().addChecklistItem(state: &state)
            AddRoutineValidationEditor.refreshChecklistValidation(state: &state)
            enforcePlanningRules(state: &state)
            return .none
        case let .removeChecklistItem(itemID):
            scheduleMutationHandler().removeChecklistItem(itemID, state: &state)
            if state.checklist.checklistValidationMessage != nil {
                AddRoutineValidationEditor.refreshChecklistValidation(state: &state)
            }
            enforcePlanningRules(state: &state)
            return .none
        default:
            return .none
        }
    }

    func reduceRecurrenceDefinitionActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .frequencyChanged(frequency):
            scheduleMutationHandler().setFrequency(frequency, state: &state)
            enforcePlanningRules(state: &state)
            return .none
        case let .frequencyValueChanged(value):
            scheduleMutationHandler().setFrequencyValue(value, state: &state)
            enforcePlanningRules(state: &state)
            return .none
        case let .recurrenceEditorModeChanged(mode):
            scheduleMutationHandler().setRecurrenceEditorMode(mode, state: &state)
            enforcePlanningRules(state: &state)
            return .none
        case let .advancedRecurrenceRuleChanged(rule):
            scheduleMutationHandler().setAdvancedRecurrenceRule(rule, state: &state)
            enforcePlanningRules(state: &state)
            return .none
        case let .recurrenceDraftChanged(recurrenceDraft):
            AddRoutineScheduleMutationHandler(
                now: { now },
                calendar: calendar
            ).setRecurrenceDraft(recurrenceDraft, state: &state)
            enforcePlanningRules(state: &state)
            return .none
        case let .recurrenceKindChanged(kind):
            scheduleMutationHandler().setRecurrenceKind(kind, state: &state)
            enforcePlanningRules(state: &state)
            return .none
        default:
            return .none
        }
    }

    func reduceRecurrenceTimingActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .recurrenceHasExplicitTimeChanged(hasExplicitTime):
            scheduleMutationHandler().setRecurrenceHasExplicitTime(hasExplicitTime, state: &state)
            return .none
        case let .recurrenceHasTimeRangeChanged(hasTimeRange):
            scheduleMutationHandler().setRecurrenceHasTimeRange(hasTimeRange, state: &state)
            return .none
        case let .recurrenceTimeRangeRoleChanged(role):
            scheduleMutationHandler().setRecurrenceTimeRangeRole(role, state: &state)
            return .none
        case let .recurrenceTimeOfDayChanged(timeOfDay):
            scheduleMutationHandler().setRecurrenceTimeOfDay(timeOfDay, state: &state)
            return .none
        case let .recurrenceTimeRangeStartChanged(timeOfDay):
            scheduleMutationHandler().setRecurrenceTimeRangeStart(timeOfDay, state: &state)
            return .none
        case let .recurrenceTimeRangeEndChanged(timeOfDay):
            scheduleMutationHandler().setRecurrenceTimeRangeEnd(timeOfDay, state: &state)
            return .none
        case let .recurrenceWeekdayChanged(weekday):
            scheduleMutationHandler().setRecurrenceWeekday(weekday, state: &state)
            return .none
        case let .recurrenceWeekdaysChanged(weekdays):
            scheduleMutationHandler().setRecurrenceWeekdays(weekdays, state: &state)
            enforcePlanningRules(state: &state)
            return .none
        case let .recurrenceDayOfMonthChanged(dayOfMonth):
            scheduleMutationHandler().setRecurrenceDayOfMonth(dayOfMonth, state: &state)
            return .none
        case let .recurrenceDaysOfMonthChanged(daysOfMonth):
            scheduleMutationHandler().setRecurrenceDaysOfMonth(daysOfMonth, state: &state)
            enforcePlanningRules(state: &state)
            return .none
        default:
            return .none
        }
    }

    func reduceAutoAssumeActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .autoAssumeDailyDoneChanged(isEnabled):
            scheduleMutationHandler().setAutoAssumeDailyDone(isEnabled, state: &state)
            return .none
        case let .hidesAssumedDoneCalendarBlockChanged(isEnabled):
            scheduleMutationHandler().setHidesAssumedDoneCalendarBlock(isEnabled, state: &state)
            return .none
        case let .autoAssumeDoneTimeOfDayChanged(timeOfDay):
            scheduleMutationHandler().setAutoAssumeDoneTimeOfDay(timeOfDay, state: &state)
            return .none
        default:
            return .none
        }
    }
}

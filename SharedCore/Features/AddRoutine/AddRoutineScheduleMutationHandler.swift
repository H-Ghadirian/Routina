import Foundation

struct AddRoutineScheduleMutationHandler {
    let now: () -> Date

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
        enforceAutoAssumeEligibility(state: &state)
    }

    func setRecurrenceTimeOfDay(
        _ timeOfDay: RoutineTimeOfDay,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setRecurrenceTimeOfDay(
            timeOfDay,
            schedule: &state.schedule
        )
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
    }

    func setRecurrenceDayOfMonth(
        _ dayOfMonth: Int,
        state: inout AddRoutineFeature.State
    ) {
        AddRoutineScheduleEditor.setRecurrenceDayOfMonth(
            dayOfMonth,
            schedule: &state.schedule
        )
    }

    func setAutoAssumeDailyDone(
        _ isEnabled: Bool,
        state: inout AddRoutineFeature.State
    ) {
        state.schedule.autoAssumeDailyDone = isEnabled && state.canAutoAssumeDailyDone
    }

    private func enforceAutoAssumeEligibility(state: inout AddRoutineFeature.State) {
        guard !state.canAutoAssumeDailyDone else { return }
        state.schedule.autoAssumeDailyDone = false
    }
}

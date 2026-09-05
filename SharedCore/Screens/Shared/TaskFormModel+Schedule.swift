import SwiftUI

extension TaskFormModel {
    var creationKind: Binding<TaskFormCreationKind> {
        let taskType = taskType
        return Binding(
            get: {
                taskType.wrappedValue == .todo ? .oneTime : .repeating
            },
            set: { kind in
                switch kind {
                case .oneTime:
                    taskType.wrappedValue = .todo
                case .repeating:
                    if taskType.wrappedValue == .todo {
                        taskType.wrappedValue = .routine
                    }
                }
            }
        )
    }

    var scheduleBehavior: Binding<RoutineScheduleBehavior> {
        let scheduleMode = scheduleMode
        return Binding(
            get: {
                scheduleMode.wrappedValue.scheduleBehavior
            },
            set: { behavior in
                scheduleMode.wrappedValue = RoutineScheduleMode.routineMode(
                    behavior: behavior,
                    format: scheduleMode.wrappedValue.routineFormat
                )
            }
        )
    }

    var routineFormat: Binding<RoutineFormat> {
        let scheduleMode = scheduleMode
        return Binding(
            get: {
                scheduleMode.wrappedValue.routineFormat
            },
            set: { format in
                scheduleMode.wrappedValue = RoutineScheduleMode.routineMode(
                    behavior: scheduleMode.wrappedValue.scheduleBehavior,
                    format: format
                )
            }
        )
    }

    var routineFinishMode: Binding<RoutineFinishMode> {
        let scheduleMode = scheduleMode
        return Binding(
            get: {
                scheduleMode.wrappedValue.routineFinishMode
            },
            set: { finishMode in
                scheduleMode.wrappedValue = scheduleMode.wrappedValue.replacingRoutineFinishMode(finishMode)
            }
        )
    }

    var checklistTimingMode: Binding<ChecklistTimingMode> {
        let scheduleMode = scheduleMode
        return Binding(
            get: {
                scheduleMode.wrappedValue.checklistTimingMode
            },
            set: { timingMode in
                scheduleMode.wrappedValue = scheduleMode.wrappedValue.replacingChecklistTimingMode(timingMode)
            }
        )
    }

    var repeatBasis: Binding<RoutineRepeatBasis> {
        let recurrenceKind = recurrenceKind
        return Binding(
            get: {
                RoutineRecurrenceRule.Kind.calendarCases.contains(recurrenceKind.wrappedValue)
                    ? .calendar
                    : .interval
            },
            set: { basis in
                recurrenceKind.wrappedValue = recurrenceKind.wrappedValue.replacingRepeatBasis(basis)
            }
        )
    }

    var supportsItemRunoutRepeatType: Bool {
        (taskType.wrappedValue == .routine)
            && scheduleMode.wrappedValue.usesRoutineCadence
            && scheduleMode.wrappedValue.routineFinishMode == .checklist
    }

    var supportsAdvancedRecurrence: Bool {
        usesEffectiveRoutineCadence
            && !scheduleMode.wrappedValue.isChecklistDrivenMode
    }

    var usesEffectiveRoutineCadence: Bool {
        (taskType.wrappedValue == .routine)
            && scheduleMode.wrappedValue.usesRoutineCadence
            && cadenceEnabled.wrappedValue
    }

    var supportsRoutineScheduleBehavior: Bool {
        taskType.wrappedValue == .routine && usesEffectiveRoutineCadence
    }

    var supportsGentleNudges: Bool {
        usesEffectiveRoutineCadence
            && scheduleMode.wrappedValue.scheduleBehavior == .soft
    }

    var supportsRecurrenceAvailability: Bool {
        taskType.wrappedValue == .todo || usesEffectiveRoutineCadence
    }

    var routineRepeatTypeCases: [RoutineRepeatType] {
        RoutineRepeatType.cases(
            supportsNoRepeat: taskType.wrappedValue == .routine,
            supportsItemRunout: supportsItemRunoutRepeatType
        )
    }

    var routineRepeatType: Binding<RoutineRepeatType> {
        let taskType = taskType
        let scheduleMode = scheduleMode
        let recurrenceKind = recurrenceKind
        let cadenceEnabled = cadenceEnabled

        return Binding(
            get: {
                if taskType.wrappedValue == .routine,
                    !cadenceEnabled.wrappedValue
                {
                    return .none
                }

                if scheduleMode.wrappedValue.isChecklistDrivenMode {
                    return .itemRunout
                }

                return RoutineRecurrenceRule.Kind.calendarCases.contains(recurrenceKind.wrappedValue)
                    ? .calendar
                    : .interval
            },
            set: { repeatType in
                switch repeatType {
                case .none:
                    guard taskType.wrappedValue == .routine else { return }
                    cadenceEnabled.wrappedValue = false
                    if scheduleMode.wrappedValue.isChecklistDrivenMode {
                        scheduleMode.wrappedValue = Self.nonRunoutScheduleMode(from: scheduleMode.wrappedValue)
                    }

                case .interval:
                    cadenceEnabled.wrappedValue = true
                    if scheduleMode.wrappedValue.isChecklistDrivenMode {
                        scheduleMode.wrappedValue = Self.nonRunoutScheduleMode(from: scheduleMode.wrappedValue)
                    }
                    recurrenceKind.wrappedValue = recurrenceKind.wrappedValue.replacingRepeatBasis(.interval)

                case .calendar:
                    cadenceEnabled.wrappedValue = true
                    if scheduleMode.wrappedValue.isChecklistDrivenMode {
                        scheduleMode.wrappedValue = Self.nonRunoutScheduleMode(from: scheduleMode.wrappedValue)
                    }
                    recurrenceKind.wrappedValue = recurrenceKind.wrappedValue.replacingRepeatBasis(.calendar)

                case .itemRunout:
                    guard taskType.wrappedValue == .routine,
                        scheduleMode.wrappedValue.usesRoutineCadence,
                        scheduleMode.wrappedValue.routineFinishMode == .checklist
                    else { return }

                    cadenceEnabled.wrappedValue = true
                    scheduleMode.wrappedValue = RoutineScheduleMode.routineMode(
                        behavior: scheduleMode.wrappedValue.scheduleBehavior,
                        format: .runout
                    )
                }
            }
        )
    }

    var calendarRecurrenceKind: Binding<RoutineRecurrenceRule.Kind> {
        let recurrenceKind = recurrenceKind
        return Binding(
            get: {
                let currentKind = recurrenceKind.wrappedValue
                return RoutineRecurrenceRule.Kind.calendarCases.contains(currentKind) ? currentKind : .weekly
            },
            set: { kind in
                guard RoutineRecurrenceRule.Kind.calendarCases.contains(kind) else { return }
                recurrenceKind.wrappedValue = kind
            }
        )
    }

    var intervalFrequencyValueBounds: ClosedRange<Int> {
        TaskFormRecurrenceConstraints.frequencyValueBounds(
            scheduleMode: scheduleMode.wrappedValue,
            routineDurationMode: routineDurationMode.wrappedValue,
            recurrenceKind: recurrenceKind.wrappedValue,
            frequencyUnit: frequencyUnit.wrappedValue
        )
    }

    var canAutoAssumeDailyDone: Bool {
        recurrenceDraft.wrappedValue.validationIssue == nil
            && RoutineAssumedCompletion.canEnable(
                scheduleMode: scheduleMode.wrappedValue,
                recurrenceRule: candidateRecurrenceRule,
                recurrenceTimeRangeRole: recurrenceTimeRangeRole.wrappedValue,
                availabilityStartDate: availabilityStartDate.wrappedValue,
                availabilityEndDate: availabilityEndDate.wrappedValue,
                isAllDay: isAllDay.wrappedValue,
                cadenceEnabled: cadenceEnabled.wrappedValue,
                hasSequentialSteps: !routineSteps.isEmpty,
                hasChecklistItems: !routineChecklistItems.isEmpty
            )
    }

    var recurrenceValidationMessage: String? {
        recurrenceDraft.wrappedValue.validationIssue?.message
    }

    var maximumTemporalWeightBeforeDueDays: Int? {
        recurrenceDraft.wrappedValue.maximumTemporalWeightBeforeDueDays
    }

    var maximumTaskLadderEntryBeforeDueDays: Int? {
        taskType.wrappedValue == .todo
            ? nil
            : maximumTemporalWeightBeforeDueDays
    }

    var supportsExactDateReminder: Bool {
        taskType.wrappedValue == .todo
    }

    var supportsTemporalWeightValues: Bool {
        RoutineTaskTemporalWeightResolver.supportsTemporalWeight(
            scheduleMode: scheduleMode.wrappedValue,
            cadenceEnabled: cadenceEnabled.wrappedValue
        )
    }

    var supportsTaskLadderEntryWindow: Bool {
        RoutineTaskLadderEntryResolver.supportsEntryWindow(
            scheduleMode: scheduleMode.wrappedValue,
            cadenceEnabled: cadenceEnabled.wrappedValue,
            hasDeadline: deadlineEnabled.wrappedValue
        )
    }

    var temporalWeightAvailabilityMessage: String? {
        guard !supportsTemporalWeightValues else { return nil }
        let currentMode = scheduleMode.wrappedValue
        if currentMode.taskType == .todo {
            return "Available for repeating tasks."
        }
        if !currentMode.usesRoutineCadence || !cadenceEnabled.wrappedValue {
            return "Choose After done or On schedule in Behavior & Schedule."
        }
        if currentMode.scheduleBehavior != .fixed {
            return "Choose Due in Behavior & Schedule."
        }
        return "Choose a repeating Due schedule first."
    }

    var supportsPlanning: Bool {
        switch taskType.wrappedValue {
        case .todo:
            return true
        case .routine:
            return !isDailyRoutineDraft
        }
    }

    private var candidateRecurrenceRule: RoutineRecurrenceRule {
        let currentScheduleMode = scheduleMode.wrappedValue
        let usesAvailabilityTiming = !isAllDay.wrappedValue
        let timeRange =
            usesAvailabilityTiming && recurrenceHasTimeRange.wrappedValue
            ? RoutineTimeRange(
                start: RoutineTimeOfDay.from(recurrenceTimeRangeStart.wrappedValue),
                end: RoutineTimeOfDay.from(recurrenceTimeRangeEnd.wrappedValue)
            )
            : nil
        let timeOfDay =
            usesAvailabilityTiming && recurrenceHasExplicitTime.wrappedValue
            ? RoutineTimeOfDay.from(recurrenceTimeOfDay.wrappedValue)
            : nil

        switch currentScheduleMode.taskType {
        case .todo:
            return .interval(days: 1, at: timeOfDay, timeRange: timeRange)
        case .routine:
            break
        }

        guard !currentScheduleMode.isChecklistDrivenMode else {
            return .interval(days: max(effectiveIntervalDays, 1))
        }

        if recurrenceEditorMode.wrappedValue == .advanced {
            return .advanced(advancedRecurrenceRule.wrappedValue)
        }

        switch recurrenceKind.wrappedValue {
        case .intervalDays:
            return .interval(days: max(effectiveIntervalDays, 1), at: timeOfDay, timeRange: timeRange)
        case .dailyTime:
            if let timeRange {
                return .daily(in: timeRange)
            }
            return RoutineRecurrenceRule(kind: .dailyTime, timeOfDay: timeOfDay)
        case .weekly:
            return .weekly(on: effectiveRecurrenceWeekdays, at: timeOfDay, timeRange: timeRange)
        case .monthlyDay:
            return .monthly(on: effectiveRecurrenceDaysOfMonth, at: timeOfDay, timeRange: timeRange)
        }
    }

    private var effectiveIntervalDays: Int {
        TaskFormRecurrenceConstraints.effectiveIntervalDays(
            value: frequencyValue.wrappedValue,
            unit: frequencyUnit.wrappedValue,
            scheduleMode: scheduleMode.wrappedValue,
            routineDurationMode: routineDurationMode.wrappedValue,
            recurrenceKind: recurrenceKind.wrappedValue
        )
    }

    private var isDailyRoutineDraft: Bool {
        let currentScheduleMode = scheduleMode.wrappedValue
        guard usesEffectiveRoutineCadence else { return false }
        if currentScheduleMode.isChecklistDrivenMode {
            return RoutineTaskDailyRoutineSupport.hasDailyRunoutChecklistItem(candidateChecklistItems)
        }
        if recurrenceEditorMode.wrappedValue == .advanced {
            return advancedRecurrenceRule.wrappedValue.isDaily
        }
        switch recurrenceKind.wrappedValue {
        case .dailyTime:
            return true
        case .intervalDays:
            return frequencyUnit.wrappedValue == .day && frequencyValue.wrappedValue <= 1
        case .weekly, .monthlyDay:
            return false
        }
    }

    private var candidateChecklistItems: [RoutineChecklistItem] {
        if let pendingTitle = RoutineChecklistItem.normalizedTitle(checklistItemDraftTitle.wrappedValue) {
            return RoutineChecklistItem.sanitized(
                routineChecklistItems + [
                    RoutineChecklistItem(
                        title: pendingTitle,
                        intervalDays: scheduleMode.wrappedValue.normalizedChecklistItemIntervalDays(
                            checklistItemDraftInterval.wrappedValue
                        )
                    )
                ],
                for: scheduleMode.wrappedValue
            )
        }
        return RoutineChecklistItem.sanitized(routineChecklistItems, for: scheduleMode.wrappedValue)
    }

    private static func nonRunoutScheduleMode(from scheduleMode: RoutineScheduleMode) -> RoutineScheduleMode {
        let fallbackFormat: RoutineFormat = scheduleMode.routineFinishMode == .checklist ? .checklist : .standard
        return RoutineScheduleMode.routineMode(
            behavior: scheduleMode.scheduleBehavior,
            format: fallbackFormat
        )
    }
}

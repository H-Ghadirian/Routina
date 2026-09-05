import ComposableArchitecture
import Foundation

extension AddRoutineFeature {
    func reduceIdentityActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .routineNameChanged(name):
            AddRoutineValidationEditor.setRoutineName(name, state: &state)
            return .none
        case let .routineEmojiChanged(emoji):
            AddRoutineBasicsEditor.setEmoji(emoji, basics: &state.basics)
            return .none
        case let .taskDescriptionChanged(description):
            AddRoutineBasicsEditor.setTaskDescription(description, basics: &state.basics)
            return .none
        case let .routineNotesChanged(notes):
            AddRoutineBasicsEditor.setNotes(notes, basics: &state.basics)
            return .none
        case let .routineLinkChanged(link):
            AddRoutineBasicsEditor.setLink(link, basics: &state.basics)
            return .none
        case let .customTaskSectionChanged(sectionID):
            state.organization.customTaskSectionID = sectionID
            return .none
        case let .existingRoutineNamesChanged(names):
            AddRoutineValidationEditor.setExistingRoutineNames(names, state: &state)
            return .none
        default:
            return .none
        }
    }

    func reduceDeadlineAndTimingActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .deadlineEnabledChanged(isEnabled):
            AddRoutineFormEditor.setDeadlineEnabled(
                isEnabled,
                now: now,
                basics: &state.basics
            )
            sanitizeTaskLadderEntryWindow(state: &state)
            return .none
        case let .deadlineDateChanged(deadline):
            AddRoutineBasicsEditor.setDeadlineDate(
                deadline,
                calendar: calendar,
                basics: &state.basics
            )
            return .none
        case let .allDayChanged(isAllDay):
            AddRoutineFormEditor.setAllDay(
                isAllDay,
                now: now,
                calendar: calendar,
                scheduleMode: state.schedule.scheduleMode,
                basics: &state.basics
            )
            if isAllDay {
                state.schedule.recurrenceHasExplicitTime = false
                state.schedule.recurrenceHasTimeRange = false
                state.schedule.recurrenceTimeRangeRole = .availability
            }
            state.synchronizeRecurrenceDraftFromLegacy()
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
                state.schedule.hidesAssumedDoneCalendarBlock = false
            }
            return .none
        case let .routineDurationModeChanged(durationMode):
            AddRoutineFormEditor.setRoutineDurationMode(
                durationMode,
                basics: &state.basics
            )
            enforceRecurrenceConstraints(state: &state)
            state.synchronizeRecurrenceDraftFromLegacy()
            enforcePlanningRules(state: &state)
            return .none
        default:
            return .none
        }
    }

    func reduceAvailabilityAndPlanningActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .availabilityStartDateChanged(availabilityStartDate):
            AddRoutineBasicsEditor.setAvailabilityStartDate(
                availabilityStartDate,
                calendar: calendar,
                basics: &state.basics
            )
            enforcePlanningRules(state: &state)
            return .none
        case let .availabilityEndDateChanged(availabilityEndDate):
            AddRoutineBasicsEditor.setAvailabilityEndDate(
                availabilityEndDate,
                calendar: calendar,
                basics: &state.basics
            )
            enforcePlanningRules(state: &state)
            return .none
        case let .plannedDateChanged(plannedDate):
            if supportsPlanning(state) {
                if state.schedule.scheduleMode == .oneOff,
                    let availabilityStartDate = state.basics.availabilityStartDate,
                    state.basics.availabilityEndDate == nil
                {
                    state.basics.plannedDate = calendar.startOfDay(for: availabilityStartDate)
                } else {
                    AddRoutineBasicsEditor.setPlannedDate(
                        plannedDate,
                        calendar: calendar,
                        basics: &state.basics
                    )
                }
            } else {
                state.basics.plannedDate = nil
            }
            return .none
        default:
            return .none
        }
    }

    func reduceReminderActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .reminderEnabledChanged(isEnabled):
            let eventDate: Date?
            if state.schedule.scheduleMode == .oneOff,
                state.basics.deadline == nil,
                state.basics.availabilityStartDate == nil
            {
                eventDate = nil
            } else {
                eventDate = reminderEventDate(for: state)
            }
            state.basics.reminderAt =
                isEnabled
                ? (state.basics.reminderAt ?? eventDate ?? now)
                : nil
            return .none
        case let .reminderDateChanged(reminderDate):
            state.basics.reminderAt = reminderDate
            return .none
        case let .reminderLeadMinutesChanged(leadMinutes):
            guard
                let leadMinutes,
                let eventDate = reminderEventDate(for: state)
            else {
                return .none
            }
            state.basics.reminderAt = TaskFormReminderLeadTime.reminderDate(
                eventDate: eventDate,
                leadMinutes: leadMinutes
            )
            return .none
        default:
            return .none
        }
    }

    func reduceTaskLadderActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .priorityChanged(priority):
            AddRoutineBasicsEditor.setPriority(priority, basics: &state.basics)
            return .none
        case let .importanceChanged(importance):
            AddRoutineBasicsEditor.setImportance(importance, basics: &state.basics)
            sanitizeTemporalWeightRule(state: &state)
            return .none
        case let .urgencyChanged(urgency):
            AddRoutineBasicsEditor.setUrgency(urgency, basics: &state.basics)
            sanitizeTemporalWeightRule(state: &state)
            return .none
        case let .pressureChanged(pressure):
            AddRoutineBasicsEditor.setPressure(pressure, basics: &state.basics)
            sanitizeTemporalWeightRule(state: &state)
            return .none
        case let .temporalWeightRuleChanged(rule):
            state.basics.temporalWeightRule = rule
            sanitizeTemporalWeightRule(state: &state)
            return .none
        case let .taskLadderEntryWindowChanged(window):
            state.basics.taskLadderEntryWindow = window
            sanitizeTaskLadderEntryWindow(state: &state)
            return .none
        case let .thinkingNeededChanged(thinkingNeeded):
            AddRoutineBasicsEditor.setThinkingNeeded(thinkingNeeded, basics: &state.basics)
            return .none
        default:
            return .none
        }
    }

    func reduceMediaAndEffortActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .imagePicked(data):
            AddRoutineBasicsEditor.setImage(data, basics: &state.basics)
            return .none
        case .removeImageTapped:
            AddRoutineBasicsEditor.removeImage(basics: &state.basics)
            return .none
        case let .voiceNoteChanged(voiceNote):
            AddRoutineBasicsEditor.setVoiceNote(voiceNote, basics: &state.basics)
            return .none
        case let .attachmentPicked(data, fileName):
            AddRoutineBasicsEditor.addAttachment(
                data: data,
                fileName: fileName,
                basics: &state.basics
            )
            return .none
        case let .removeAttachment(id):
            AddRoutineBasicsEditor.removeAttachment(id, basics: &state.basics)
            return .none
        case let .routineColorChanged(color):
            AddRoutineBasicsEditor.setColor(color, basics: &state.basics)
            return .none
        case let .estimatedDurationChanged(estimatedDurationMinutes):
            AddRoutineBasicsEditor.setEstimatedDurationMinutes(
                estimatedDurationMinutes,
                basics: &state.basics
            )
            return .none
        case let .actualDurationChanged(actualDurationMinutes):
            AddRoutineBasicsEditor.setActualDurationMinutes(
                actualDurationMinutes,
                basics: &state.basics
            )
            return .none
        case let .storyPointsChanged(storyPoints):
            AddRoutineBasicsEditor.setStoryPoints(storyPoints, basics: &state.basics)
            return .none
        case let .focusModeEnabledChanged(isEnabled):
            AddRoutineBasicsEditor.setFocusModeEnabled(isEnabled, basics: &state.basics)
            return .none
        default:
            return .none
        }
    }

    func reduceTaskBehaviorActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .taskTypeChanged(taskType):
            scheduleMutationHandler().setTaskType(taskType, state: &state)
            if taskType == .todo {
                state.basics.taskLadderGroupEnabled = false
            }
            sanitizeTemporalWeightRule(state: &state)
            sanitizeTaskLadderEntryWindow(state: &state)
            return .none
        case let .taskLadderGroupEnabledChanged(isEnabled):
            state.basics.taskLadderGroupEnabled = state.taskType == .todo ? false : isEnabled
            return .none
        case let .cadenceEnabledChanged(isEnabled):
            state.basics.cadenceEnabled = isEnabled
            if isEnabled {
                state.basics.autoPauseAfterCompletion = false
            }
            if !isEnabled {
                state.basics.nudgesEnabled = false
            }
            state.synchronizeRecurrenceDraftFromLegacy()
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
                state.schedule.hidesAssumedDoneCalendarBlock = false
            }
            sanitizeTemporalWeightRule(state: &state)
            sanitizeTaskLadderEntryWindow(state: &state)
            return .none
        case let .nudgesEnabledChanged(isEnabled):
            state.basics.nudgesEnabled = isEnabled
            return .none
        default:
            return .none
        }
    }
}

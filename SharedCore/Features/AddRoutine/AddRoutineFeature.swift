import Foundation
import ComposableArchitecture

struct AddRoutineFeature: Reducer {
    typealias Frequency = TaskFormFrequencyUnit

    typealias State = AddRoutineFeatureState

    enum Action: Equatable {
        case routineNameChanged(String)
        case routineEmojiChanged(String)
        case routineNotesChanged(String)
        case routineLinkChanged(String)
        case deadlineEnabledChanged(Bool)
        case deadlineDateChanged(Date)
        case allDayChanged(Bool)
        case routineDurationModeChanged(RoutineDurationMode)
        case availabilityStartDateChanged(Date?)
        case availabilityEndDateChanged(Date?)
        case plannedDateChanged(Date?)
        case reminderEnabledChanged(Bool)
        case reminderDateChanged(Date)
        case priorityChanged(RoutineTaskPriority)
        case importanceChanged(RoutineTaskImportance)
        case urgencyChanged(RoutineTaskUrgency)
        case pressureChanged(RoutineTaskPressure)
        case imagePicked(Data?)
        case removeImageTapped
        case voiceNoteChanged(RoutineVoiceNote?)
        case attachmentPicked(Data, String)
        case removeAttachment(UUID)
        case taskTypeChanged(RoutineTaskType)
        case availableTagsChanged([String])
        case availableTagSummariesChanged([RoutineTagSummary])
        case availableGoalsChanged([RoutineGoalSummary])
        case availableEventsChanged([RoutineEventLinkCandidate])
        case relatedTagRulesChanged([RoutineRelatedTagRule])
        case availableRelationshipTasksChanged([RoutineTaskRelationshipCandidate])
        case tagDraftChanged(String)
        case goalDraftChanged(String)
        case addTagTapped
        case addGoalTapped
        case removeTag(String)
        case removeGoal(UUID)
        case toggleTagSelection(String)
        case toggleGoalSelection(RoutineGoalSummary)
        case toggleEventSelection(UUID)
        case addRelationship(UUID, RoutineTaskRelationshipKind)
        case removeRelationship(UUID)
        case tagRenamed(oldName: String, newName: String)
        case tagDeleted(String)
        case scheduleModeChanged(RoutineScheduleMode)
        case stepDraftChanged(String)
        case addStepTapped
        case removeStep(UUID)
        case moveStepUp(UUID)
        case moveStepDown(UUID)
        case checklistItemDraftTitleChanged(String)
        case checklistItemDraftIntervalChanged(Int)
        case addChecklistItemTapped
        case removeChecklistItem(UUID)
        case frequencyChanged(Frequency)
        case frequencyValueChanged(Int)
        case recurrenceKindChanged(RoutineRecurrenceRule.Kind)
        case recurrenceHasExplicitTimeChanged(Bool)
        case recurrenceHasTimeRangeChanged(Bool)
        case recurrenceTimeRangeRoleChanged(RoutineTimeRangeRole)
        case recurrenceTimeOfDayChanged(RoutineTimeOfDay)
        case recurrenceTimeRangeStartChanged(RoutineTimeOfDay)
        case recurrenceTimeRangeEndChanged(RoutineTimeOfDay)
        case recurrenceWeekdayChanged(Int)
        case recurrenceWeekdaysChanged([Int])
        case recurrenceDayOfMonthChanged(Int)
        case recurrenceDaysOfMonthChanged([Int])
        case autoAssumeDailyDoneChanged(Bool)
        case autoAssumeDoneTimeOfDayChanged(RoutineTimeOfDay)
        case existingRoutineNamesChanged([String])
        case availablePlacesChanged([RoutinePlaceSummary])
        case selectedPlaceChanged(UUID?)
        case selectedPlaceIDsChanged([UUID])
        case routineColorChanged(RoutineTaskColor)
        case estimatedDurationChanged(Int?)
        case actualDurationChanged(Int?)
        case storyPointsChanged(Int?)
        case focusModeEnabledChanged(Bool)
        case trackingCadenceEnabledChanged(Bool)
        case trackingNudgesEnabledChanged(Bool)
        case applyQuickAddDraftFromName
        case saveTapped
        case cancelTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case didCancel
            case didSave(AddRoutineSaveRequest)
        }
    }

    @Dependency(\.date.now) var now
    @Dependency(\.calendar) var calendar

    var onSave: (AddRoutineSaveRequest) -> Effect<Action>
    var onCancel: () -> Effect<Action>

    private func scheduleMutationHandler() -> AddRoutineScheduleMutationHandler {
        AddRoutineScheduleMutationHandler(now: { now })
    }

    private func organizationMutationHandler() -> AddRoutineOrganizationMutationHandler {
        AddRoutineOrganizationMutationHandler()
    }

    private func supportsPlanning(_ state: State) -> Bool {
        !RoutineTaskDailyRoutineSupport.isDailyRoutineForTaskList(
            scheduleMode: state.schedule.scheduleMode,
            recurrenceRule: state.candidateRecurrenceRule,
            checklistItems: state.candidateChecklistItems
        )
    }

    private func clearPlanningIfDailyRoutine(state: inout State) {
        if !supportsPlanning(state) {
            state.basics.plannedDate = nil
        }
    }

    private func enforceRecurrenceConstraints(state: inout State) {
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

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .routineNameChanged(name):
            AddRoutineValidationEditor.setRoutineName(
                name,
                state: &state
            )
            return .none

        case let .routineEmojiChanged(emoji):
            AddRoutineBasicsEditor.setEmoji(
                emoji,
                basics: &state.basics
            )
            return .none

        case let .routineNotesChanged(notes):
            AddRoutineBasicsEditor.setNotes(
                notes,
                basics: &state.basics
            )
            return .none

        case let .routineLinkChanged(link):
            AddRoutineBasicsEditor.setLink(
                link,
                basics: &state.basics
            )
            return .none

        case let .deadlineEnabledChanged(isEnabled):
            AddRoutineFormEditor.setDeadlineEnabled(
                isEnabled,
                now: now,
                basics: &state.basics
            )
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
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
            }
            return .none

        case let .routineDurationModeChanged(durationMode):
            AddRoutineFormEditor.setRoutineDurationMode(
                durationMode,
                basics: &state.basics
            )
            enforceRecurrenceConstraints(state: &state)
            clearPlanningIfDailyRoutine(state: &state)
            return .none

        case let .availabilityStartDateChanged(availabilityStartDate):
            AddRoutineBasicsEditor.setAvailabilityStartDate(
                availabilityStartDate,
                calendar: calendar,
                basics: &state.basics
            )
            return .none

        case let .availabilityEndDateChanged(availabilityEndDate):
            AddRoutineBasicsEditor.setAvailabilityEndDate(
                availabilityEndDate,
                calendar: calendar,
                basics: &state.basics
            )
            return .none

        case let .plannedDateChanged(plannedDate):
            if supportsPlanning(state) {
                AddRoutineBasicsEditor.setPlannedDate(
                    plannedDate,
                    calendar: calendar,
                    basics: &state.basics
                )
            } else {
                state.basics.plannedDate = nil
            }
            return .none

        case let .reminderEnabledChanged(isEnabled):
            AddRoutineFormEditor.setReminderEnabled(
                isEnabled,
                now: now,
                basics: &state.basics
            )
            return .none

        case let .reminderDateChanged(reminderDate):
            state.basics.reminderAt = reminderDate
            return .none

        case let .priorityChanged(priority):
            AddRoutineBasicsEditor.setPriority(
                priority,
                basics: &state.basics
            )
            return .none

        case let .importanceChanged(importance):
            AddRoutineBasicsEditor.setImportance(
                importance,
                basics: &state.basics
            )
            return .none

        case let .urgencyChanged(urgency):
            AddRoutineBasicsEditor.setUrgency(
                urgency,
                basics: &state.basics
            )
            return .none

        case let .pressureChanged(pressure):
            AddRoutineBasicsEditor.setPressure(
                pressure,
                basics: &state.basics
            )
            return .none

        case let .imagePicked(data):
            AddRoutineBasicsEditor.setImage(
                data,
                basics: &state.basics
            )
            return .none

        case .removeImageTapped:
            AddRoutineBasicsEditor.removeImage(
                basics: &state.basics
            )
            return .none

        case let .voiceNoteChanged(voiceNote):
            AddRoutineBasicsEditor.setVoiceNote(
                voiceNote,
                basics: &state.basics
            )
            return .none

        case let .attachmentPicked(data, fileName):
            AddRoutineBasicsEditor.addAttachment(
                data: data,
                fileName: fileName,
                basics: &state.basics
            )
            return .none

        case let .removeAttachment(id):
            AddRoutineBasicsEditor.removeAttachment(
                id,
                basics: &state.basics
            )
            return .none

        case let .taskTypeChanged(taskType):
            scheduleMutationHandler().setTaskType(taskType, state: &state)
            return .none

        case let .availableTagsChanged(tags):
            organizationMutationHandler().setAvailableTags(tags, state: &state)
            return .none

        case let .availableTagSummariesChanged(summaries):
            organizationMutationHandler().setAvailableTagSummaries(summaries, state: &state)
            return .none

        case let .availableGoalsChanged(goals):
            organizationMutationHandler().setAvailableGoals(goals, state: &state)
            return .none

        case let .availableEventsChanged(events):
            organizationMutationHandler().setAvailableEvents(events, state: &state)
            return .none

        case let .relatedTagRulesChanged(rules):
            organizationMutationHandler().setRelatedTagRules(rules, state: &state)
            return .none

        case let .availableRelationshipTasksChanged(tasks):
            organizationMutationHandler().setAvailableRelationshipTasks(tasks, state: &state)
            return .none

        case let .tagDraftChanged(value):
            organizationMutationHandler().setTagDraft(value, state: &state)
            return .none

        case let .goalDraftChanged(value):
            organizationMutationHandler().setGoalDraft(value, state: &state)
            return .none

        case .addTagTapped:
            organizationMutationHandler().commitDraftTag(state: &state)
            return .none

        case .addGoalTapped:
            organizationMutationHandler().commitDraftGoal(state: &state)
            return .none

        case let .removeTag(tag):
            organizationMutationHandler().removeTag(tag, state: &state)
            return .none

        case let .removeGoal(goalID):
            organizationMutationHandler().removeGoal(goalID, state: &state)
            return .none

        case let .toggleTagSelection(tag):
            organizationMutationHandler().toggleTagSelection(tag, state: &state)
            return .none

        case let .toggleGoalSelection(goal):
            organizationMutationHandler().toggleGoalSelection(goal, state: &state)
            return .none

        case let .toggleEventSelection(eventID):
            organizationMutationHandler().toggleEventSelection(eventID, state: &state)
            return .none

        case let .addRelationship(taskID, kind):
            organizationMutationHandler().addRelationship(
                targetTaskID: taskID,
                kind: kind,
                state: &state
            )
            return .none

        case let .removeRelationship(taskID):
            organizationMutationHandler().removeRelationship(targetTaskID: taskID, state: &state)
            return .none

        case let .tagRenamed(oldName, newName):
            organizationMutationHandler().renameTag(
                oldName: oldName,
                newName: newName,
                state: &state
            )
            return .none

        case let .tagDeleted(tag):
            organizationMutationHandler().deleteTag(tag, state: &state)
            return .none

        case let .scheduleModeChanged(mode):
            scheduleMutationHandler().setScheduleMode(mode, state: &state)
            if state.checklist.checklistValidationMessage != nil {
                AddRoutineValidationEditor.refreshChecklistValidation(state: &state)
            }
            clearPlanningIfDailyRoutine(state: &state)
            return .none

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
            clearPlanningIfDailyRoutine(state: &state)
            return .none

        case let .checklistItemDraftIntervalChanged(value):
            AddRoutineChecklistEditor.setChecklistItemDraftInterval(
                value,
                checklist: &state.checklist
            )
            if state.checklist.checklistValidationMessage != nil {
                AddRoutineValidationEditor.refreshChecklistValidation(state: &state)
            }
            clearPlanningIfDailyRoutine(state: &state)
            return .none

        case .addChecklistItemTapped:
            scheduleMutationHandler().addChecklistItem(state: &state)
            AddRoutineValidationEditor.refreshChecklistValidation(state: &state)
            clearPlanningIfDailyRoutine(state: &state)
            return .none

        case let .removeChecklistItem(itemID):
            scheduleMutationHandler().removeChecklistItem(itemID, state: &state)
            if state.checklist.checklistValidationMessage != nil {
                AddRoutineValidationEditor.refreshChecklistValidation(state: &state)
            }
            clearPlanningIfDailyRoutine(state: &state)
            return .none

        case let .frequencyChanged(freq):
            scheduleMutationHandler().setFrequency(freq, state: &state)
            clearPlanningIfDailyRoutine(state: &state)
            return .none

        case let .frequencyValueChanged(value):
            scheduleMutationHandler().setFrequencyValue(value, state: &state)
            clearPlanningIfDailyRoutine(state: &state)
            return .none

        case let .recurrenceKindChanged(kind):
            scheduleMutationHandler().setRecurrenceKind(kind, state: &state)
            clearPlanningIfDailyRoutine(state: &state)
            return .none

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
            clearPlanningIfDailyRoutine(state: &state)
            return .none

        case let .recurrenceDayOfMonthChanged(dayOfMonth):
            scheduleMutationHandler().setRecurrenceDayOfMonth(dayOfMonth, state: &state)
            return .none

        case let .recurrenceDaysOfMonthChanged(daysOfMonth):
            scheduleMutationHandler().setRecurrenceDaysOfMonth(daysOfMonth, state: &state)
            clearPlanningIfDailyRoutine(state: &state)
            return .none

        case let .autoAssumeDailyDoneChanged(isEnabled):
            scheduleMutationHandler().setAutoAssumeDailyDone(isEnabled, state: &state)
            return .none

        case let .autoAssumeDoneTimeOfDayChanged(timeOfDay):
            scheduleMutationHandler().setAutoAssumeDoneTimeOfDay(timeOfDay, state: &state)
            return .none

        case let .existingRoutineNamesChanged(names):
            AddRoutineValidationEditor.setExistingRoutineNames(
                names,
                state: &state
            )
            return .none

        case let .availablePlacesChanged(places):
            organizationMutationHandler().setAvailablePlaces(places, state: &state)
            return .none

        case let .selectedPlaceChanged(placeID):
            AddRoutineFormEditor.setSelectedPlace(
                placeID,
                basics: &state.basics
            )
            return .none

        case let .selectedPlaceIDsChanged(placeIDs):
            AddRoutineFormEditor.setSelectedPlaces(
                placeIDs,
                basics: &state.basics
            )
            return .none

        case let .routineColorChanged(color):
            AddRoutineBasicsEditor.setColor(
                color,
                basics: &state.basics
            )
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
            AddRoutineBasicsEditor.setStoryPoints(
                storyPoints,
                basics: &state.basics
            )
            return .none

        case let .focusModeEnabledChanged(isEnabled):
            AddRoutineBasicsEditor.setFocusModeEnabled(
                isEnabled,
                basics: &state.basics
            )
            return .none

        case let .trackingCadenceEnabledChanged(isEnabled):
            state.basics.trackingCadenceEnabled = isEnabled
            if !isEnabled {
                state.basics.trackingNudgesEnabled = false
            }
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
            }
            return .none

        case let .trackingNudgesEnabledChanged(isEnabled):
            state.basics.trackingNudgesEnabled = isEnabled
            return .none

        case .applyQuickAddDraftFromName:
            applyQuickAddDraftFromName(state: &state)
            return .none

        case .saveTapped:
            applyQuickAddDraftFromName(state: &state)
            AddRoutineDraftFinalizer(now: now).apply(to: &state)
            AddRoutineValidationEditor.refreshNameValidation(state: &state)
            AddRoutineValidationEditor.refreshChecklistValidation(state: &state)
            guard state.checklist.checklistValidationMessage == nil else { return .none }
            guard let request = AddRoutineSaveRequest(state: state, calendar: calendar) else { return .none }
            return onSave(request)

        case .cancelTapped:
            return onCancel()
        case .delegate(_):
            return .none
        }
    }

    private func applyQuickAddDraftFromName(state: inout State) {
        guard let draft = RoutinaQuickAddParser.parse(
            state.basics.routineName,
            referenceDate: now,
            calendar: calendar,
            includingPlaces: SharedDefaults.app[.appSettingPlacesEnabled]
        ), draft.hasDetectedMetadata else {
            return
        }

        AddRoutineValidationEditor.setRoutineName(draft.name, state: &state)

        if draft.hasDetectedSchedule {
            applyQuickAddSchedule(from: draft, state: &state)
        }

        state.organization.routineTags = RoutineTag.merging(
            draft.tags,
            into: state.organization.routineTags,
            availableTags: state.organization.availableTags
        )

        if SharedDefaults.app[.appSettingPlacesEnabled],
           let placeID = matchingPlaceID(named: draft.placeName, in: state.organization.availablePlaces) {
            AddRoutineFormEditor.setSelectedPlace(placeID, basics: &state.basics)
        }

        if draft.importance != .level2 || draft.urgency != .level2 {
            state.basics.importance = draft.importance
            state.basics.urgency = draft.urgency
            state.basics.priority = AddRoutinePriorityMatrix.priority(
                importance: draft.importance,
                urgency: draft.urgency
            )
        }

        if let estimatedDurationMinutes = draft.estimatedDurationMinutes {
            AddRoutineBasicsEditor.setEstimatedDurationMinutes(
                estimatedDurationMinutes,
                basics: &state.basics
            )
            state.basics.focusModeEnabled = draft.focusModeEnabled
        }
    }

    private func applyQuickAddSchedule(
        from draft: RoutinaQuickAddDraft,
        state: inout State
    ) {
        scheduleMutationHandler().setScheduleMode(draft.scheduleMode, state: &state)
        applyFrequency(days: draft.frequencyInDays, state: &state)

        if draft.scheduleMode == .oneOff {
            state.basics.deadline = draft.deadline
            state.basics.reminderAt = draft.reminderAt
            return
        }

        state.basics.deadline = nil
        state.basics.reminderAt = nil

        let recurrenceRule = draft.recurrenceRule
        scheduleMutationHandler().setRecurrenceKind(recurrenceRule.kind, state: &state)

        switch recurrenceRule.kind {
        case .intervalDays:
            applyTimeConstraint(from: recurrenceRule, state: &state)
        case .dailyTime:
            applyTimeConstraint(from: recurrenceRule, state: &state)
        case .weekly:
            scheduleMutationHandler().setRecurrenceWeekdays(
                recurrenceRule.resolvedWeekdays(calendar: calendar),
                state: &state
            )
            applyTimeConstraint(from: recurrenceRule, state: &state)
        case .monthlyDay:
            scheduleMutationHandler().setRecurrenceDaysOfMonth(
                recurrenceRule.resolvedDaysOfMonth(calendar: calendar),
                state: &state
            )
            applyTimeConstraint(from: recurrenceRule, state: &state)
        }
    }

    private func applyFrequency(days: Int, state: inout State) {
        let safeDays = max(days, 1)
        if safeDays.isMultiple(of: 30) {
            scheduleMutationHandler().setFrequency(.month, state: &state)
            scheduleMutationHandler().setFrequencyValue(max(safeDays / 30, 1), state: &state)
        } else if safeDays.isMultiple(of: 7) {
            scheduleMutationHandler().setFrequency(.week, state: &state)
            scheduleMutationHandler().setFrequencyValue(max(safeDays / 7, 1), state: &state)
        } else {
            scheduleMutationHandler().setFrequency(.day, state: &state)
            scheduleMutationHandler().setFrequencyValue(safeDays, state: &state)
        }
    }

    private func applyTimeConstraint(
        from recurrenceRule: RoutineRecurrenceRule,
        state: inout State
    ) {
        if let timeRange = recurrenceRule.timeRange {
            scheduleMutationHandler().setRecurrenceHasTimeRange(true, state: &state)
            scheduleMutationHandler().setRecurrenceTimeRangeStart(timeRange.start, state: &state)
            scheduleMutationHandler().setRecurrenceTimeRangeEnd(timeRange.end, state: &state)
        } else if let timeOfDay = recurrenceRule.timeOfDay {
            scheduleMutationHandler().setRecurrenceHasExplicitTime(true, state: &state)
            scheduleMutationHandler().setRecurrenceTimeOfDay(timeOfDay, state: &state)
        } else {
            scheduleMutationHandler().setRecurrenceHasExplicitTime(false, state: &state)
            scheduleMutationHandler().setRecurrenceHasTimeRange(false, state: &state)
        }
    }

    private func matchingPlaceID(
        named placeName: String?,
        in places: [RoutinePlaceSummary]
    ) -> UUID? {
        guard let placeName,
              let normalizedName = RoutinePlace.normalizedName(placeName)
        else {
            return nil
        }

        return places.first { place in
            RoutinePlace.normalizedName(place.name) == normalizedName
        }?.id
    }
}

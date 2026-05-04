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
        case reminderEnabledChanged(Bool)
        case reminderDateChanged(Date)
        case priorityChanged(RoutineTaskPriority)
        case importanceChanged(RoutineTaskImportance)
        case urgencyChanged(RoutineTaskUrgency)
        case pressureChanged(RoutineTaskPressure)
        case imagePicked(Data?)
        case removeImageTapped
        case attachmentPicked(Data, String)
        case removeAttachment(UUID)
        case taskTypeChanged(RoutineTaskType)
        case availableTagsChanged([String])
        case availableTagSummariesChanged([RoutineTagSummary])
        case availableGoalsChanged([RoutineGoalSummary])
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
        case recurrenceTimeOfDayChanged(RoutineTimeOfDay)
        case recurrenceWeekdayChanged(Int)
        case recurrenceDayOfMonthChanged(Int)
        case autoAssumeDailyDoneChanged(Bool)
        case existingRoutineNamesChanged([String])
        case availablePlacesChanged([RoutinePlaceSummary])
        case selectedPlaceChanged(UUID?)
        case routineColorChanged(RoutineTaskColor)
        case estimatedDurationChanged(Int?)
        case storyPointsChanged(Int?)
        case focusModeEnabledChanged(Bool)
        case saveTapped
        case cancelTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case didCancel
            case didSave(AddRoutineSaveRequest)
        }
    }

    @Dependency(\.date.now) var now

    var onSave: (AddRoutineSaveRequest) -> Effect<Action>
    var onCancel: () -> Effect<Action>

    private func scheduleMutationHandler() -> AddRoutineScheduleMutationHandler {
        AddRoutineScheduleMutationHandler(now: { now })
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
                basics: &state.basics
            )
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
            AddRoutineOrganizationEditor.setAvailableTags(
                tags,
                organization: &state.organization
            )
            return .none

        case let .availableTagSummariesChanged(summaries):
            AddRoutineOrganizationEditor.setAvailableTagSummaries(
                summaries,
                organization: &state.organization
            )
            return .none

        case let .availableGoalsChanged(goals):
            AddRoutineOrganizationEditor.setAvailableGoals(
                goals,
                organization: &state.organization
            )
            return .none

        case let .relatedTagRulesChanged(rules):
            AddRoutineOrganizationEditor.setRelatedTagRules(
                rules,
                organization: &state.organization
            )
            return .none

        case let .availableRelationshipTasksChanged(tasks):
            AddRoutineOrganizationEditor.setAvailableRelationshipTasks(
                tasks,
                organization: &state.organization
            )
            return .none

        case let .tagDraftChanged(value):
            state.organization.tagDraft = value
            return .none

        case let .goalDraftChanged(value):
            state.organization.goalDraft = value
            return .none

        case .addTagTapped:
            AddRoutineOrganizationEditor.commitDraftTag(
                organization: &state.organization
            )
            return .none

        case .addGoalTapped:
            AddRoutineOrganizationEditor.commitDraftGoal(
                organization: &state.organization
            )
            return .none

        case let .removeTag(tag):
            AddRoutineOrganizationEditor.removeTag(
                tag,
                organization: &state.organization
            )
            return .none

        case let .removeGoal(goalID):
            AddRoutineOrganizationEditor.removeGoal(
                goalID,
                organization: &state.organization
            )
            return .none

        case let .toggleTagSelection(tag):
            AddRoutineOrganizationEditor.toggleTagSelection(
                tag,
                organization: &state.organization
            )
            return .none

        case let .toggleGoalSelection(goal):
            AddRoutineOrganizationEditor.toggleGoalSelection(
                goal,
                organization: &state.organization
            )
            return .none

        case let .addRelationship(taskID, kind):
            AddRoutineOrganizationEditor.addRelationship(
                targetTaskID: taskID,
                kind: kind,
                organization: &state.organization
            )
            return .none

        case let .removeRelationship(taskID):
            AddRoutineOrganizationEditor.removeRelationship(
                targetTaskID: taskID,
                organization: &state.organization
            )
            return .none

        case let .tagRenamed(oldName, newName):
            AddRoutineOrganizationEditor.renameTag(
                oldName: oldName,
                newName: newName,
                organization: &state.organization
            )
            return .none

        case let .tagDeleted(tag):
            AddRoutineOrganizationEditor.deleteTag(
                tag,
                organization: &state.organization
            )
            return .none

        case let .scheduleModeChanged(mode):
            scheduleMutationHandler().setScheduleMode(mode, state: &state)
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
            return .none

        case let .checklistItemDraftIntervalChanged(value):
            AddRoutineChecklistEditor.setChecklistItemDraftInterval(
                value,
                checklist: &state.checklist
            )
            return .none

        case .addChecklistItemTapped:
            scheduleMutationHandler().addChecklistItem(state: &state)
            return .none

        case let .removeChecklistItem(itemID):
            scheduleMutationHandler().removeChecklistItem(itemID, state: &state)
            return .none

        case let .frequencyChanged(freq):
            scheduleMutationHandler().setFrequency(freq, state: &state)
            return .none

        case let .frequencyValueChanged(value):
            scheduleMutationHandler().setFrequencyValue(value, state: &state)
            return .none

        case let .recurrenceKindChanged(kind):
            scheduleMutationHandler().setRecurrenceKind(kind, state: &state)
            return .none

        case let .recurrenceHasExplicitTimeChanged(hasExplicitTime):
            scheduleMutationHandler().setRecurrenceHasExplicitTime(hasExplicitTime, state: &state)
            return .none

        case let .recurrenceTimeOfDayChanged(timeOfDay):
            scheduleMutationHandler().setRecurrenceTimeOfDay(timeOfDay, state: &state)
            return .none

        case let .recurrenceWeekdayChanged(weekday):
            scheduleMutationHandler().setRecurrenceWeekday(weekday, state: &state)
            return .none

        case let .recurrenceDayOfMonthChanged(dayOfMonth):
            scheduleMutationHandler().setRecurrenceDayOfMonth(dayOfMonth, state: &state)
            return .none

        case let .autoAssumeDailyDoneChanged(isEnabled):
            scheduleMutationHandler().setAutoAssumeDailyDone(isEnabled, state: &state)
            return .none

        case let .existingRoutineNamesChanged(names):
            AddRoutineValidationEditor.setExistingRoutineNames(
                names,
                state: &state
            )
            return .none

        case let .availablePlacesChanged(places):
            var basics = state.basics
            var organization = state.organization
            AddRoutineFormEditor.setAvailablePlaces(
                places,
                basics: &basics,
                organization: &organization
            )
            state.basics = basics
            state.organization = organization
            return .none

        case let .selectedPlaceChanged(placeID):
            AddRoutineFormEditor.setSelectedPlace(
                placeID,
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

        case .saveTapped:
            AddRoutineDraftFinalizer(now: now).apply(to: &state)
            AddRoutineValidationEditor.refreshNameValidation(state: &state)
            guard let request = AddRoutineSaveRequest(state: state) else { return .none }
            return onSave(request)

        case .cancelTapped:
            return onCancel()
        case .delegate(_):
            return .none
        }
    }
}

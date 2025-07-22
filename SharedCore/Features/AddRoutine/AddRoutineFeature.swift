import Foundation
import ComposableArchitecture

struct AddRoutineFeature: Reducer {
    enum Frequency: String, CaseIterable, Equatable {
        case day = "Day"
        case week = "Week"
        case month = "Month"

        var daysMultiplier: Int {
            switch self {
            case .day:
                return 1
            case .week:
                return 7
            case .month:
                return 30
            }
        }

        var singularLabel: String {
            switch self {
            case .day:
                return "day"
            case .week:
                return "week"
            case .month:
                return "month"
            }
        }
    }

    typealias State = AddRoutineFeatureState

    enum Action: Equatable {
        case routineNameChanged(String)
        case routineEmojiChanged(String)
        case routineNotesChanged(String)
        case routineLinkChanged(String)
        case deadlineEnabledChanged(Bool)
        case deadlineDateChanged(Date)
        case priorityChanged(RoutineTaskPriority)
        case importanceChanged(RoutineTaskImportance)
        case urgencyChanged(RoutineTaskUrgency)
        case imagePicked(Data?)
        case removeImageTapped
        case attachmentPicked(Data, String)
        case removeAttachment(UUID)
        case taskTypeChanged(RoutineTaskType)
        case availableTagsChanged([String])
        case availableTagSummariesChanged([RoutineTagSummary])
        case relatedTagRulesChanged([RoutineRelatedTagRule])
        case availableRelationshipTasksChanged([RoutineTaskRelationshipCandidate])
        case tagDraftChanged(String)
        case addTagTapped
        case removeTag(String)
        case toggleTagSelection(String)
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
        case saveTapped
        case cancelTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case didCancel
            case didSave(String, Int, RoutineRecurrenceRule, String, String?, String?, Date?, RoutineTaskPriority, RoutineTaskImportance, RoutineTaskUrgency, Data?, UUID?, [String], [RoutineTaskRelationship], [RoutineStep], RoutineScheduleMode, [RoutineChecklistItem], [AttachmentItem], RoutineTaskColor, Bool, Int?, Int?)
        }
    }

    @Dependency(\.date.now) var now

    var onSave: (String, Int, RoutineRecurrenceRule, String, String?, String?, Date?, RoutineTaskPriority, RoutineTaskImportance, RoutineTaskUrgency, Data?, UUID?, [String], [RoutineTaskRelationship], [RoutineStep], RoutineScheduleMode, [RoutineChecklistItem], [AttachmentItem], RoutineTaskColor, Bool, Int?, Int?) -> Effect<Action>
    var onCancel: () -> Effect<Action>

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
            var basics = state.basics
            var schedule = state.schedule
            AddRoutineFormEditor.setTaskType(
                taskType,
                basics: &basics,
                schedule: &schedule
            )
            state.basics = basics
            state.schedule = schedule
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
            }
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

        case .addTagTapped:
            AddRoutineOrganizationEditor.commitDraftTag(
                organization: &state.organization
            )
            return .none

        case let .removeTag(tag):
            AddRoutineOrganizationEditor.removeTag(
                tag,
                organization: &state.organization
            )
            return .none

        case let .toggleTagSelection(tag):
            AddRoutineOrganizationEditor.toggleTagSelection(
                tag,
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
            AddRoutineScheduleEditor.setScheduleMode(
                mode,
                schedule: &state.schedule
            )
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
            }
            return .none

        case let .stepDraftChanged(value):
            AddRoutineChecklistEditor.setStepDraft(
                value,
                checklist: &state.checklist
            )
            return .none

        case .addStepTapped:
            AddRoutineChecklistEditor.addStep(
                checklist: &state.checklist
            )
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
            }
            return .none

        case let .removeStep(stepID):
            AddRoutineChecklistEditor.removeStep(
                stepID,
                checklist: &state.checklist
            )
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
            }
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
            AddRoutineChecklistEditor.addChecklistItem(
                createdAt: now,
                checklist: &state.checklist
            )
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
            }
            return .none

        case let .removeChecklistItem(itemID):
            AddRoutineChecklistEditor.removeChecklistItem(
                itemID,
                checklist: &state.checklist
            )
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
            }
            return .none

        case let .frequencyChanged(freq):
            AddRoutineScheduleEditor.setFrequency(
                freq,
                schedule: &state.schedule
            )
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
            }
            return .none

        case let .frequencyValueChanged(value):
            AddRoutineScheduleEditor.setFrequencyValue(
                value,
                schedule: &state.schedule
            )
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
            }
            return .none

        case let .recurrenceKindChanged(kind):
            AddRoutineScheduleEditor.setRecurrenceKind(
                kind,
                schedule: &state.schedule
            )
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
            }
            return .none

        case let .recurrenceHasExplicitTimeChanged(hasExplicitTime):
            AddRoutineScheduleEditor.setRecurrenceHasExplicitTime(
                hasExplicitTime,
                schedule: &state.schedule
            )
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
            }
            return .none

        case let .recurrenceTimeOfDayChanged(timeOfDay):
            AddRoutineScheduleEditor.setRecurrenceTimeOfDay(
                timeOfDay,
                schedule: &state.schedule
            )
            if !state.canAutoAssumeDailyDone {
                state.schedule.autoAssumeDailyDone = false
            }
            return .none

        case let .recurrenceWeekdayChanged(weekday):
            AddRoutineScheduleEditor.setRecurrenceWeekday(
                weekday,
                schedule: &state.schedule
            )
            return .none

        case let .recurrenceDayOfMonthChanged(dayOfMonth):
            AddRoutineScheduleEditor.setRecurrenceDayOfMonth(
                dayOfMonth,
                schedule: &state.schedule
            )
            return .none

        case let .autoAssumeDailyDoneChanged(isEnabled):
            state.schedule.autoAssumeDailyDone = isEnabled && state.canAutoAssumeDailyDone
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

        case .saveTapped:
            AddRoutineDraftFinalizer(now: now).apply(to: &state)
            AddRoutineValidationEditor.refreshNameValidation(state: &state)
            guard let request = AddRoutineSaveRequest(state: state) else { return .none }
            return onSave(
                request.name,
                request.frequencyInDays,
                request.recurrenceRule,
                request.emoji,
                request.notes,
                request.link,
                request.deadline,
                request.priority,
                request.importance,
                request.urgency,
                request.imageData,
                request.selectedPlaceID,
                request.tags,
                request.relationships,
                request.steps,
                request.scheduleMode,
                request.checklistItems,
                request.attachments,
                request.color,
                request.autoAssumeDailyDone,
                request.estimatedDurationMinutes,
                request.storyPoints
            )

        case .cancelTapped:
            return onCancel()
        case .delegate(_):
            return .none
        }
    }
}

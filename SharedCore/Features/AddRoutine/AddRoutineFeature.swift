import ComposableArchitecture
import Foundation

struct AddRoutineFeature: Reducer {
    typealias Frequency = TaskFormFrequencyUnit
    typealias State = AddRoutineFeatureState

    enum Action: Equatable {
        case routineNameChanged(String)
        case routineEmojiChanged(String)
        case taskDescriptionChanged(String)
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
        case reminderLeadMinutesChanged(Int?)
        case priorityChanged(RoutineTaskPriority)
        case importanceChanged(RoutineTaskImportance)
        case urgencyChanged(RoutineTaskUrgency)
        case pressureChanged(RoutineTaskPressure)
        case temporalWeightRuleChanged(RoutineTaskTemporalWeightRule?)
        case taskLadderEntryWindowChanged(RoutineTaskLadderEntryWindow)
        case thinkingNeededChanged(RoutineTaskThinkingNeeded)
        case imagePicked(Data?)
        case removeImageTapped
        case voiceNoteChanged(RoutineVoiceNote?)
        case attachmentPicked(Data, String)
        case removeAttachment(UUID)
        case taskTypeChanged(RoutineTaskType)
        case taskLadderGroupEnabledChanged(Bool)
        case customTaskSectionChanged(UUID?)
        case availableTagsChanged([String])
        case availableFlagsChanged([String])
        case flagRulesChanged([RoutineFlagRule])
        case availableTagSummariesChanged([RoutineTagSummary])
        case availableGoalsChanged([RoutineGoalSummary])
        case availableEventsChanged([RoutineEventLinkCandidate])
        case relatedTagRulesChanged([RoutineRelatedTagRule])
        case availableRelationshipTasksChanged([RoutineTaskRelationshipCandidate])
        case tagDraftChanged(String)
        case flagDraftChanged(String)
        case goalDraftChanged(String)
        case addTagTapped
        case addFlagTapped
        case addGoalTapped
        case removeTag(String)
        case removeFlag(String)
        case removeGoal(UUID)
        case toggleTagSelection(String)
        case toggleFlagSelection(String)
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
        case recurrenceEditorModeChanged(RoutineRecurrenceEditorMode)
        case advancedRecurrenceRuleChanged(RoutineAdvancedRecurrenceRule)
        case recurrenceDraftChanged(RoutineRecurrenceDraft)
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
        case hidesAssumedDoneCalendarBlockChanged(Bool)
        case autoAssumeDoneTimeOfDayChanged(RoutineTimeOfDay)
        case existingRoutineNamesChanged([String])
        case availablePlacesChanged([RoutinePlaceSummary])
        case selectedPlaceChanged(UUID?)
        case selectedPlaceIDsChanged([UUID])
        case destinationAddressChanged(String)
        case destinationCoordinateChanged(LocationCoordinate?)
        case routineColorChanged(RoutineTaskColor)
        case estimatedDurationChanged(Int?)
        case actualDurationChanged(Int?)
        case storyPointsChanged(Int?)
        case focusModeEnabledChanged(Bool)
        case cadenceEnabledChanged(Bool)
        case nudgesEnabledChanged(Bool)
        case applyQuickAddDraftFromName
        case saveTapped
        case saveFailed
        case cancelTapped
        case delegate(AddRoutineDelegateAction)
    }

    @Dependency(\.date.now) var now
    @Dependency(\.calendar) var calendar
    @Dependency(\.creationDraftClient) var creationDraftClient

    var onSave: (AddRoutineSaveRequest) -> Effect<Action>
    var onCancel: () -> Effect<Action>

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        let effect = Effect.merge(
            reduceIdentityActions(into: &state, action: action),
            reduceDeadlineAndTimingActions(into: &state, action: action),
            reduceAvailabilityAndPlanningActions(into: &state, action: action),
            reduceReminderActions(into: &state, action: action),
            reduceTaskLadderActions(into: &state, action: action),
            reduceMediaAndEffortActions(into: &state, action: action),
            reduceTaskBehaviorActions(into: &state, action: action),
            reduceOrganizationCatalogActions(into: &state, action: action),
            reduceOrganizationDraftActions(into: &state, action: action),
            reduceOrganizationSelectionActions(into: &state, action: action),
            reducePlaceActions(into: &state, action: action),
            reduceScheduleModeActions(into: &state, action: action),
            reduceScheduleStructureActions(into: &state, action: action),
            reduceRecurrenceDefinitionActions(into: &state, action: action),
            reduceRecurrenceTimingActions(into: &state, action: action),
            reduceAutoAssumeActions(into: &state, action: action),
            reduceLifecycleActions(into: &state, action: action)
        )

        switch action {
        case .cancelTapped, .delegate:
            creationDraftClient.cancelScheduledSave(.task)
        case .saveTapped where state.isSaving:
            creationDraftClient.cancelScheduledSave(.task)
        default:
            scheduleCreationDraftAutosave(for: state)
        }

        return effect
    }
}

enum AddRoutineDelegateAction: Equatable {
    case didCancel
    case didSave(AddRoutineSaveRequest)
}

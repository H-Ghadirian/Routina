import ComposableArchitecture
import SwiftUI

@MainActor
struct AddRoutineTaskFormModelFactory {
    let store: StoreOf<AddRoutineFeature>
    let emojiOptions: [String]
    let isEmojiPickerPresented: Binding<Bool>
    var nameFocus: FocusState<Bool>.Binding?
    var nameFocusRequestID = 0

    func make() -> TaskFormModel {
        TaskFormModel(
            name: binding(get: { store.basics.routineName }, send: AddRoutineFeature.Action.routineNameChanged),
            nameValidationMessage: store.organization.nameValidationMessage,
            taskType: binding(get: { store.taskType }, send: AddRoutineFeature.Action.taskTypeChanged),
            emoji: binding(get: { store.basics.routineEmoji }, send: AddRoutineFeature.Action.routineEmojiChanged),
            emojiOptions: emojiOptions,
            isEmojiPickerPresented: isEmojiPickerPresented,
            notes: binding(get: { store.basics.routineNotes }, send: AddRoutineFeature.Action.routineNotesChanged),
            link: binding(get: { store.basics.routineLink }, send: AddRoutineFeature.Action.routineLinkChanged),
            deadlineEnabled: binding(get: { store.hasDeadline }, send: AddRoutineFeature.Action.deadlineEnabledChanged),
            deadline: binding(get: { store.basics.deadline ?? Date() }, send: AddRoutineFeature.Action.deadlineDateChanged),
            reminderEnabled: binding(
                get: { store.basics.reminderAt != nil },
                send: AddRoutineFeature.Action.reminderEnabledChanged
            ),
            reminderAt: binding(get: { store.basics.reminderAt ?? Date() }, send: AddRoutineFeature.Action.reminderDateChanged),
            importance: binding(get: { store.basics.importance }, send: AddRoutineFeature.Action.importanceChanged),
            urgency: binding(get: { store.basics.urgency }, send: AddRoutineFeature.Action.urgencyChanged),
            pressure: binding(get: { store.basics.pressure }, send: AddRoutineFeature.Action.pressureChanged),
            estimatedDurationMinutes: binding(
                get: { store.basics.estimatedDurationMinutes },
                send: AddRoutineFeature.Action.estimatedDurationChanged
            ),
            storyPoints: binding(get: { store.basics.storyPoints }, send: AddRoutineFeature.Action.storyPointsChanged),
            imageData: store.basics.imageData,
            onImagePicked: { store.send(.imagePicked($0)) },
            onRemoveImage: { store.send(.removeImageTapped) },
            attachments: store.basics.attachments,
            onAttachmentPicked: { store.send(.attachmentPicked($0, $1)) },
            onRemoveAttachment: { store.send(.removeAttachment($0)) },
            tagDraft: binding(get: { store.organization.tagDraft }, send: AddRoutineFeature.Action.tagDraftChanged),
            routineTags: store.organization.routineTags,
            availableTags: store.organization.availableTags,
            availableTagSummaries: store.organization.availableTagSummaries,
            relatedTagRules: store.organization.relatedTagRules,
            tagCounterDisplayMode: store.organization.tagCounterDisplayMode,
            onAddTag: { store.send(.addTagTapped) },
            onRemoveTag: { store.send(.removeTag($0)) },
            onToggleTagSelection: { store.send(.toggleTagSelection($0)) },
            goalDraft: binding(get: { store.organization.goalDraft }, send: AddRoutineFeature.Action.goalDraftChanged),
            selectedGoals: store.organization.routineGoals,
            availableGoals: store.organization.availableGoals,
            onAddGoal: { store.send(.addGoalTapped) },
            onRemoveGoal: { store.send(.removeGoal($0)) },
            onToggleGoalSelection: { store.send(.toggleGoalSelection($0)) },
            relationships: store.organization.relationships,
            availableRelationshipTasks: store.organization.availableRelationshipTasks,
            onAddRelationship: { store.send(.addRelationship($0, $1)) },
            onRemoveRelationship: { store.send(.removeRelationship($0)) },
            scheduleMode: binding(get: { store.schedule.scheduleMode }, send: AddRoutineFeature.Action.scheduleModeChanged),
            stepDraft: binding(get: { store.checklist.stepDraft }, send: AddRoutineFeature.Action.stepDraftChanged),
            routineSteps: store.checklist.routineSteps,
            onAddStep: { store.send(.addStepTapped) },
            onRemoveStep: { store.send(.removeStep($0)) },
            onMoveStepUp: { store.send(.moveStepUp($0)) },
            onMoveStepDown: { store.send(.moveStepDown($0)) },
            checklistItemDraftTitle: binding(
                get: { store.checklist.checklistItemDraftTitle },
                send: AddRoutineFeature.Action.checklistItemDraftTitleChanged
            ),
            checklistItemDraftInterval: binding(
                get: { store.checklist.checklistItemDraftInterval },
                send: AddRoutineFeature.Action.checklistItemDraftIntervalChanged
            ),
            routineChecklistItems: store.checklist.routineChecklistItems,
            onAddChecklistItem: { store.send(.addChecklistItemTapped) },
            onRemoveChecklistItem: { store.send(.removeChecklistItem($0)) },
            availablePlaces: store.organization.availablePlaces,
            selectedPlaceID: binding(get: { store.basics.selectedPlaceID }, send: AddRoutineFeature.Action.selectedPlaceChanged),
            recurrenceKind: binding(get: { store.schedule.recurrenceKind }, send: AddRoutineFeature.Action.recurrenceKindChanged),
            recurrenceHasExplicitTime: binding(
                get: { store.schedule.recurrenceHasExplicitTime },
                send: AddRoutineFeature.Action.recurrenceHasExplicitTimeChanged
            ),
            recurrenceTimeOfDay: binding(
                get: { store.schedule.recurrenceTimeOfDay.date(on: Date()) },
                send: { .recurrenceTimeOfDayChanged(RoutineTimeOfDay.from($0)) }
            ),
            recurrenceWeekday: binding(
                get: { store.schedule.recurrenceWeekday },
                send: AddRoutineFeature.Action.recurrenceWeekdayChanged
            ),
            recurrenceDayOfMonth: binding(
                get: { store.schedule.recurrenceDayOfMonth },
                send: AddRoutineFeature.Action.recurrenceDayOfMonthChanged
            ),
            frequencyUnit: binding(get: { store.schedule.frequency }, send: AddRoutineFeature.Action.frequencyChanged),
            frequencyValue: binding(get: { store.schedule.frequencyValue }, send: AddRoutineFeature.Action.frequencyValueChanged),
            autoAssumeDailyDone: binding(
                get: { store.schedule.autoAssumeDailyDone },
                send: AddRoutineFeature.Action.autoAssumeDailyDoneChanged
            ),
            canAutoAssumeDailyDone: store.canAutoAssumeDailyDone,
            focusModeEnabled: binding(
                get: { store.basics.focusModeEnabled },
                send: AddRoutineFeature.Action.focusModeEnabledChanged
            ),
            color: binding(get: { store.basics.routineColor }, send: AddRoutineFeature.Action.routineColorChanged),
            nameFocus: nameFocus,
            nameFocusRequestID: nameFocusRequestID,
            autofocusName: true,
            onDelete: nil
        )
    }

    private func binding<Value>(
        get: @escaping @MainActor @Sendable () -> Value,
        send action: @escaping @MainActor @Sendable (Value) -> AddRoutineFeature.Action
    ) -> Binding<Value> {
        Binding(
            get: get,
            set: { store.send(action($0)) }
        )
    }
}

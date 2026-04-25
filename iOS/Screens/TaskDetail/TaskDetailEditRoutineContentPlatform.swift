import ComposableArchitecture
import SwiftUI

struct TaskDetailEditRoutineContent: View {
    let store: StoreOf<TaskDetailFeature>
    @Binding var isEditEmojiPickerPresented: Bool
    let emojiOptions: [String]

    var body: some View {
        TaskFormContent(model: makeTaskFormModel())
            .onReceive(
                NotificationCenter.default.publisher(for: .routineTagDidRename)
                    .receive(on: RunLoop.main)
            ) { notification in
                guard let payload = notification.routineTagRenamePayload else { return }
                store.send(.editTagRenamed(oldName: payload.oldName, newName: payload.newName))
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .routineTagDidDelete)
                    .receive(on: RunLoop.main)
            ) { notification in
                guard let tagName = notification.routineTagDeletedName else { return }
                store.send(.editTagDeleted(tagName))
            }
    }

    private func makeTaskFormModel() -> TaskFormModel {
        TaskFormModel(
            name: Binding(
                get: { store.editRoutineName },
                set: { store.send(.editRoutineNameChanged($0)) }
            ),
            nameValidationMessage: nil,
            taskType: taskTypeBinding,
            emoji: Binding(
                get: { store.editRoutineEmoji },
                set: { store.send(.editRoutineEmojiChanged($0)) }
            ),
            emojiOptions: emojiOptions,
            isEmojiPickerPresented: $isEditEmojiPickerPresented,
            notes: Binding(
                get: { store.editRoutineNotes },
                set: { store.send(.editRoutineNotesChanged($0)) }
            ),
            link: Binding(
                get: { store.editRoutineLink },
                set: { store.send(.editRoutineLinkChanged($0)) }
            ),
            deadlineEnabled: editDeadlineEnabledBinding,
            deadline: editDeadlineBinding,
            importance: editImportanceBinding,
            urgency: editUrgencyBinding,
            pressure: Binding(
                get: { store.editPressure },
                set: { store.send(.editPressureChanged($0)) }
            ),
            estimatedDurationMinutes: Binding(
                get: { store.editEstimatedDurationMinutes },
                set: { store.send(.editEstimatedDurationChanged($0)) }
            ),
            storyPoints: Binding(
                get: { store.editStoryPoints },
                set: { store.send(.editStoryPointsChanged($0)) }
            ),
            imageData: store.editImageData,
            onImagePicked: { store.send(.editImagePicked($0)) },
            onRemoveImage: { store.send(.editRemoveImageTapped) },
            attachments: store.editAttachments,
            onAttachmentPicked: { store.send(.editAttachmentPicked($0, $1)) },
            onRemoveAttachment: { store.send(.editRemoveAttachment($0)) },
            tagDraft: Binding(
                get: { store.editTagDraft },
                set: { store.send(.editTagDraftChanged($0)) }
            ),
            routineTags: store.editRoutineTags,
            availableTags: store.availableTags,
            relatedTagRules: store.relatedTagRules,
            onAddTag: { store.send(.editAddTagTapped) },
            onRemoveTag: { store.send(.editRemoveTag($0)) },
            onToggleTagSelection: { store.send(.editToggleTagSelection($0)) },
            relationships: store.editRelationships,
            availableRelationshipTasks: store.availableRelationshipTasks,
            onAddRelationship: { store.send(.editAddRelationship($0, $1)) },
            onRemoveRelationship: { store.send(.editRemoveRelationship($0)) },
            scheduleMode: scheduleModeBinding,
            stepDraft: Binding(
                get: { store.editStepDraft },
                set: { store.send(.editStepDraftChanged($0)) }
            ),
            routineSteps: store.editRoutineSteps,
            onAddStep: { store.send(.editAddStepTapped) },
            onRemoveStep: { store.send(.editRemoveStep($0)) },
            onMoveStepUp: { store.send(.editMoveStepUp($0)) },
            onMoveStepDown: { store.send(.editMoveStepDown($0)) },
            checklistItemDraftTitle: Binding(
                get: { store.editChecklistItemDraftTitle },
                set: { store.send(.editChecklistItemDraftTitleChanged($0)) }
            ),
            checklistItemDraftInterval: Binding(
                get: { store.editChecklistItemDraftInterval },
                set: { store.send(.editChecklistItemDraftIntervalChanged($0)) }
            ),
            routineChecklistItems: store.editRoutineChecklistItems,
            onAddChecklistItem: { store.send(.editAddChecklistItemTapped) },
            onRemoveChecklistItem: { store.send(.editRemoveChecklistItem($0)) },
            availablePlaces: store.availablePlaces,
            selectedPlaceID: Binding(
                get: { store.editSelectedPlaceID },
                set: { store.send(.editSelectedPlaceChanged($0)) }
            ),
            recurrenceKind: recurrenceKindBinding,
            recurrenceHasExplicitTime: recurrenceHasExplicitTimeBinding,
            recurrenceTimeOfDay: recurrenceTimeBinding,
            recurrenceWeekday: recurrenceWeekdayBinding,
            recurrenceDayOfMonth: recurrenceDayOfMonthBinding,
            frequencyUnit: frequencyUnitBinding,
            frequencyValue: Binding(
                get: { store.editFrequencyValue },
                set: { store.send(.editFrequencyValueChanged($0)) }
            ),
            autoAssumeDailyDone: Binding(
                get: { store.editAutoAssumeDailyDone },
                set: { store.send(.editAutoAssumeDailyDoneChanged($0)) }
            ),
            canAutoAssumeDailyDone: store.canAutoAssumeDailyDone,
            color: Binding(
                get: { store.editColor },
                set: { store.send(.editColorChanged($0)) }
            ),
            autofocusName: false,
            onDelete: { store.send(.setDeleteConfirmation(true)) }
        )
    }

    private var taskTypeBinding: Binding<RoutineTaskType> {
        Binding(
            get: { store.editScheduleMode.taskType },
            set: { taskType in
                let nextMode: RoutineScheduleMode
                switch taskType {
                case .routine:
                    nextMode = store.editScheduleMode == .oneOff ? .fixedInterval : store.editScheduleMode
                case .todo:
                    nextMode = .oneOff
                }
                store.send(.editScheduleModeChanged(nextMode))
            }
        )
    }

    private var scheduleModeBinding: Binding<RoutineScheduleMode> {
        Binding(
            get: { store.editScheduleMode },
            set: { store.send(.editScheduleModeChanged($0)) }
        )
    }

    private var editDeadlineEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.editDeadline != nil },
            set: { store.send(.editDeadlineEnabledChanged($0)) }
        )
    }

    private var editDeadlineBinding: Binding<Date> {
        Binding(
            get: { store.editDeadline ?? Date() },
            set: { store.send(.editDeadlineDateChanged($0)) }
        )
    }

    private var editImportanceBinding: Binding<RoutineTaskImportance> {
        Binding(
            get: { store.editImportance },
            set: { store.send(.editImportanceChanged($0)) }
        )
    }

    private var editUrgencyBinding: Binding<RoutineTaskUrgency> {
        Binding(
            get: { store.editUrgency },
            set: { store.send(.editUrgencyChanged($0)) }
        )
    }

    private var recurrenceKindBinding: Binding<RoutineRecurrenceRule.Kind> {
        Binding(
            get: { store.editRecurrenceKind },
            set: { store.send(.editRecurrenceKindChanged($0)) }
        )
    }

    private var recurrenceTimeBinding: Binding<Date> {
        Binding(
            get: { store.editRecurrenceTimeOfDay.date(on: Date()) },
            set: { store.send(.editRecurrenceTimeOfDayChanged(RoutineTimeOfDay.from($0))) }
        )
    }

    private var recurrenceHasExplicitTimeBinding: Binding<Bool> {
        Binding(
            get: { store.editRecurrenceHasExplicitTime },
            set: { store.send(.editRecurrenceHasExplicitTimeChanged($0)) }
        )
    }

    private var recurrenceWeekdayBinding: Binding<Int> {
        Binding(
            get: { store.editRecurrenceWeekday },
            set: { store.send(.editRecurrenceWeekdayChanged($0)) }
        )
    }

    private var recurrenceDayOfMonthBinding: Binding<Int> {
        Binding(
            get: { store.editRecurrenceDayOfMonth },
            set: { store.send(.editRecurrenceDayOfMonthChanged($0)) }
        )
    }

    private var frequencyUnitBinding: Binding<TaskFormFrequencyUnit> {
        Binding(
            get: { TaskFormFrequencyUnit(rawValue: store.editFrequency.rawValue) ?? .day },
            set: { store.send(.editFrequencyChanged(TaskDetailFeature.EditFrequency(rawValue: $0.rawValue) ?? .day)) }
        )
    }
}

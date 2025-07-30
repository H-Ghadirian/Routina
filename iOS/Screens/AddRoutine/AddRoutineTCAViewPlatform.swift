import SwiftUI

extension View {
    func routinaAddRoutineNameAutofocus(
        isRoutineNameFocused: FocusState<Bool>.Binding
    ) -> some View {
        self
    }

    func routinaAddRoutineSheetFrame() -> some View {
        self
    }

    func routinaAddRoutineEmojiPicker<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented) {
            content()
        }
    }

    func routinaAddRoutinePlatformLinkField() -> some View {
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
    }

    func routinaAddRoutineImageImportSupport(
        isDropTargeted: Binding<Bool>,
        isFileImporterPresented: Binding<Bool>,
        onImport: @escaping (URL) -> Void
    ) -> some View {
        self
    }

    func routinaTaskRelationshipSearchFieldPlatform() -> some View {
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}

extension AddRoutineTCAView {
    var platformAddRoutineContent: some View {
        TaskFormContent(model: makeTaskFormModel())
    }

    @ViewBuilder
    var platformImageImportButton: some View {
        EmptyView()
    }

    @ViewBuilder
    var platformImageDropHint: some View {
        EmptyView()
    }

    private func makeTaskFormModel() -> TaskFormModel {
        TaskFormModel(
            name: routineNameBinding,
            nameValidationMessage: store.organization.nameValidationMessage,
            taskType: taskTypeBinding,
            emoji: routineEmojiBinding,
            emojiOptions: emojiOptions,
            isEmojiPickerPresented: $isEmojiPickerPresented,
            notes: routineNotesBinding,
            link: routineLinkBinding,
            deadlineEnabled: deadlineEnabledBinding,
            deadline: deadlineBinding,
            reminderEnabled: reminderEnabledBinding,
            reminderAt: reminderBinding,
            importance: importanceBinding,
            urgency: urgencyBinding,
            pressure: Binding(
                get: { store.basics.pressure },
                set: { store.send(.pressureChanged($0)) }
            ),
            estimatedDurationMinutes: Binding(
                get: { store.basics.estimatedDurationMinutes },
                set: { store.send(.estimatedDurationChanged($0)) }
            ),
            storyPoints: Binding(
                get: { store.basics.storyPoints },
                set: { store.send(.storyPointsChanged($0)) }
            ),
            imageData: store.basics.imageData,
            onImagePicked: { store.send(.imagePicked($0)) },
            onRemoveImage: { store.send(.removeImageTapped) },
            attachments: store.basics.attachments,
            onAttachmentPicked: { store.send(.attachmentPicked($0, $1)) },
            onRemoveAttachment: { store.send(.removeAttachment($0)) },
            tagDraft: tagDraftBinding,
            routineTags: store.organization.routineTags,
            availableTags: store.organization.availableTags,
            availableTagSummaries: store.organization.availableTagSummaries,
            relatedTagRules: store.organization.relatedTagRules,
            tagCounterDisplayMode: store.organization.tagCounterDisplayMode,
            onAddTag: { store.send(.addTagTapped) },
            onRemoveTag: { store.send(.removeTag($0)) },
            onToggleTagSelection: { store.send(.toggleTagSelection($0)) },
            relationships: store.organization.relationships,
            availableRelationshipTasks: store.organization.availableRelationshipTasks,
            onAddRelationship: { store.send(.addRelationship($0, $1)) },
            onRemoveRelationship: { store.send(.removeRelationship($0)) },
            scheduleMode: scheduleModeBinding,
            stepDraft: stepDraftBinding,
            routineSteps: store.checklist.routineSteps,
            onAddStep: { store.send(.addStepTapped) },
            onRemoveStep: { store.send(.removeStep($0)) },
            onMoveStepUp: { store.send(.moveStepUp($0)) },
            onMoveStepDown: { store.send(.moveStepDown($0)) },
            checklistItemDraftTitle: checklistItemDraftTitleBinding,
            checklistItemDraftInterval: checklistItemDraftIntervalBinding,
            routineChecklistItems: store.checklist.routineChecklistItems,
            onAddChecklistItem: { store.send(.addChecklistItemTapped) },
            onRemoveChecklistItem: { store.send(.removeChecklistItem($0)) },
            availablePlaces: store.organization.availablePlaces,
            selectedPlaceID: selectedPlaceBinding,
            recurrenceKind: recurrenceKindBinding,
            recurrenceHasExplicitTime: recurrenceHasExplicitTimeBinding,
            recurrenceTimeOfDay: recurrenceTimeBinding,
            recurrenceWeekday: recurrenceWeekdayBinding,
            recurrenceDayOfMonth: recurrenceDayOfMonthBinding,
            frequencyUnit: frequencyUnitBinding,
            frequencyValue: frequencyValueBinding,
            autoAssumeDailyDone: Binding(
                get: { store.schedule.autoAssumeDailyDone },
                set: { store.send(.autoAssumeDailyDoneChanged($0)) }
            ),
            canAutoAssumeDailyDone: store.canAutoAssumeDailyDone,
            color: Binding(
                get: { store.basics.routineColor },
                set: { store.send(.routineColorChanged($0)) }
            ),
            autofocusName: true,
            onDelete: nil
        )
    }

    private var frequencyUnitBinding: Binding<TaskFormFrequencyUnit> {
        Binding(
            get: { TaskFormFrequencyUnit(rawValue: store.schedule.frequency.rawValue) ?? .day },
            set: { store.send(.frequencyChanged(AddRoutineFeature.Frequency(rawValue: $0.rawValue) ?? .day)) }
        )
    }

    private var recurrenceHasExplicitTimeBinding: Binding<Bool> {
        Binding(
            get: { store.schedule.recurrenceHasExplicitTime },
            set: { store.send(.recurrenceHasExplicitTimeChanged($0)) }
        )
    }

    private var reminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.basics.reminderAt != nil },
            set: { store.send(.reminderEnabledChanged($0)) }
        )
    }

    private var reminderBinding: Binding<Date> {
        Binding(
            get: { store.basics.reminderAt ?? Date() },
            set: { store.send(.reminderDateChanged($0)) }
        )
    }
}

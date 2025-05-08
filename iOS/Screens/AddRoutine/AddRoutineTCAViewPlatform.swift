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
            nameValidationMessage: store.nameValidationMessage,
            taskType: taskTypeBinding,
            emoji: routineEmojiBinding,
            emojiOptions: emojiOptions,
            isEmojiPickerPresented: $isEmojiPickerPresented,
            notes: routineNotesBinding,
            link: routineLinkBinding,
            deadlineEnabled: deadlineEnabledBinding,
            deadline: deadlineBinding,
            importance: importanceBinding,
            urgency: urgencyBinding,
            imageData: store.imageData,
            onImagePicked: { store.send(.imagePicked($0)) },
            onRemoveImage: { store.send(.removeImageTapped) },
            attachments: store.attachments,
            onAttachmentPicked: { store.send(.attachmentPicked($0, $1)) },
            onRemoveAttachment: { store.send(.removeAttachment($0)) },
            tagDraft: tagDraftBinding,
            routineTags: store.routineTags,
            availableTags: store.availableTags,
            onAddTag: { store.send(.addTagTapped) },
            onRemoveTag: { store.send(.removeTag($0)) },
            onToggleTagSelection: { store.send(.toggleTagSelection($0)) },
            relationships: store.relationships,
            availableRelationshipTasks: store.availableRelationshipTasks,
            onAddRelationship: { store.send(.addRelationship($0, $1)) },
            onRemoveRelationship: { store.send(.removeRelationship($0)) },
            scheduleMode: scheduleModeBinding,
            stepDraft: stepDraftBinding,
            routineSteps: store.routineSteps,
            onAddStep: { store.send(.addStepTapped) },
            onRemoveStep: { store.send(.removeStep($0)) },
            onMoveStepUp: { store.send(.moveStepUp($0)) },
            onMoveStepDown: { store.send(.moveStepDown($0)) },
            checklistItemDraftTitle: checklistItemDraftTitleBinding,
            checklistItemDraftInterval: checklistItemDraftIntervalBinding,
            routineChecklistItems: store.routineChecklistItems,
            onAddChecklistItem: { store.send(.addChecklistItemTapped) },
            onRemoveChecklistItem: { store.send(.removeChecklistItem($0)) },
            availablePlaces: store.availablePlaces,
            selectedPlaceID: selectedPlaceBinding,
            recurrenceKind: recurrenceKindBinding,
            recurrenceTimeOfDay: recurrenceTimeBinding,
            recurrenceWeekday: recurrenceWeekdayBinding,
            recurrenceDayOfMonth: recurrenceDayOfMonthBinding,
            frequencyUnit: frequencyUnitBinding,
            frequencyValue: frequencyValueBinding,
            autofocusName: true,
            onDelete: nil
        )
    }

    private var frequencyUnitBinding: Binding<TaskFormFrequencyUnit> {
        Binding(
            get: { TaskFormFrequencyUnit(rawValue: store.frequency.rawValue) ?? .day },
            set: { store.send(.frequencyChanged(AddRoutineFeature.Frequency(rawValue: $0.rawValue) ?? .day)) }
        )
    }
}

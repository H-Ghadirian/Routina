import SwiftUI

extension AddRoutineTCAView {
    var tagComposer: some View {
        AddRoutineTagComposerView(
            tagDraft: tagDraftBinding,
            isAddDisabled: isAddTagDisabled,
            onAddTag: { store.send(.addTagTapped) }
        )
    }

    var manageTagsButton: some View {
        Button {
            isTagManagerPresented = true
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .accessibilityLabel("Manage Tags")
        .help("Manage tags")
    }

    var stepComposer: some View {
        AddRoutineStepComposerView(
            stepDraft: stepDraftBinding,
            isAddDisabled: isAddStepDisabled,
            onAddStep: { store.send(.addStepTapped) }
        )
    }

    var checklistItemComposer: some View {
        AddRoutineChecklistItemComposerView(
            titleDraft: checklistItemDraftTitleBinding,
            intervalDays: checklistItemDraftIntervalBinding,
            showsInterval: store.schedule.scheduleMode.isChecklistDrivenMode,
            intervalLabel: checklistIntervalLabel(for:),
            isAddDisabled: isAddChecklistItemDisabled,
            onAddItem: { store.send(.addChecklistItemTapped) }
        )
    }

    @ViewBuilder
    var availableTagSuggestionsContent: some View {
        AddRoutineAvailableTagSuggestionsView(
            availableTags: store.organization.availableTags,
            selectedTags: store.organization.routineTags,
            onToggleTag: { store.send(.toggleTagSelection($0)) }
        )
    }

    @ViewBuilder
    var editableTagsContent: some View {
        AddRoutineSelectedTagsView(
            selectedTags: store.organization.routineTags,
            isAvailableTagsEmpty: store.organization.availableTags.isEmpty,
            onRemoveTag: { store.send(.removeTag($0)) }
        )
    }

    @ViewBuilder
    var editableStepsContent: some View {
        AddRoutineEditableStepsView(
            steps: store.checklist.routineSteps,
            onMoveStepUp: { store.send(.moveStepUp($0)) },
            onMoveStepDown: { store.send(.moveStepDown($0)) },
            onRemoveStep: { store.send(.removeStep($0)) }
        )
    }

    @ViewBuilder
    var editableChecklistItemsContent: some View {
        AddRoutineChecklistItemsView(
            items: store.checklist.routineChecklistItems,
            showsInterval: store.schedule.scheduleMode.isChecklistDrivenMode,
            intervalLabel: checklistIntervalLabel(for:),
            onRemoveItem: { store.send(.removeChecklistItem($0)) }
        )
    }
}

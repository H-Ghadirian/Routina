import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers
import PhotosUI

struct AddRoutineTCAView: View {
    let store: StoreOf<AddRoutineFeature>
    @FocusState var isRoutineNameFocused: Bool
    @State var isEmojiPickerPresented = false
    @State var selectedPhotoItem: PhotosPickerItem?
    @State var isImageFileImporterPresented = false
    @State var isImageDropTargeted = false
    @State var isTagManagerPresented = false
    @State var tagManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    let emojiOptions = EmojiCatalog.uniqueQuick
    let allEmojiOptions = EmojiCatalog.searchableAll

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                addRoutineContent
                .routinaAddRoutineNavigationChrome(store: store, isSaveDisabled: isSaveDisabled)
                .routinaAddRoutineNameAutofocus(isRoutineNameFocused: $isRoutineNameFocused)
                .routinaAddRoutineEmojiPicker(isPresented: $isEmojiPickerPresented) {
                    EmojiPickerSheet(
                        selectedEmoji: routineEmojiBinding,
                        emojis: allEmojiOptions
                    )
                }
                .sheet(isPresented: $isTagManagerPresented) {
                    SettingsTagManagerPresentationView(store: tagManagerStore)
                }
                .routinaAddRoutineTagNotifications(store: store)
                .routinaAddRoutineSheetFrame()
                .onChange(of: selectedPhotoItem) { _, newItem in
                    guard let newItem else { return }
                    loadPickedImage(from: newItem)
                }
            }
        }
    }

    @ViewBuilder
    var addRoutineContent: some View {
        platformAddRoutineContent
    }

    var isSaveDisabled: Bool {
        store.isSaveDisabled
    }

    var nameValidationMessage: String? {
        store.organization.nameValidationMessage
    }

    private var isAddTagDisabled: Bool {
        RoutineTag.parseDraft(store.organization.tagDraft).isEmpty
    }

    private var isAddStepDisabled: Bool {
        RoutineStep.normalizedTitle(store.checklist.stepDraft) == nil
    }

    private var isAddChecklistItemDisabled: Bool {
        RoutineChecklistItem.normalizedTitle(store.checklist.checklistItemDraftTitle) == nil
    }

    var formPresentation: TaskFormPresentation {
        TaskFormPresentation(
            taskType: store.taskType,
            scheduleMode: store.schedule.scheduleMode,
            recurrenceKind: store.schedule.recurrenceKind,
            recurrenceHasExplicitTime: store.schedule.recurrenceHasExplicitTime,
            recurrenceWeekday: store.schedule.recurrenceWeekday,
            recurrenceDayOfMonth: store.schedule.recurrenceDayOfMonth,
            importance: store.basics.importance,
            urgency: store.basics.urgency,
            hasAvailableTags: !store.organization.availableTags.isEmpty,
            hasAvailableGoals: !store.organization.availableGoals.isEmpty,
            goalDraft: store.organization.goalDraft,
            selectedPlaceName: selectedPlaceName,
            canAutoAssumeDailyDone: store.canAutoAssumeDailyDone
        )
    }

    private var selectedPlaceName: String? {
        guard let selectedPlaceID = store.basics.selectedPlaceID else { return nil }
        return store.organization.availablePlaces.first { $0.id == selectedPlaceID }?.name
    }

    var isStepBasedMode: Bool {
        formPresentation.isStepBasedMode
    }

    var showsRepeatControls: Bool {
        formPresentation.showsRepeatControls
    }

    var taskTypeDescription: String {
        formPresentation.taskTypeDescription
    }

    var scheduleModeDescription: String {
        formPresentation.scheduleModeDescription
    }

    var checklistSectionDescription: String {
        formPresentation.checklistSectionDescription(includesDerivedChecklistDueDetail: true)
    }

    var placeSelectionDescription: String {
        formPresentation.placeSelectionDescription
    }

    var importanceUrgencyDescription: String {
        formPresentation.importanceUrgencyDescription(
            includesDerivedPriority: true,
            priority: store.basics.priority
        )
    }

    var stepsSectionDescription: String {
        formPresentation.stepsSectionDescription
    }

    var tagSectionHelpText: String {
        formPresentation.tagSectionHelpText
    }

    var notesHelpText: String {
        formPresentation.notesHelpText
    }

    var linkHelpText: String {
        formPresentation.linkHelpText
    }

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
            Label("Manage Tags", systemImage: "slider.horizontal.3")
        }
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
            showsInterval: store.schedule.scheduleMode == .derivedFromChecklist,
            intervalLabel: checklistIntervalLabel(for:),
            isAddDisabled: isAddChecklistItemDisabled,
            onAddItem: { store.send(.addChecklistItemTapped) }
        )
    }

    @ViewBuilder
    var imageAttachmentContent: some View {
        AddRoutineImageAttachmentContent(
            imageData: store.basics.imageData,
            onRemove: removeImage,
            imagePreview: { TaskImageView(data: $0) },
            photoPickerButton: { label in
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(label, systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
            },
            importButton: { platformImageImportButton },
            dropHint: { platformImageDropHint }
        )
        .routinaAddRoutineImageImportSupport(
            isDropTargeted: $isImageDropTargeted,
            isFileImporterPresented: $isImageFileImporterPresented,
            onImport: loadPickedImage(fromFileAt:)
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
            showsInterval: store.schedule.scheduleMode == .derivedFromChecklist,
            intervalLabel: checklistIntervalLabel(for:),
            onRemoveItem: { store.send(.removeChecklistItem($0)) }
        )
    }

    private func checklistIntervalLabel(for intervalDays: Int) -> String {
        TaskFormPresentation.checklistIntervalLabel(for: intervalDays)
    }

    private func removeImage() {
        selectedPhotoItem = nil
        store.send(.removeImageTapped)
    }

    @ViewBuilder
    var repeatPatternSections: some View {
        AddRoutineRepeatPatternSections(
            recurrenceKind: recurrenceKindBinding,
            frequency: frequencyBinding,
            frequencyValue: frequencyValueBinding,
            recurrenceTime: recurrenceTimeBinding,
            recurrenceWeekday: recurrenceWeekdayBinding,
            recurrenceDayOfMonth: recurrenceDayOfMonthBinding,
            recurrencePatternDescription: formPresentation.recurrencePatternDescription(includesOptionalExactTimeDetail: false),
            dailyTimeSummary: "Due every day at \(store.schedule.recurrenceTimeOfDay.formatted()).",
            weeklyRecurrenceSummary: formPresentation.weeklyRecurrenceSummary,
            monthlyRecurrenceSummary: formPresentation.monthlyRecurrenceSummary,
            weekdayOptions: weekdayOptions
        )
    }

    var weekdayOptions: [(id: Int, name: String)] {
        let symbols = Calendar.current.weekdaySymbols
        return symbols.enumerated().map { index, name in
            (id: index + 1, name: name)
        }
    }

    private func loadPickedImage(from item: PhotosPickerItem) {
        AddRoutineImageImportSupport.loadPickedImage(
            loadData: { try? await item.loadTransferable(type: Data.self) },
            onImagePicked: { store.send(.imagePicked($0)) }
        )
    }

    private func loadPickedImage(fromFileAt url: URL) {
        AddRoutineImageImportSupport.loadPickedImage(fromFileAt: url) {
            store.send(.imagePicked($0))
        }
    }

}

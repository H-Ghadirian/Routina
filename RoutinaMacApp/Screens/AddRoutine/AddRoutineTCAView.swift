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
    @Environment(\.addEditFormCoordinator) var formCoordinator

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

    var routineNameBinding: Binding<String> {
        Binding(
            get: { store.basics.routineName },
            set: { store.send(.routineNameChanged($0)) }
        )
    }

    var routineEmojiBinding: Binding<String> {
        Binding(
            get: { store.basics.routineEmoji },
            set: { store.send(.routineEmojiChanged($0)) }
        )
    }

    var routineNotesBinding: Binding<String> {
        Binding(
            get: { store.basics.routineNotes },
            set: { store.send(.routineNotesChanged($0)) }
        )
    }

    var routineLinkBinding: Binding<String> {
        Binding(
            get: { store.basics.routineLink },
            set: { store.send(.routineLinkChanged($0)) }
        )
    }

    var taskTypeBinding: Binding<RoutineTaskType> {
        Binding(
            get: { store.taskType },
            set: { store.send(.taskTypeChanged($0)) }
        )
    }

    var tagDraftBinding: Binding<String> {
        Binding(
            get: { store.organization.tagDraft },
            set: { store.send(.tagDraftChanged($0)) }
        )
    }

    var goalDraftBinding: Binding<String> {
        Binding(
            get: { store.organization.goalDraft },
            set: { store.send(.goalDraftChanged($0)) }
        )
    }

    var stepDraftBinding: Binding<String> {
        Binding(
            get: { store.checklist.stepDraft },
            set: { store.send(.stepDraftChanged($0)) }
        )
    }

    var checklistItemDraftTitleBinding: Binding<String> {
        Binding(
            get: { store.checklist.checklistItemDraftTitle },
            set: { store.send(.checklistItemDraftTitleChanged($0)) }
        )
    }

    var checklistItemDraftIntervalBinding: Binding<Int> {
        Binding(
            get: { store.checklist.checklistItemDraftInterval },
            set: { store.send(.checklistItemDraftIntervalChanged($0)) }
        )
    }

    var scheduleModeBinding: Binding<RoutineScheduleMode> {
        Binding(
            get: { store.schedule.scheduleMode },
            set: { store.send(.scheduleModeChanged($0)) }
        )
    }

    var frequencyBinding: Binding<AddRoutineFeature.Frequency> {
        Binding(
            get: { store.schedule.frequency },
            set: { store.send(.frequencyChanged($0)) }
        )
    }

    var frequencyValueBinding: Binding<Int> {
        Binding(
            get: { store.schedule.frequencyValue },
            set: { store.send(.frequencyValueChanged($0)) }
        )
    }

    var recurrenceKindBinding: Binding<RoutineRecurrenceRule.Kind> {
        Binding(
            get: { store.schedule.recurrenceKind },
            set: { store.send(.recurrenceKindChanged($0)) }
        )
    }

    var recurrenceTimeBinding: Binding<Date> {
        Binding(
            get: { store.schedule.recurrenceTimeOfDay.date(on: Date()) },
            set: { store.send(.recurrenceTimeOfDayChanged(RoutineTimeOfDay.from($0))) }
        )
    }

    var recurrenceWeekdayBinding: Binding<Int> {
        Binding(
            get: { store.schedule.recurrenceWeekday },
            set: { store.send(.recurrenceWeekdayChanged($0)) }
        )
    }

    var recurrenceDayOfMonthBinding: Binding<Int> {
        Binding(
            get: { store.schedule.recurrenceDayOfMonth },
            set: { store.send(.recurrenceDayOfMonthChanged($0)) }
        )
    }

    var selectedPlaceBinding: Binding<UUID?> {
        Binding(
            get: { store.basics.selectedPlaceID },
            set: { store.send(.selectedPlaceChanged($0)) }
        )
    }

    var deadlineEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.hasDeadline },
            set: { store.send(.deadlineEnabledChanged($0)) }
        )
    }

    var deadlineBinding: Binding<Date> {
        Binding(
            get: { store.basics.deadline ?? Date() },
            set: { store.send(.deadlineDateChanged($0)) }
        )
    }

    var importanceBinding: Binding<RoutineTaskImportance> {
        Binding(
            get: { store.basics.importance },
            set: { store.send(.importanceChanged($0)) }
        )
    }

    var urgencyBinding: Binding<RoutineTaskUrgency> {
        Binding(
            get: { store.basics.urgency },
            set: { store.send(.urgencyChanged($0)) }
        )
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
        let imagePickerLabel = store.basics.imageData == nil ? "Choose Image" : "Replace Image"

        VStack(alignment: .leading, spacing: 10) {
            if let imageData = store.basics.imageData {
                TaskImageView(data: imageData)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    )
            } else {
                Label("No image selected", systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(imagePickerLabel, systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)

                platformImageImportButton

                if store.basics.imageData != nil {
                    Button("Remove") {
                        selectedPhotoItem = nil
                        store.send(.removeImageTapped)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("Images are resized and compressed before saving to keep iCloud usage low.")
                .font(.caption)
                .foregroundStyle(.secondary)

            platformImageDropHint
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
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

    func stepperLabel(
        frequency: AddRoutineFeature.Frequency,
        frequencyValue: Int
    ) -> String {
        let unit: TaskFormFrequencyUnit
        switch frequency {
        case .day:
            unit = .day
        case .week:
            unit = .week
        case .month:
            unit = .month
        }
        return TaskFormPresentation.stepperLabel(unit: unit, value: frequencyValue)
    }

    private func checklistIntervalLabel(for intervalDays: Int) -> String {
        TaskFormPresentation.checklistIntervalLabel(for: intervalDays)
    }

    @ViewBuilder
    var repeatPatternSections: some View {
        Section(header: Text("Repeat Pattern")) {
            Picker("Repeat Pattern", selection: recurrenceKindBinding) {
                ForEach(RoutineRecurrenceRule.Kind.allCases, id: \.self) { kind in
                    Text(kind.pickerTitle).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            Text(recurrencePatternDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        switch store.schedule.recurrenceKind {
        case .intervalDays:
            Section(header: Text("Frequency")) {
                Picker("Frequency", selection: frequencyBinding) {
                    ForEach(AddRoutineFeature.Frequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Repeat")) {
                Stepper(value: frequencyValueBinding, in: 1...365) {
                    Text(
                        stepperLabel(
                            frequency: store.schedule.frequency,
                            frequencyValue: store.schedule.frequencyValue
                        )
                    )
                }
            }

        case .dailyTime:
            Section(header: Text("Time of Day")) {
                DatePicker(
                    "Time",
                    selection: recurrenceTimeBinding,
                    displayedComponents: .hourAndMinute
                )

                Text("Due every day at \(store.schedule.recurrenceTimeOfDay.formatted()).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .weekly:
            Section(header: Text("Weekday")) {
                Picker("Weekday", selection: recurrenceWeekdayBinding) {
                    ForEach(weekdayOptions, id: \.id) { option in
                        Text(option.name).tag(option.id)
                    }
                }

                Text(formPresentation.weeklyRecurrenceSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .monthlyDay:
            Section(header: Text("Day of Month")) {
                Stepper(value: recurrenceDayOfMonthBinding, in: 1...31) {
                    Text("Every \(TaskFormPresentation.ordinalDay(store.schedule.recurrenceDayOfMonth))")
                }

                Text(formPresentation.monthlyRecurrenceSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var recurrencePatternDescription: String {
        formPresentation.recurrencePatternDescription(includesOptionalExactTimeDetail: false)
    }

    var weekdayOptions: [(id: Int, name: String)] {
        let symbols = Calendar.current.weekdaySymbols
        return symbols.enumerated().map { index, name in
            (id: index + 1, name: name)
        }
    }

    private func loadPickedImage(from item: PhotosPickerItem) {
        _ = Task {
            let data = try? await item.loadTransferable(type: Data.self)
            _ = await MainActor.run {
                store.send(.imagePicked(data))
            }
        }
    }

    private func loadPickedImage(fromFileAt url: URL) {
        let compressedData = TaskImageProcessor.compressedImageData(fromFileAt: url)
        store.send(.imagePicked(compressedData))
    }

}

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
                .navigationTitle("Add Task")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            store.send(.cancelTapped)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.send(.saveTapped)
                        }
                        .disabled(isSaveDisabled)
                    }
                }
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
                .onReceive(
                    NotificationCenter.default.publisher(for: .routineTagDidRename)
                        .receive(on: RunLoop.main)
                ) { notification in
                    guard let payload = notification.routineTagRenamePayload else { return }
                    store.send(.tagRenamed(oldName: payload.oldName, newName: payload.newName))
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: .routineTagDidDelete)
                        .receive(on: RunLoop.main)
                ) { notification in
                    guard let tagName = notification.routineTagDeletedName else { return }
                    store.send(.tagDeleted(tagName))
                }
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

    var isStepBasedMode: Bool {
        store.schedule.scheduleMode == .fixedInterval || store.schedule.scheduleMode == .softInterval || store.schedule.scheduleMode == .oneOff
    }

    var showsRepeatControls: Bool {
        store.schedule.scheduleMode != .derivedFromChecklist && store.schedule.scheduleMode != .oneOff
    }

    var taskTypeDescription: String {
        switch store.taskType {
        case .routine:
            return "Routines repeat on a schedule and stay in your rotation."
        case .todo:
            return "Todos are one-off tasks. Once you finish one, it stays completed."
        }
    }

    var scheduleModeDescription: String {
        switch store.schedule.scheduleMode {
        case .fixedInterval:
            return "Use one overall repeat interval for the whole routine."
        case .softInterval:
            return "Keep this routine visible all the time and gently highlight it again after a while."
        case .fixedIntervalChecklist:
            return "Use one overall repeat interval and complete every checklist item to finish the routine."
        case .derivedFromChecklist:
            return "Use checklist item due dates to decide when the routine is due."
        case .oneOff:
            return "This task does not repeat."
        }
    }

    var checklistSectionDescription: String {
        switch store.schedule.scheduleMode {
        case .fixedIntervalChecklist:
            return "The routine is done when every checklist item is completed."
        case .derivedFromChecklist:
            return "Each item gets its own due date. The routine becomes due when the earliest item is due."
        case .fixedInterval, .softInterval, .oneOff:
            return ""
        }
    }

    var placeSelectionDescription: String {
        if let selectedPlaceID = store.basics.selectedPlaceID,
           let place = store.organization.availablePlaces.first(where: { $0.id == selectedPlaceID }) {
            return "Show this task when you are at \(place.name)."
        }
        return "Anywhere means the task is always visible."
    }

    var importanceUrgencyDescription: String {
        "\(store.basics.importance.title) importance and \(store.basics.urgency.title.lowercased()) urgency map to \(store.basics.priority.title.lowercased()) priority for sorting."
    }

    var stepsSectionDescription: String {
        if store.schedule.scheduleMode == .oneOff {
            return "Steps run in order. Leave this empty for a single-step todo."
        }
        return "Steps run in order. Leave this empty for a one-step routine."
    }

    var tagSectionHelpText: String {
        if store.organization.availableTags.isEmpty {
            return "Press return or Add. Separate multiple tags with commas, or open Manage Tags."
        }
        return "Tap an existing tag below, open Manage Tags, or press return/Add to create a new one. Separate multiple tags with commas."
    }

    var notesHelpText: String {
        store.taskType == .todo
            ? "Capture extra context, links, or reminders for this todo."
            : "Add any details you want to keep with this routine."
    }

    var linkHelpText: String {
        "Add a website to open from the task detail screen. If you skip the scheme, https will be used."
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
        if frequencyValue == 1 {
            switch frequency {
            case .day:
                return "Every day"
            case .week:
                return "Every week"
            case .month:
                return "Every month"
            }
        }

        let unit = frequency.singularLabel
        return "Every \(frequencyValue) \(unit)s"
    }

    private func checklistIntervalLabel(for intervalDays: Int) -> String {
        if intervalDays == 1 {
            return "Runs out in 1 day"
        }
        return "Runs out in \(intervalDays) days"
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

                Text("Due every \(weekdayName(for: store.schedule.recurrenceWeekday)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .monthlyDay:
            Section(header: Text("Day of Month")) {
                Stepper(value: recurrenceDayOfMonthBinding, in: 1...31) {
                    Text("Every \(ordinalDay(store.schedule.recurrenceDayOfMonth))")
                }

                Text("Due on the \(ordinalDay(store.schedule.recurrenceDayOfMonth)) of each month.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var recurrencePatternDescription: String {
        switch store.schedule.recurrenceKind {
        case .intervalDays:
            return "Repeat after a fixed number of days, weeks, or months."
        case .dailyTime:
            return "Repeat every day at a specific time."
        case .weekly:
            return "Repeat on the same weekday each week."
        case .monthlyDay:
            return "Repeat on the same calendar day each month."
        }
    }

    var weekdayOptions: [(id: Int, name: String)] {
        let symbols = Calendar.current.weekdaySymbols
        return symbols.enumerated().map { index, name in
            (id: index + 1, name: name)
        }
    }

    func weekdayName(for weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let safeIndex = min(max(weekday - 1, 0), max(symbols.count - 1, 0))
        return symbols[safeIndex]
    }

    func ordinalDay(_ day: Int) -> String {
        let resolvedDay = min(max(day, 1), 31)
        let suffix: String
        switch resolvedDay % 100 {
        case 11, 12, 13:
            suffix = "th"
        default:
            switch resolvedDay % 10 {
            case 1:
                suffix = "st"
            case 2:
                suffix = "nd"
            case 3:
                suffix = "rd"
            default:
                suffix = "th"
            }
        }
        return "\(resolvedDay)\(suffix)"
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

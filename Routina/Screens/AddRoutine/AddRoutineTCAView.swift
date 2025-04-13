import SwiftUI
import ComposableArchitecture
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif

struct AddRoutineTCAView: View {
    let store: StoreOf<AddRoutineFeature>
    @FocusState private var isRoutineNameFocused: Bool
    @State private var isEmojiPickerPresented = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isImageFileImporterPresented = false
    @State private var isImageDropTargeted = false
    @State private var isTagManagerPresented = false
    @State private var tagManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    private let emojiOptions = EmojiCatalog.uniqueQuick
    private let allEmojiOptions = EmojiCatalog.searchableAll

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
    private var addRoutineContent: some View {
        #if os(macOS)
        macOSContent
        #else
        Form {
            Section(header: Text("Name")) {
                TextField("Task name", text: routineNameBinding)
                    .focused($isRoutineNameFocused)
                if let nameValidationMessage {
                    Text(nameValidationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(header: Text("Task Type")) {
                Picker("Task Type", selection: taskTypeBinding) {
                    Text("Routine").tag(RoutineTaskType.routine)
                    Text("Todo").tag(RoutineTaskType.todo)
                }
                .pickerStyle(.segmented)

                Text(taskTypeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Emoji")) {
                HStack(spacing: 12) {
                    Text("Selected")
                        .foregroundColor(.secondary)
                    Text(store.routineEmoji)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                    Spacer()
                    Button("Choose Emoji") {
                        isEmojiPickerPresented = true
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button {
                                store.send(.routineEmojiChanged(emoji))
                            } label: {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(store.routineEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(header: Text("Notes")) {
                TextField("Add notes", text: routineNotesBinding, axis: .vertical)
                    .lineLimit(4...8)

                Text(notesHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Link")) {
                TextField("https://example.com", text: routineLinkBinding)
                    .textInputAutocapitalization(.never)
#if !os(macOS)
                    .autocorrectionDisabled()
#endif
                    .keyboardType(.URL)

                Text(linkHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.taskType == .todo {
                Section(header: Text("Deadline")) {
                    Toggle("Set deadline", isOn: deadlineEnabledBinding)
                    if store.hasDeadline {
                        DatePicker("Deadline", selection: deadlineBinding)
                    }
                }
            }

            Section(header: Text("Image")) {
                imageAttachmentContent
            }

            Section(header: Text("Tags")) {
                tagComposer
                availableTagSuggestionsContent
                manageTagsButton
                editableTagsContent

                Text(tagSectionHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Relationships")) {
                TaskRelationshipsEditor(
                    relationships: store.relationships,
                    candidates: store.availableRelationshipTasks,
                    addRelationship: { store.send(.addRelationship($0, $1)) },
                    removeRelationship: { store.send(.removeRelationship($0)) }
                )

                Text("Link this task to another task as related work or a blocker.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.taskType == .routine {
                Section(header: Text("Schedule Type")) {
                    Picker("Schedule Type", selection: scheduleModeBinding) {
                        Text("Fixed").tag(RoutineScheduleMode.fixedInterval)
                        Text("Checklist").tag(RoutineScheduleMode.fixedIntervalChecklist)
                        Text("Runout").tag(RoutineScheduleMode.derivedFromChecklist)
                    }
                    .pickerStyle(.segmented)

                    Text(scheduleModeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isStepBasedMode {
                Section(header: Text("Steps")) {
                    stepComposer
                    editableStepsContent

                    Text(stepsSectionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(header: Text("Checklist Items")) {
                    checklistItemComposer
                    editableChecklistItemsContent

                    Text(checklistSectionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("Place")) {
                Picker("Place", selection: selectedPlaceBinding) {
                    Text("Anywhere").tag(Optional<UUID>.none)
                    ForEach(store.availablePlaces) { place in
                        Text(place.name).tag(Optional(place.id))
                    }
                }

                Text(placeSelectionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if showsRepeatControls {
                repeatPatternSections
            }
        }
        #endif
    }

    private var routineNameBinding: Binding<String> {
        Binding(
            get: { store.routineName },
            set: { store.send(.routineNameChanged($0)) }
        )
    }

    private var routineEmojiBinding: Binding<String> {
        Binding(
            get: { store.routineEmoji },
            set: { store.send(.routineEmojiChanged($0)) }
        )
    }

    private var routineNotesBinding: Binding<String> {
        Binding(
            get: { store.routineNotes },
            set: { store.send(.routineNotesChanged($0)) }
        )
    }

    private var routineLinkBinding: Binding<String> {
        Binding(
            get: { store.routineLink },
            set: { store.send(.routineLinkChanged($0)) }
        )
    }

    private var taskTypeBinding: Binding<RoutineTaskType> {
        Binding(
            get: { store.taskType },
            set: { store.send(.taskTypeChanged($0)) }
        )
    }

    private var tagDraftBinding: Binding<String> {
        Binding(
            get: { store.tagDraft },
            set: { store.send(.tagDraftChanged($0)) }
        )
    }

    private var stepDraftBinding: Binding<String> {
        Binding(
            get: { store.stepDraft },
            set: { store.send(.stepDraftChanged($0)) }
        )
    }

    private var checklistItemDraftTitleBinding: Binding<String> {
        Binding(
            get: { store.checklistItemDraftTitle },
            set: { store.send(.checklistItemDraftTitleChanged($0)) }
        )
    }

    private var checklistItemDraftIntervalBinding: Binding<Int> {
        Binding(
            get: { store.checklistItemDraftInterval },
            set: { store.send(.checklistItemDraftIntervalChanged($0)) }
        )
    }

    private var scheduleModeBinding: Binding<RoutineScheduleMode> {
        Binding(
            get: { store.scheduleMode },
            set: { store.send(.scheduleModeChanged($0)) }
        )
    }

    private var frequencyBinding: Binding<AddRoutineFeature.Frequency> {
        Binding(
            get: { store.frequency },
            set: { store.send(.frequencyChanged($0)) }
        )
    }

    private var frequencyValueBinding: Binding<Int> {
        Binding(
            get: { store.frequencyValue },
            set: { store.send(.frequencyValueChanged($0)) }
        )
    }

    private var recurrenceKindBinding: Binding<RoutineRecurrenceRule.Kind> {
        Binding(
            get: { store.recurrenceKind },
            set: { store.send(.recurrenceKindChanged($0)) }
        )
    }

    private var recurrenceTimeBinding: Binding<Date> {
        Binding(
            get: { store.recurrenceTimeOfDay.date(on: Date()) },
            set: { store.send(.recurrenceTimeOfDayChanged(RoutineTimeOfDay.from($0))) }
        )
    }

    private var recurrenceWeekdayBinding: Binding<Int> {
        Binding(
            get: { store.recurrenceWeekday },
            set: { store.send(.recurrenceWeekdayChanged($0)) }
        )
    }

    private var recurrenceDayOfMonthBinding: Binding<Int> {
        Binding(
            get: { store.recurrenceDayOfMonth },
            set: { store.send(.recurrenceDayOfMonthChanged($0)) }
        )
    }

    private var selectedPlaceBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedPlaceID },
            set: { store.send(.selectedPlaceChanged($0)) }
        )
    }

    private var deadlineEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.hasDeadline },
            set: { store.send(.deadlineEnabledChanged($0)) }
        )
    }

    private var deadlineBinding: Binding<Date> {
        Binding(
            get: { store.deadline ?? Date() },
            set: { store.send(.deadlineDateChanged($0)) }
        )
    }

    private var isSaveDisabled: Bool {
        store.isSaveDisabled
    }

    private var nameValidationMessage: String? {
        store.nameValidationMessage
    }

    private var isAddTagDisabled: Bool {
        RoutineTag.parseDraft(store.tagDraft).isEmpty
    }

    private var isAddStepDisabled: Bool {
        RoutineStep.normalizedTitle(store.stepDraft) == nil
    }

    private var isAddChecklistItemDisabled: Bool {
        RoutineChecklistItem.normalizedTitle(store.checklistItemDraftTitle) == nil
    }

    private var isStepBasedMode: Bool {
        store.scheduleMode == .fixedInterval || store.scheduleMode == .oneOff
    }

    private var showsRepeatControls: Bool {
        store.scheduleMode != .derivedFromChecklist && store.scheduleMode != .oneOff
    }

    private var taskTypeDescription: String {
        switch store.taskType {
        case .routine:
            return "Routines repeat on a schedule and stay in your rotation."
        case .todo:
            return "Todos are one-off tasks. Once you finish one, it stays completed."
        }
    }

    private var scheduleModeDescription: String {
        switch store.scheduleMode {
        case .fixedInterval:
            return "Use one overall repeat interval for the whole routine."
        case .fixedIntervalChecklist:
            return "Use one overall repeat interval and complete every checklist item to finish the routine."
        case .derivedFromChecklist:
            return "Use checklist item due dates to decide when the routine is due."
        case .oneOff:
            return "This task does not repeat."
        }
    }

    private var checklistSectionDescription: String {
        switch store.scheduleMode {
        case .fixedIntervalChecklist:
            return "The routine is done when every checklist item is completed."
        case .derivedFromChecklist:
            return "Each item gets its own due date. The routine becomes due when the earliest item is due."
        case .fixedInterval, .oneOff:
            return ""
        }
    }

    private var placeSelectionDescription: String {
        if let selectedPlaceID = store.selectedPlaceID,
           let place = store.availablePlaces.first(where: { $0.id == selectedPlaceID }) {
            return "Show this task when you are at \(place.name)."
        }
        return "Anywhere means the task is always visible."
    }

    private var stepsSectionDescription: String {
        if store.scheduleMode == .oneOff {
            return "Steps run in order. Leave this empty for a single-step todo."
        }
        return "Steps run in order. Leave this empty for a one-step routine."
    }

    private var tagSectionHelpText: String {
        if store.availableTags.isEmpty {
            return "Press return or Add. Separate multiple tags with commas, or open Manage Tags."
        }
        return "Tap an existing tag below, open Manage Tags, or press return/Add to create a new one. Separate multiple tags with commas."
    }

    private var notesHelpText: String {
        store.taskType == .todo
            ? "Capture extra context, links, or reminders for this todo."
            : "Add any details you want to keep with this routine."
    }

    private var linkHelpText: String {
        "Add a website to open from the task detail screen. If you skip the scheme, https will be used."
    }

    private var tagComposer: some View {
        HStack(spacing: 10) {
            TextField("health, focus, morning", text: tagDraftBinding)
                .onSubmit {
                    store.send(.addTagTapped)
                }

            Button("Add") {
                store.send(.addTagTapped)
            }
            .disabled(isAddTagDisabled)
        }
    }

    private var manageTagsButton: some View {
        Button {
            isTagManagerPresented = true
        } label: {
            Label("Manage Tags", systemImage: "slider.horizontal.3")
        }
    }

    private var stepComposer: some View {
        HStack(spacing: 10) {
            TextField("Wash clothes", text: stepDraftBinding)
                .onSubmit {
                    store.send(.addStepTapped)
                }

            Button("Add") {
                store.send(.addStepTapped)
            }
            .disabled(isAddStepDisabled)
        }
    }

    private var checklistItemComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Bread", text: checklistItemDraftTitleBinding)
                .onSubmit {
                    store.send(.addChecklistItemTapped)
                }

            if store.scheduleMode == .derivedFromChecklist {
                Stepper(value: checklistItemDraftIntervalBinding, in: 1...365) {
                    Text(checklistIntervalLabel(for: store.checklistItemDraftInterval))
                }
            }

            Button("Add Item") {
                store.send(.addChecklistItemTapped)
            }
            .disabled(isAddChecklistItemDisabled)
        }
    }

    @ViewBuilder
    private var imageAttachmentContent: some View {
        let imagePickerLabel = store.imageData == nil ? "Choose Image" : "Replace Image"

        VStack(alignment: .leading, spacing: 10) {
            if let imageData = store.imageData {
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

#if os(macOS)
                Button(store.imageData == nil ? "Browse in Finder" : "Browse Another File") {
                    isImageFileImporterPresented = true
                }
                .buttonStyle(.bordered)
#endif

                if store.imageData != nil {
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

#if os(macOS)
            Text("You can also drag an image from Finder onto this area.")
                .font(.caption)
                .foregroundStyle(.secondary)
#endif
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
#if os(macOS)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isImageDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isImageDropTargeted ? Color.accentColor : Color.secondary.opacity(0.18),
                    style: StrokeStyle(lineWidth: isImageDropTargeted ? 2 : 1, dash: [8, 6])
                )
        )
        .dropDestination(for: URL.self) { urls, _ in
            guard let imageURL = urls.first(where: { isSupportedImageFile($0) }) else {
                return false
            }
            loadPickedImage(fromFileAt: imageURL)
            return true
        } isTargeted: { isTargeted in
            isImageDropTargeted = isTargeted
        }
        .fileImporter(
            isPresented: $isImageFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleImageFileImport(result)
        }
#endif
    }

    @ViewBuilder
    private var availableTagSuggestionsContent: some View {
        if !store.availableTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose from existing tags")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(store.availableTags, id: \.self) { tag in
                        let isSelected = RoutineTag.contains(tag, in: store.routineTags)
                        Button {
                            store.send(.toggleTagSelection(tag))
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.caption)
                                Text("#\(tag)")
                                    .lineLimit(1)
                            }
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(isSelected ? "Remove" : "Add") tag \(tag)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var editableTagsContent: some View {
        if store.routineTags.isEmpty {
            Text(store.availableTags.isEmpty ? "No tags yet" : "No selected tags yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(store.routineTags, id: \.self) { tag in
                    Button {
                        store.send(.removeTag(tag))
                    } label: {
                        HStack(spacing: 6) {
                            Text("#\(tag)")
                                .lineLimit(1)
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove tag \(tag)")
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var editableStepsContent: some View {
        if store.routineSteps.isEmpty {
            Text("No steps yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(Array(store.routineSteps.enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 10) {
                        Text("\(index + 1).")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .leading)

                        Text(step.title)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 6) {
                            Button {
                                store.send(.moveStepUp(step.id))
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)

                            Button {
                                store.send(.moveStepDown(step.id))
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == store.routineSteps.count - 1)

                            Button(role: .destructive) {
                                store.send(.removeStep(step.id))
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var editableChecklistItemsContent: some View {
        if store.routineChecklistItems.isEmpty {
            Text("No checklist items yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(store.routineChecklistItems) { item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if store.scheduleMode == .derivedFromChecklist {
                                Text(checklistIntervalLabel(for: item.intervalDays))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button(role: .destructive) {
                            store.send(.removeChecklistItem(item.id))
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func stepperLabel(
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
    private var repeatPatternSections: some View {
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

        switch store.recurrenceKind {
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
                            frequency: store.frequency,
                            frequencyValue: store.frequencyValue
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

                Text("Due every day at \(store.recurrenceTimeOfDay.formatted()).")
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

                Text("Due every \(weekdayName(for: store.recurrenceWeekday)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .monthlyDay:
            Section(header: Text("Day of Month")) {
                Stepper(value: recurrenceDayOfMonthBinding, in: 1...31) {
                    Text("Every \(ordinalDay(store.recurrenceDayOfMonth))")
                }

                Text("Due on the \(ordinalDay(store.recurrenceDayOfMonth)) of each month.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recurrencePatternDescription: String {
        switch store.recurrenceKind {
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

    private var weekdayOptions: [(id: Int, name: String)] {
        let symbols = Calendar.current.weekdaySymbols
        return symbols.enumerated().map { index, name in
            (id: index + 1, name: name)
        }
    }

    private func weekdayName(for weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let safeIndex = min(max(weekday - 1, 0), max(symbols.count - 1, 0))
        return symbols[safeIndex]
    }

    private func ordinalDay(_ day: Int) -> String {
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

#if os(macOS)
    private let formLabelWidth: CGFloat = 110

    private var sectionCardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor)
    }

    private var sectionCardStroke: Color {
        Color.gray.opacity(0.18)
    }

    private var macOSContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                macSectionCard(title: "Basic") {
                    VStack(alignment: .leading, spacing: 14) {
                        macFormRow("Name") {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Task name", text: routineNameBinding)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($isRoutineNameFocused)
                                if let nameValidationMessage {
                                    Text(nameValidationMessage)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }

                        macFormRow("Emoji") {
                            HStack(spacing: 12) {
                                Text(store.routineEmoji)
                                    .font(.title2)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.16))
                                    )
                                Text("Selected")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                                Button("Choose Emoji") {
                                    isEmojiPickerPresented = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        macFormRow("Quick Picks") {
                            HStack(spacing: 6) {
                                ForEach(Array(emojiOptions.prefix(8)), id: \.self) { emoji in
                                    Button {
                                        store.send(.routineEmojiChanged(emoji))
                                    } label: {
                                        Text(emoji)
                                            .font(.title3)
                                            .frame(width: 30, height: 30)
                                            .background(
                                                Circle()
                                                    .fill(store.routineEmoji == emoji ? Color.accentColor.opacity(0.18) : Color.clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        macFormRow("Tags") {
                            VStack(alignment: .leading, spacing: 10) {
                                tagComposer
                                availableTagSuggestionsContent
                                manageTagsButton
                                editableTagsContent
                                Text(tagSectionHelpText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        macFormRow("Links") {
                            VStack(alignment: .leading, spacing: 10) {
                                TaskRelationshipsEditor(
                                    relationships: store.relationships,
                                    candidates: store.availableRelationshipTasks,
                                    addRelationship: { store.send(.addRelationship($0, $1)) },
                                    removeRelationship: { store.send(.removeRelationship($0)) }
                                )

                                Text("Link this task to another task as related work or a blocker.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        macFormRow("Notes") {
                            VStack(alignment: .leading, spacing: 8) {
                                TextEditor(text: routineNotesBinding)
                                    .frame(minHeight: 96)
                                    .padding(6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color(nsColor: .textBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(sectionCardStroke, lineWidth: 1)
                                    )

                                Text(notesHelpText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        macFormRow("Link") {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("https://example.com", text: routineLinkBinding)
                                    .textFieldStyle(.roundedBorder)

                                Text(linkHelpText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        macFormRow("Task Type") {
                            VStack(alignment: .leading, spacing: 10) {
                                Picker("Task Type", selection: taskTypeBinding) {
                                    Text("Routine").tag(RoutineTaskType.routine)
                                    Text("Todo").tag(RoutineTaskType.todo)
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .frame(width: 260)

                                Text(taskTypeDescription)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if store.taskType == .routine {
                            macFormRow("Schedule") {
                                VStack(alignment: .leading, spacing: 10) {
                                    Picker("Schedule Type", selection: scheduleModeBinding) {
                                        Text("Fixed").tag(RoutineScheduleMode.fixedInterval)
                                        Text("Checklist").tag(RoutineScheduleMode.fixedIntervalChecklist)
                                        Text("Runout").tag(RoutineScheduleMode.derivedFromChecklist)
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.segmented)
                                    .frame(width: 320)

                                    Text(scheduleModeDescription)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        macFormRow("Place") {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("Place", selection: selectedPlaceBinding) {
                                    Text("Anywhere").tag(Optional<UUID>.none)
                                    ForEach(store.availablePlaces) { place in
                                        Text(place.name).tag(Optional(place.id))
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)

                                Text(placeSelectionDescription)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if store.taskType == .todo {
                            macFormRow("Deadline") {
                                VStack(alignment: .leading, spacing: 10) {
                                    Toggle("Set deadline", isOn: deadlineEnabledBinding)
                                    if store.hasDeadline {
                                        DatePicker("Deadline", selection: deadlineBinding)
                                            .labelsHidden()
                                    }
                                }
                            }
                        }

                        if isStepBasedMode {
                            macFormRow("Steps") {
                                VStack(alignment: .leading, spacing: 10) {
                                    stepComposer
                                    editableStepsContent
                                    Text(stepsSectionDescription)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            macFormRow("Checklist") {
                                VStack(alignment: .leading, spacing: 10) {
                                    checklistItemComposer
                                    editableChecklistItemsContent
                                    Text(checklistSectionDescription)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                macSectionCard(title: "Image") {
                    imageAttachmentContent
                }

                if showsRepeatControls {
                    macSectionCard(title: "Schedule") {
                        VStack(alignment: .leading, spacing: 10) {
                            macFormRow("Pattern") {
                                VStack(alignment: .leading, spacing: 10) {
                                    Picker("Repeat Pattern", selection: recurrenceKindBinding) {
                                        ForEach(RoutineRecurrenceRule.Kind.allCases, id: \.self) { kind in
                                            Text(kind.pickerTitle).tag(kind)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.segmented)
                                    .frame(width: 320)

                                    Text(recurrencePatternDescription)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            switch store.recurrenceKind {
                            case .intervalDays:
                                macFormRow("Repeat") {
                                    HStack(spacing: 10) {
                                        Text("Every")
                                            .foregroundStyle(.secondary)
                                        Stepper(value: frequencyValueBinding, in: 1...365) {
                                            Text("\(store.frequencyValue)")
                                                .font(.body.monospacedDigit())
                                                .frame(minWidth: 28, alignment: .trailing)
                                        }
                                        .fixedSize()
                                        Picker("Unit", selection: frequencyBinding) {
                                            ForEach(AddRoutineFeature.Frequency.allCases, id: \.self) { frequency in
                                                Text(frequency.rawValue).tag(frequency)
                                            }
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.segmented)
                                        .frame(width: 220)
                                        Spacer(minLength: 0)
                                    }
                                }

                                macFormRow("") {
                                    Text(stepperLabel(frequency: store.frequency, frequencyValue: store.frequencyValue))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                            case .dailyTime:
                                macFormRow("Time") {
                                    DatePicker(
                                        "Time",
                                        selection: recurrenceTimeBinding,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .labelsHidden()
                                }

                                macFormRow("") {
                                    Text("Due every day at \(store.recurrenceTimeOfDay.formatted()).")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                            case .weekly:
                                macFormRow("Weekday") {
                                    Picker("Weekday", selection: recurrenceWeekdayBinding) {
                                        ForEach(weekdayOptions, id: \.id) { option in
                                            Text(option.name).tag(option.id)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                }

                                macFormRow("") {
                                    Text("Due every \(weekdayName(for: store.recurrenceWeekday)).")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                            case .monthlyDay:
                                macFormRow("Month Day") {
                                    Stepper(value: recurrenceDayOfMonthBinding, in: 1...31) {
                                        Text(ordinalDay(store.recurrenceDayOfMonth))
                                            .frame(minWidth: 40, alignment: .leading)
                                    }
                                    .fixedSize()
                                }

                                macFormRow("") {
                                    Text("Due on the \(ordinalDay(store.recurrenceDayOfMonth)) of each month.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func macSectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(sectionCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(sectionCardStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func macFormRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(title.isEmpty ? " " : title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: formLabelWidth, alignment: .trailing)
            content()
        }
    }
#endif

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

#if os(macOS)
    private func handleImageFileImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result,
              let imageURL = urls.first(where: { isSupportedImageFile($0) }) else {
            return
        }
        loadPickedImage(fromFileAt: imageURL)
    }

    private func isSupportedImageFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return false
        }
        return type.conforms(to: .image)
    }
#endif
}

struct TaskRelationshipsEditor: View {
    let relationships: [RoutineTaskRelationship]
    let candidates: [RoutineTaskRelationshipCandidate]
    let addRelationship: (UUID, RoutineTaskRelationshipKind) -> Void
    let removeRelationship: (UUID) -> Void

    @State private var isPickerPresented = false

    private var resolvedRelationships: [RoutineTaskResolvedRelationship] {
        let candidateByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        return relationships.compactMap { relationship in
            guard let candidate = candidateByID[relationship.targetTaskID] else { return nil }
            return RoutineTaskResolvedRelationship(
                taskID: candidate.id,
                taskName: candidate.displayName,
                taskEmoji: candidate.emoji,
                kind: relationship.kind
            )
        }
        .sorted {
            if $0.kind.sortOrder != $1.kind.sortOrder {
                return $0.kind.sortOrder < $1.kind.sortOrder
            }
            return $0.taskName.localizedCaseInsensitiveCompare($1.taskName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                isPickerPresented = true
            } label: {
                Label("Add linked task", systemImage: "plus.circle")
            }
            .disabled(candidates.isEmpty)

            if candidates.isEmpty {
                Text("Create another task first to add a relationship.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if resolvedRelationships.isEmpty {
                Text("No linked tasks yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(resolvedRelationships) { relationship in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(relationship.taskEmoji)
                                Text(relationship.taskName)
                                    .foregroundStyle(.primary)
                            }

                            Label(relationship.kind.title, systemImage: relationship.kind.systemImage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        Button {
                            removeRelationship(relationship.taskID)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove relationship to \(relationship.taskName)")
                    }

                    if relationship.id != resolvedRelationships.last?.id {
                        Divider()
                    }
                }
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            TaskRelationshipPickerSheet(
                candidates: candidates,
                linkedTaskIDs: Set(relationships.map(\.targetTaskID)),
                onSelect: { taskID, kind in
                    addRelationship(taskID, kind)
                    isPickerPresented = false
                }
            )
        }
    }
}

struct TaskRelationshipPickerSheet: View {
    let candidates: [RoutineTaskRelationshipCandidate]
    let linkedTaskIDs: Set<UUID>
    let onSelect: (UUID, RoutineTaskRelationshipKind) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedKind: RoutineTaskRelationshipKind = .related

    private var availableCandidates: [RoutineTaskRelationshipCandidate] {
        candidates.filter { !linkedTaskIDs.contains($0.id) }
    }

    private var filteredCandidates: [RoutineTaskRelationshipCandidate] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return availableCandidates }
        let normalizedSearch = trimmedSearch.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        return availableCandidates.filter { candidate in
            let normalizedName = candidate.displayName.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            return normalizedName.contains(normalizedSearch)
                || candidate.emoji.contains(trimmedSearch)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Relationship Type", selection: $selectedKind) {
                        ForEach(RoutineTaskRelationshipKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Search tasks", text: $searchText)
#if !os(macOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
#endif

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
                .padding()

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Task")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if filteredCandidates.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(availableCandidates.isEmpty ? "All tasks are already linked." : "No matching tasks.")
                                .foregroundStyle(.secondary)

                            if !availableCandidates.isEmpty && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Try part of the task name.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(filteredCandidates) { candidate in
                                    Button {
                                        onSelect(candidate.id, selectedKind)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 10) {
                                            Text(candidate.emoji)
                                                .font(.title3)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(candidate.displayName)
                                                    .foregroundStyle(.primary)
                                                Text(selectedKind.title)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer(minLength: 0)
                                        }
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if candidate.id != filteredCandidates.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .navigationTitle("Link Task")
            .frame(minWidth: 520, minHeight: 420)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

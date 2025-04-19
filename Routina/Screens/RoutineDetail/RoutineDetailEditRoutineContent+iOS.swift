import ComposableArchitecture
import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif

struct RoutineDetailEditRoutineContent: View {
    let store: StoreOf<RoutineDetailFeature>
    @Binding var isEditEmojiPickerPresented: Bool
    let emojiOptions: [String]
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isImageFileImporterPresented = false
    @State private var isImageDropTargeted = false
    @State private var isTagManagerPresented = false
    @State private var tagManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }

    var body: some View {
        Form {
            Section(header: Text("Name")) {
                TextField(
                    "Task name",
                    text: Binding(
                        get: { store.editRoutineName },
                        set: { store.send(.editRoutineNameChanged($0)) }
                    )
                )
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
                    Text(store.editRoutineEmoji)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                    Spacer()
                    Button("Choose Emoji") {
                        isEditEmojiPickerPresented = true
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button {
                                store.send(.editRoutineEmojiChanged(emoji))
                            } label: {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(store.editRoutineEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(header: Text("Notes")) {
                TextField(
                    "Add notes",
                    text: Binding(
                        get: { store.editRoutineNotes },
                        set: { store.send(.editRoutineNotesChanged($0)) }
                    ),
                    axis: .vertical
                )
                .lineLimit(4...8)

                Text(editNotesHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Link")) {
                TextField(
                    "https://example.com",
                    text: Binding(
                        get: { store.editRoutineLink },
                        set: { store.send(.editRoutineLinkChanged($0)) }
                    )
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)

                Text("Add a website to open from the detail screen. If you skip the scheme, https will be used.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Tags")) {
                HStack(spacing: 10) {
                    TextField(
                        "health, focus, morning",
                        text: Binding(
                            get: { store.editTagDraft },
                            set: { store.send(.editTagDraftChanged($0)) }
                        )
                    )
                    .onSubmit {
                        store.send(.editAddTagTapped)
                    }

                    Button("Add") {
                        store.send(.editAddTagTapped)
                    }
                    .disabled(RoutineTag.parseDraft(store.editTagDraft).isEmpty)
                }

                availableTagSuggestionsContent
                manageTagsButton

                if store.editRoutineTags.isEmpty {
                    Text(store.availableTags.isEmpty ? "No tags yet" : "No selected tags yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(store.editRoutineTags, id: \.self) { tag in
                            Button {
                                store.send(.editRemoveTag(tag))
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
                        }
                    }
                    .padding(.vertical, 4)
                }

                Text(tagSectionHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Relationships")) {
                TaskRelationshipsEditor(
                    relationships: store.editRelationships,
                    candidates: store.availableRelationshipTasks,
                    addRelationship: { store.send(.editAddRelationship($0, $1)) },
                    removeRelationship: { store.send(.editRemoveRelationship($0)) }
                )

                Text("Link this task to another task as related work or a blocker.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.editScheduleMode.taskType == .routine {
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
                    HStack(spacing: 10) {
                        TextField(
                            "Wash clothes",
                            text: Binding(
                                get: { store.editStepDraft },
                                set: { store.send(.editStepDraftChanged($0)) }
                            )
                        )
                        .onSubmit {
                            store.send(.editAddStepTapped)
                        }

                        Button("Add") {
                            store.send(.editAddStepTapped)
                        }
                        .disabled(RoutineStep.normalizedTitle(store.editStepDraft) == nil)
                    }

                    if store.editRoutineSteps.isEmpty {
                        Text("No steps yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(Array(store.editRoutineSteps.enumerated()), id: \.element.id) { index, step in
                                HStack(spacing: 10) {
                                    Text("\(index + 1).")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 22, alignment: .leading)

                                    Text(step.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    HStack(spacing: 6) {
                                        Button {
                                            store.send(.editMoveStepUp(step.id))
                                        } label: {
                                            Image(systemName: "arrow.up")
                                        }
                                        .buttonStyle(.borderless)
                                        .disabled(index == 0)

                                        Button {
                                            store.send(.editMoveStepDown(step.id))
                                        } label: {
                                            Image(systemName: "arrow.down")
                                        }
                                        .buttonStyle(.borderless)
                                        .disabled(index == store.editRoutineSteps.count - 1)

                                        Button(role: .destructive) {
                                            store.send(.editRemoveStep(step.id))
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

                    Text(stepsSectionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(header: Text("Checklist Items")) {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField(
                            "Bread",
                            text: Binding(
                                get: { store.editChecklistItemDraftTitle },
                                set: { store.send(.editChecklistItemDraftTitleChanged($0)) }
                            )
                        )
                        .onSubmit {
                            store.send(.editAddChecklistItemTapped)
                        }

                        if store.editScheduleMode == .derivedFromChecklist {
                            Stepper(
                                value: Binding(
                                    get: { store.editChecklistItemDraftInterval },
                                    set: { store.send(.editChecklistItemDraftIntervalChanged($0)) }
                                ),
                                in: 1...365
                            ) {
                                Text(checklistIntervalLabel(for: store.editChecklistItemDraftInterval))
                            }
                        }

                        Button("Add Item") {
                            store.send(.editAddChecklistItemTapped)
                        }
                        .disabled(RoutineChecklistItem.normalizedTitle(store.editChecklistItemDraftTitle) == nil)
                    }

                    if store.editRoutineChecklistItems.isEmpty {
                        Text("No checklist items yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(store.editRoutineChecklistItems) { item in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        if store.editScheduleMode == .derivedFromChecklist {
                                            Text(checklistIntervalLabel(for: item.intervalDays))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Button(role: .destructive) {
                                        store.send(.editRemoveChecklistItem(item.id))
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Text(checklistSectionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("Place")) {
                Picker(
                    "Place",
                    selection: Binding(
                        get: { store.editSelectedPlaceID },
                        set: { store.send(.editSelectedPlaceChanged($0)) }
                    )
                ) {
                    Text("Anywhere").tag(Optional<UUID>.none)
                    ForEach(store.availablePlaces) { place in
                        Text(place.name).tag(Optional(place.id))
                    }
                }

                Text(editPlaceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.editScheduleMode.taskType == .todo {
                Section(header: Text("Deadline")) {
                    Toggle("Set deadline", isOn: editDeadlineEnabledBinding)
                    if store.editDeadline != nil {
                        DatePicker("Deadline", selection: editDeadlineBinding)
                    }
                }
            }

            Section(header: Text("Priority")) {
                Picker("Priority", selection: editPriorityBinding) {
                    ForEach(RoutineTaskPriority.allCases, id: \.self) { priority in
                        Text(priority.title).tag(priority)
                    }
                }

                Text(priorityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Image")) {
                editImageAttachmentContent
            }

            if showsRepeatControls {
                repeatPatternSections
            }

            Section {
                Button(role: .destructive) {
                    store.send(.setDeleteConfirmation(true))
                } label: {
                    Text("Delete Task")
                }
            } footer: {
                Text("This action cannot be undone.")
            }
        }
        .sheet(isPresented: $isTagManagerPresented) {
            SettingsTagManagerPresentationView(store: tagManagerStore)
        }
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
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            loadPickedImage(from: newItem)
        }
    }

    private var scheduleModeBinding: Binding<RoutineScheduleMode> {
        Binding(
            get: { store.editScheduleMode },
            set: { store.send(.editScheduleModeChanged($0)) }
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

    private var isStepBasedMode: Bool {
        store.editScheduleMode == .fixedInterval || store.editScheduleMode == .oneOff
    }

    private var showsRepeatControls: Bool {
        store.editScheduleMode != .derivedFromChecklist && store.editScheduleMode != .oneOff
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

    private var editPriorityBinding: Binding<RoutineTaskPriority> {
        Binding(
            get: { store.editPriority },
            set: { store.send(.editPriorityChanged($0)) }
        )
    }

    private var editNotesHelpText: String {
        store.editScheduleMode.taskType == .todo
            ? "Keep any extra context or reminders with this todo."
            : "Keep any details you want to remember for this routine."
    }

    private var priorityDescription: String {
        if store.editPriority == .none {
            return "Optional. Higher priority wins when tasks share the same due date."
        }
        return "\(store.editPriority.title) tasks are sorted above lower-priority tasks with the same due date."
    }

    private var taskTypeDescription: String {
        switch store.editScheduleMode.taskType {
        case .routine:
            return "Routines repeat on a schedule and stay in your rotation."
        case .todo:
            return "Todos are one-off tasks. Once you finish one, it stays completed."
        }
    }

    private var manageTagsButton: some View {
        Button {
            isTagManagerPresented = true
        } label: {
            Label("Manage Tags", systemImage: "slider.horizontal.3")
        }
    }

    private var tagSectionHelpText: String {
        if store.availableTags.isEmpty {
            return "Press return or Add. Separate multiple tags with commas, or open Manage Tags."
        }
        return "Tap an existing tag below, open Manage Tags, or press return/Add to create a new one. Separate multiple tags with commas."
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
                        let isSelected = RoutineTag.contains(tag, in: store.editRoutineTags)
                        Button {
                            store.send(.editToggleTagSelection(tag))
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

    private func editStepperLabel(
        frequency: RoutineDetailFeature.EditFrequency,
        frequencyValue: Int
    ) -> String {
        if frequencyValue == 1 {
            switch frequency {
            case .day: return "Everyday"
            case .week: return "Everyweek"
            case .month: return "Everymonth"
            }
        }
        return "Every \(frequencyValue) \(frequency.singularLabel)s"
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

        switch store.editRecurrenceKind {
        case .intervalDays:
            Section(header: Text("Frequency")) {
                Picker(
                    "Frequency",
                    selection: Binding(
                        get: { store.editFrequency },
                        set: { store.send(.editFrequencyChanged($0)) }
                    )
                ) {
                    ForEach(RoutineDetailFeature.EditFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Repeat")) {
                Stepper(
                    value: Binding(
                        get: { store.editFrequencyValue },
                        set: { store.send(.editFrequencyValueChanged($0)) }
                    ),
                    in: 1...365
                ) {
                    Text(
                        editStepperLabel(
                            frequency: store.editFrequency,
                            frequencyValue: store.editFrequencyValue
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

                Text("Due every day at \(store.editRecurrenceTimeOfDay.formatted()).")
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

                Text("Due every \(weekdayName(for: store.editRecurrenceWeekday)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .monthlyDay:
            Section(header: Text("Day of Month")) {
                Stepper(value: recurrenceDayOfMonthBinding, in: 1...31) {
                    Text("Every \(ordinalDay(store.editRecurrenceDayOfMonth))")
                }

                Text("Due on the \(ordinalDay(store.editRecurrenceDayOfMonth)) of each month.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recurrencePatternDescription: String {
        switch store.editRecurrenceKind {
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
        Calendar.current.weekdaySymbols.enumerated().map { index, name in
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

    private var editPlaceDescription: String {
        if let selectedPlaceID = store.editSelectedPlaceID,
           let place = store.availablePlaces.first(where: { $0.id == selectedPlaceID }) {
            return "Show this task when you are at \(place.name)."
        }
        return "Anywhere means the task is always visible."
    }

    private var stepsSectionDescription: String {
        if store.editScheduleMode == .oneOff {
            return "Steps run in order. Leave this empty for a single-step todo."
        }
        return "Steps run in order. Leave this empty for a one-step routine."
    }

    private var scheduleModeDescription: String {
        switch store.editScheduleMode {
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
        switch store.editScheduleMode {
        case .fixedIntervalChecklist:
            return "The routine is done when every checklist item is completed."
        case .derivedFromChecklist:
            return "The routine becomes due when the earliest checklist item is due."
        case .fixedInterval, .oneOff:
            return ""
        }
    }

    private func checklistIntervalLabel(for intervalDays: Int) -> String {
        if intervalDays == 1 {
            return "Runs out in 1 day"
        }
        return "Runs out in \(intervalDays) days"
    }

    @ViewBuilder
    private var editImageAttachmentContent: some View {
        let imagePickerLabel = store.editImageData == nil ? "Choose Image" : "Replace Image"

        VStack(alignment: .leading, spacing: 10) {
            if let imageData = store.editImageData {
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
                Button(store.editImageData == nil ? "Browse in Finder" : "Browse Another File") {
                    isImageFileImporterPresented = true
                }
                .buttonStyle(.bordered)
#endif

                if store.editImageData != nil {
                    Button("Remove") {
                        selectedPhotoItem = nil
                        store.send(.editRemoveImageTapped)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("Images are resized and compressed before saving to reduce storage use.")
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

    private func loadPickedImage(from item: PhotosPickerItem) {
        _ = Task {
            let data = try? await item.loadTransferable(type: Data.self)
            _ = await MainActor.run {
                store.send(.editImagePicked(data))
            }
        }
    }

    private func loadPickedImage(fromFileAt url: URL) {
        let compressedData = TaskImageProcessor.compressedImageData(fromFileAt: url)
        store.send(.editImagePicked(compressedData))
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

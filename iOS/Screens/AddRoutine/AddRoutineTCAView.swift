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
            get: { store.routineName },
            set: { store.send(.routineNameChanged($0)) }
        )
    }

    var routineEmojiBinding: Binding<String> {
        Binding(
            get: { store.routineEmoji },
            set: { store.send(.routineEmojiChanged($0)) }
        )
    }

    var routineNotesBinding: Binding<String> {
        Binding(
            get: { store.routineNotes },
            set: { store.send(.routineNotesChanged($0)) }
        )
    }

    var routineLinkBinding: Binding<String> {
        Binding(
            get: { store.routineLink },
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
            get: { store.tagDraft },
            set: { store.send(.tagDraftChanged($0)) }
        )
    }

    var stepDraftBinding: Binding<String> {
        Binding(
            get: { store.stepDraft },
            set: { store.send(.stepDraftChanged($0)) }
        )
    }

    var checklistItemDraftTitleBinding: Binding<String> {
        Binding(
            get: { store.checklistItemDraftTitle },
            set: { store.send(.checklistItemDraftTitleChanged($0)) }
        )
    }

    var checklistItemDraftIntervalBinding: Binding<Int> {
        Binding(
            get: { store.checklistItemDraftInterval },
            set: { store.send(.checklistItemDraftIntervalChanged($0)) }
        )
    }

    var scheduleModeBinding: Binding<RoutineScheduleMode> {
        Binding(
            get: { store.scheduleMode },
            set: { store.send(.scheduleModeChanged($0)) }
        )
    }

    var frequencyBinding: Binding<AddRoutineFeature.Frequency> {
        Binding(
            get: { store.frequency },
            set: { store.send(.frequencyChanged($0)) }
        )
    }

    var frequencyValueBinding: Binding<Int> {
        Binding(
            get: { store.frequencyValue },
            set: { store.send(.frequencyValueChanged($0)) }
        )
    }

    var recurrenceKindBinding: Binding<RoutineRecurrenceRule.Kind> {
        Binding(
            get: { store.recurrenceKind },
            set: { store.send(.recurrenceKindChanged($0)) }
        )
    }

    var recurrenceTimeBinding: Binding<Date> {
        Binding(
            get: { store.recurrenceTimeOfDay.date(on: Date()) },
            set: { store.send(.recurrenceTimeOfDayChanged(RoutineTimeOfDay.from($0))) }
        )
    }

    var recurrenceWeekdayBinding: Binding<Int> {
        Binding(
            get: { store.recurrenceWeekday },
            set: { store.send(.recurrenceWeekdayChanged($0)) }
        )
    }

    var recurrenceDayOfMonthBinding: Binding<Int> {
        Binding(
            get: { store.recurrenceDayOfMonth },
            set: { store.send(.recurrenceDayOfMonthChanged($0)) }
        )
    }

    var selectedPlaceBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedPlaceID },
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
            get: { store.deadline ?? Date() },
            set: { store.send(.deadlineDateChanged($0)) }
        )
    }

    var importanceBinding: Binding<RoutineTaskImportance> {
        Binding(
            get: { store.importance },
            set: { store.send(.importanceChanged($0)) }
        )
    }

    var urgencyBinding: Binding<RoutineTaskUrgency> {
        Binding(
            get: { store.urgency },
            set: { store.send(.urgencyChanged($0)) }
        )
    }

    var isSaveDisabled: Bool {
        store.isSaveDisabled
    }

    var nameValidationMessage: String? {
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

    var isStepBasedMode: Bool {
        store.scheduleMode == .fixedInterval || store.scheduleMode == .oneOff
    }

    var showsRepeatControls: Bool {
        store.scheduleMode != .derivedFromChecklist && store.scheduleMode != .oneOff
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

    var checklistSectionDescription: String {
        switch store.scheduleMode {
        case .fixedIntervalChecklist:
            return "The routine is done when every checklist item is completed."
        case .derivedFromChecklist:
            return "Each item gets its own due date. The routine becomes due when the earliest item is due."
        case .fixedInterval, .oneOff:
            return ""
        }
    }

    var placeSelectionDescription: String {
        if let selectedPlaceID = store.selectedPlaceID,
           let place = store.availablePlaces.first(where: { $0.id == selectedPlaceID }) {
            return "Show this task when you are at \(place.name)."
        }
        return "Anywhere means the task is always visible."
    }

    var importanceUrgencyDescription: String {
        "\(store.importance.title) importance and \(store.urgency.title.lowercased()) urgency map to \(store.priority.title.lowercased()) priority for sorting."
    }

    var stepsSectionDescription: String {
        if store.scheduleMode == .oneOff {
            return "Steps run in order. Leave this empty for a single-step todo."
        }
        return "Steps run in order. Leave this empty for a one-step routine."
    }

    var tagSectionHelpText: String {
        if store.availableTags.isEmpty {
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

    var manageTagsButton: some View {
        Button {
            isTagManagerPresented = true
        } label: {
            Label("Manage Tags", systemImage: "slider.horizontal.3")
        }
    }

    var stepComposer: some View {
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

    var checklistItemComposer: some View {
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
    var imageAttachmentContent: some View {
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

                platformImageImportButton

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
    var editableTagsContent: some View {
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
    var editableStepsContent: some View {
        if store.routineSteps.isEmpty {
            Label("No steps yet", systemImage: "list.bullet")
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
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    var editableChecklistItemsContent: some View {
        if store.routineChecklistItems.isEmpty {
            Label("No checklist items yet", systemImage: "checklist")
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
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
            }
            .padding(.vertical, 4)
        }
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

    var recurrencePatternDescription: String {
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
                kind: relationship.kind,
                status: candidate.status
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

                            Picker("", selection: Binding(
                                get: { relationship.kind },
                                set: { addRelationship(relationship.taskID, $0) }
                            )) {
                                ForEach(RoutineTaskRelationshipKind.allCases, id: \.self) { kind in
                                    Label(kind.title, systemImage: kind.systemImage).tag(kind)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.caption)
                            .labelsHidden()
                            .padding(.leading, -8)
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
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
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
                            .routinaTaskRelationshipSearchFieldPlatform()

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

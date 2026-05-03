import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct TaskFormContent: View {
    let model: TaskFormModel
    @Dependency(\.appSettingsClient) private var appSettingsClient
    @FocusState private var isNameFocused: Bool
    @State private var isTagManagerPresented = false
    @State private var tagManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    @State private var isPlaceManagerPresented = false
    @State private var placeManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isFileImporterPresented = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) private var showPersianDates = false

    var body: some View {
        Form {
            nameSection
            taskTypeSection
            emojiSection
            colorSection
            notesSection
            linkSection
            if model.taskType.wrappedValue == .todo {
                deadlineSection
            }
            reminderSection
            importanceUrgencySection
            pressureSection
            estimationSection
            imageSection
            attachmentSection
            tagsSection
            goalsSection
            relationshipsSection
            if model.scheduleMode.wrappedValue.taskType == .routine {
                scheduleTypeSection
            }
            if presentation.isStepBasedMode {
                stepsSection
            } else {
                checklistSection
            }
            placeSection
            if presentation.showsRepeatControls {
                repeatPatternSections
            }
            if let onDelete = model.onDelete {
                Section {
                    Button(role: .destructive) { onDelete() } label: {
                        Text("Delete Task")
                    }
                } footer: {
                    Text("This action cannot be undone.")
                }
            }
        }
        .sheet(isPresented: $isTagManagerPresented) {
            SettingsTagManagerPresentationView(store: tagManagerStore)
        }
        .sheet(isPresented: $isPlaceManagerPresented) {
            SettingsPlaceManagerPresentationView(store: placeManagerStore)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            loadPickedImage(from: newItem)
        }
        .onAppear {
            guard model.autofocusName else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isNameFocused = true
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleAttachmentImport(result)
        }
    }

    // MARK: - Helpers

    private var presentation: TaskFormPresentation {
        TaskFormPresentation(
            taskType: model.taskType.wrappedValue,
            scheduleMode: model.scheduleMode.wrappedValue,
            recurrenceKind: model.recurrenceKind.wrappedValue,
            recurrenceHasExplicitTime: model.recurrenceHasExplicitTime.wrappedValue,
            recurrenceWeekday: model.recurrenceWeekday.wrappedValue,
            recurrenceDayOfMonth: model.recurrenceDayOfMonth.wrappedValue,
            importance: model.importance.wrappedValue,
            urgency: model.urgency.wrappedValue,
            hasAvailableTags: !model.availableTags.isEmpty,
            hasAvailableGoals: !model.availableGoals.isEmpty,
            goalDraft: model.goalDraft.wrappedValue,
            selectedPlaceName: selectedPlaceName,
            canAutoAssumeDailyDone: model.canAutoAssumeDailyDone
        )
    }

    private var selectedPlaceName: String? {
        if let id = model.selectedPlaceID.wrappedValue,
           let place = model.availablePlaces.first(where: { $0.id == id }) {
            return place.name
        }
        return nil
    }

    private var estimatedDurationEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.estimatedDurationMinutes.wrappedValue != nil },
            set: { isEnabled in
                model.estimatedDurationMinutes.wrappedValue = isEnabled
                    ? (model.estimatedDurationMinutes.wrappedValue ?? 30)
                    : nil
            }
        )
    }

    private var estimatedDurationStepperBinding: Binding<Int> {
        Binding(
            get: { max(model.estimatedDurationMinutes.wrappedValue ?? 30, 5) },
            set: { model.estimatedDurationMinutes.wrappedValue = RoutineTask.sanitizedEstimatedDurationMinutes(max($0, 5)) }
        )
    }

    private var actualDurationEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.actualDurationMinutes?.wrappedValue != nil },
            set: { isEnabled in
                guard let actualDurationMinutes = model.actualDurationMinutes else { return }
                actualDurationMinutes.wrappedValue = isEnabled
                    ? (actualDurationMinutes.wrappedValue ?? model.estimatedDurationMinutes.wrappedValue ?? 30)
                    : nil
            }
        )
    }

    private var actualDurationStepperBinding: Binding<Int> {
        Binding(
            get: { max(model.actualDurationMinutes?.wrappedValue ?? model.estimatedDurationMinutes.wrappedValue ?? 30, 1) },
            set: { model.actualDurationMinutes?.wrappedValue = RoutineTask.sanitizedActualDurationMinutes(max($0, 1)) }
        )
    }

    private var storyPointsEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.storyPoints.wrappedValue != nil },
            set: { isEnabled in
                model.storyPoints.wrappedValue = isEnabled
                    ? (model.storyPoints.wrappedValue ?? 1)
                    : nil
            }
        )
    }

    private var storyPointsStepperBinding: Binding<Int> {
        Binding(
            get: { max(model.storyPoints.wrappedValue ?? 1, 1) },
            set: { model.storyPoints.wrappedValue = RoutineTask.sanitizedStoryPoints(max($0, 1)) }
        )
    }

    private func loadPickedImage(from item: PhotosPickerItem) {
        _ = Task {
            let data = try? await item.loadTransferable(type: Data.self)
            _ = await MainActor.run {
                model.onImagePicked(data)
            }
        }
    }

    private func handleAttachmentImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        let maxSize = 20 * 1024 * 1024  // 20 MB
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url), data.count <= maxSize else { return }
        model.onAttachmentPicked(data, url.lastPathComponent)
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section(header: Text("Name")) {
            TextField("Task name", text: model.name)
                .focused($isNameFocused)
            if let msg = model.nameValidationMessage {
                Text(msg).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var taskTypeSection: some View {
        Section(header: Text("Task Type")) {
            Picker("Task Type", selection: model.taskType) {
                Text("Routine").tag(RoutineTaskType.routine)
                Text("Todo").tag(RoutineTaskType.todo)
            }
            .pickerStyle(.segmented)
            Text(presentation.taskTypeDescription).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var emojiSection: some View {
        Section(header: Text("Emoji")) {
            HStack(spacing: 12) {
                Text("Selected").foregroundColor(.secondary)
                Text(model.emoji.wrappedValue).font(.title2).frame(width: 44, height: 44)
                Spacer()
                Button("Choose Emoji") { model.isEmojiPickerPresented.wrappedValue = true }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(model.emojiOptions, id: \.self) { emoji in
                        Button {
                            model.emoji.wrappedValue = emoji
                        } label: {
                            Text(emoji)
                                .font(.title2)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle().fill(
                                        model.emoji.wrappedValue == emoji
                                            ? Color.blue.opacity(0.2)
                                            : Color.clear
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var colorSection: some View {
        Section(header: Text("Color")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(RoutineTaskColor.allCases, id: \.self) { color in
                        Button {
                            model.color.wrappedValue = color
                        } label: {
                            ZStack {
                                if let c = color.swiftUIColor {
                                    Circle()
                                        .fill(c)
                                        .frame(width: 30, height: 30)
                                } else {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.12))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: "circle.slash")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.secondary)
                                }
                                if model.color.wrappedValue == color {
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: 2.5)
                                        .frame(width: 36, height: 36)
                                }
                            }
                            .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(color.displayName)
                    }

                    // Custom colour picker
                    ZStack {
                        ColorPicker(
                            "",
                            selection: customColorPickerBinding,
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())

                        if case .custom = model.color.wrappedValue {
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: 2.5)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .accessibilityLabel("Custom color")
                }
                .padding(.vertical, 6)
            }
            Text("Sets a tint on the task row and detail screen background.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var customColorPickerBinding: Binding<Color> {
        Binding(
            get: {
                if case .custom(let hex) = model.color.wrappedValue {
                    return Color(hex: hex)
                }
                return .white
            },
            set: { color in
                if let hex = color.hexString {
                    model.color.wrappedValue = .custom(hex: hex)
                }
            }
        )
    }

    private var notesSection: some View {
        Section(header: Text("Notes")) {
            TextField("Add notes", text: model.notes, axis: .vertical)
                .lineLimit(4...8)
            Text(presentation.notesHelpText).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var linkSection: some View {
        Section(header: Text("Link")) {
            TextField("https://example.com", text: model.link)
                .routinaAddRoutinePlatformLinkField()
            Text("Add a website to open from the detail screen. If you skip the scheme, https will be used.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var deadlineSection: some View {
        Section(header: Text("Deadline")) {
            Toggle("Set deadline", isOn: model.deadlineEnabled)
            if model.deadlineEnabled.wrappedValue {
                DatePicker("Deadline", selection: model.deadline)
                if let persianDeadlineText {
                    Text(persianDeadlineText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var persianDeadlineText: String? {
        PersianDateDisplay.supplementaryText(
            for: model.deadline.wrappedValue,
            enabled: showPersianDates
        )
    }

    private var reminderSection: some View {
        Section(header: Text("Reminder")) {
            Toggle("Set reminder", isOn: model.reminderEnabled)
            if model.reminderEnabled.wrappedValue {
                DatePicker("Reminder", selection: model.reminderAt)
            }
            Text("Send one notification at an exact date and time.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var importanceUrgencySection: some View {
        Section(header: Text("Importance & Urgency")) {
            ImportanceUrgencyMatrixPicker(importance: model.importance, urgency: model.urgency)
            Text(presentation.importanceUrgencyDescription(includesDerivedPriority: true))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var pressureSection: some View {
        Section(header: Text("Pressure")) {
            Picker("Pressure", selection: model.pressure) {
                ForEach(RoutineTaskPressure.allCases, id: \.self) { pressure in
                    Text(pressure.title).tag(pressure)
                }
            }
            .pickerStyle(.segmented)
            Text("Use this for tasks that keep occupying your mind, even when they are not the most urgent.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var estimationSection: some View {
        Section(header: Text("Estimation")) {
            Toggle("Set duration estimate", isOn: estimatedDurationEnabledBinding)
            if estimatedDurationEnabledBinding.wrappedValue {
                Stepper(value: estimatedDurationStepperBinding, in: 5...10_080, step: 5) {
                    Text(TaskFormPresentation.estimatedDurationLabel(for: estimatedDurationStepperBinding.wrappedValue))
                }
            }

            if model.taskType.wrappedValue == .todo, model.actualDurationMinutes != nil {
                Toggle("Set actual time spent", isOn: actualDurationEnabledBinding)
                if actualDurationEnabledBinding.wrappedValue {
                    Stepper(value: actualDurationStepperBinding, in: 1...1_440, step: 5) {
                        Text(TaskFormPresentation.estimatedDurationLabel(for: actualDurationStepperBinding.wrappedValue))
                    }
                }
            }

            Toggle("Set story points", isOn: storyPointsEnabledBinding)
            if storyPointsEnabledBinding.wrappedValue {
                Stepper(value: storyPointsStepperBinding, in: 1...100) {
                    Text(TaskFormPresentation.storyPointsLabel(for: storyPointsStepperBinding.wrappedValue))
                }
            }

            Toggle("Show focus timer", isOn: model.focusModeEnabled)

            Text(presentation.estimationHelpText).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var imageSection: some View {
        Section(header: Text("Image")) {
            imageAttachmentContent
        }
    }

    private var attachmentSection: some View {
        Section(header: Text("File Attachment")) {
            attachmentContent
        }
    }

    @ViewBuilder
    private var attachmentContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.attachments.isEmpty {
                Label("No files attached", systemImage: "doc")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(model.attachments) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.secondary)
                        Text(item.fileName)
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            model.onRemoveAttachment(item.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            Button {
                isFileImporterPresented = true
            } label: {
                Label("Add File", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.bordered)
            Text("Attach any file up to 20 MB (PDF, document, spreadsheet, etc.).")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4).padding(.horizontal, 2)
    }

    private var tagsSection: some View {
        Section(header: Text("Tags")) {
            HStack(spacing: 10) {
                ZStack(alignment: .trailing) {
                    TextField("health, focus, morning", text: model.tagDraft)
                        .onSubmit { model.onAddTag() }
                        .padding(.trailing, model.tagAutocompleteSuggestion == nil ? 0 : 88)

                    if let suggestion = model.tagAutocompleteSuggestion {
                        Button {
                            model.acceptTagAutocompleteSuggestion()
                        } label: {
                            let tint = tagColor(for: suggestion) ?? .secondary
                            Text("#\(suggestion)")
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(tint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tint.opacity(0.12), in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(tint.opacity(0.28), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.tab, modifiers: [])
                    }
                }

                Button("Add") { model.onAddTag() }
                    .disabled(RoutineTag.parseDraft(model.tagDraft.wrappedValue).isEmpty)
            }
            relatedTagSuggestionsContent
            availableTagSuggestionsContent
            manageTagsButton
            if model.routineTags.isEmpty {
                Text(model.availableTags.isEmpty ? "No tags yet" : "No selected tags yet")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(model.routineTags, id: \.self) { tag in
                        let tint = tagColor(for: tag) ?? .accentColor
                        Button { model.onRemoveTag(tag) } label: {
                            HStack(spacing: 6) {
                                Text("#\(tag)").lineLimit(1)
                                Image(systemName: "xmark.circle.fill").font(.caption)
                            }
                            .foregroundStyle(tint)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(tint.opacity(0.14), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(tint.opacity(0.28), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            Text(presentation.tagSectionHelpText).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var goalsSection: some View {
        Section(header: Text("Goals")) {
            HStack(spacing: 10) {
                TextField("Ship portfolio, improve health", text: model.goalDraft)
                    .onSubmit { model.onAddGoal() }
                Button("Add") { model.onAddGoal() }
                    .disabled(!presentation.canAddGoalDraft)
            }
            availableGoalSuggestionsContent
            if model.selectedGoals.isEmpty {
                Text(model.availableGoals.isEmpty ? "No goals yet" : "No selected goals yet")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(model.selectedGoals) { goal in
                        Button { model.onRemoveGoal(goal.id) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "target").font(.caption)
                                Text(goal.displayTitle).lineLimit(1)
                                Image(systemName: "xmark.circle.fill").font(.caption)
                            }
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.14), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.28), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            Text(presentation.goalSectionHelpText).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var relationshipsSection: some View {
        Section(header: Text("Relationships")) {
            TaskRelationshipsEditor(
                relationships: model.relationships,
                candidates: model.availableRelationshipTasks,
                addRelationship: model.onAddRelationship,
                removeRelationship: model.onRemoveRelationship
            )
            Text("Link this task to another task as related work or a blocker.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var scheduleTypeSection: some View {
        Section(header: Text("Schedule Type")) {
            Picker("Schedule Type", selection: model.scheduleMode) {
                Text("Fixed").tag(RoutineScheduleMode.fixedInterval)
                Text("Soft").tag(RoutineScheduleMode.softInterval)
                Text("Checklist").tag(RoutineScheduleMode.fixedIntervalChecklist)
                Text("Runout").tag(RoutineScheduleMode.derivedFromChecklist)
            }
            .pickerStyle(.segmented)
            Text(presentation.scheduleModeDescription).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var stepsSection: some View {
        Section(header: Text("Steps")) {
            HStack(spacing: 10) {
                TextField("Wash clothes", text: model.stepDraft)
                    .onSubmit { model.onAddStep() }
                Button("Add") { model.onAddStep() }
                    .disabled(RoutineStep.normalizedTitle(model.stepDraft.wrappedValue) == nil)
            }
            if model.routineSteps.isEmpty {
                Label("No steps yet", systemImage: "list.bullet")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(model.routineSteps.enumerated()), id: \.element.id) { index, step in
                        HStack(spacing: 10) {
                            Text("\(index + 1).")
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                .frame(width: 22, alignment: .leading)
                            Text(step.title).frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 6) {
                                Button { model.onMoveStepUp(step.id) } label: {
                                    Image(systemName: "arrow.up")
                                }
                                .buttonStyle(.borderless).disabled(index == 0)
                                Button { model.onMoveStepDown(step.id) } label: {
                                    Image(systemName: "arrow.down")
                                }
                                .buttonStyle(.borderless).disabled(index == model.routineSteps.count - 1)
                                Button(role: .destructive) { model.onRemoveStep(step.id) } label: {
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
            Text(presentation.stepsSectionDescription).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var checklistSection: some View {
        Section(header: Text("Checklist Items")) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Bread", text: model.checklistItemDraftTitle)
                    .onSubmit { model.onAddChecklistItem() }
                if model.scheduleMode.wrappedValue == .derivedFromChecklist {
                    Stepper(value: model.checklistItemDraftInterval, in: 1...365) {
                        Text(TaskFormPresentation.checklistIntervalLabel(for: model.checklistItemDraftInterval.wrappedValue))
                    }
                }
                Button("Add Item") { model.onAddChecklistItem() }
                    .disabled(RoutineChecklistItem.normalizedTitle(model.checklistItemDraftTitle.wrappedValue) == nil)
            }
            if model.routineChecklistItems.isEmpty {
                Label("No checklist items yet", systemImage: "checklist")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(model.routineChecklistItems) { item in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).frame(maxWidth: .infinity, alignment: .leading)
                                if model.scheduleMode.wrappedValue == .derivedFromChecklist {
                                    Text(TaskFormPresentation.checklistIntervalLabel(for: item.intervalDays))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Button(role: .destructive) { model.onRemoveChecklistItem(item.id) } label: {
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
            Text(presentation.checklistSectionDescription(includesDerivedChecklistDueDetail: false))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var placeSection: some View {
        Section(header: Text("Place")) {
            Picker("Place", selection: model.selectedPlaceID) {
                Text("Anywhere").tag(Optional<UUID>.none)
                ForEach(model.availablePlaces) { place in
                    Text(place.name).tag(Optional(place.id))
                }
            }
            managePlacesButton
            Text(presentation.placeSelectionDescription).font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var repeatPatternSections: some View {
        if model.scheduleMode.wrappedValue == .softInterval {
            Section(header: Text("Soft Reminder")) {
                Picker("Frequency", selection: model.frequencyUnit) {
                    ForEach(TaskFormFrequencyUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(value: model.frequencyValue, in: 1...365) {
                    Text("Highlight again after \(TaskFormPresentation.stepperLabel(unit: model.frequencyUnit.wrappedValue, value: model.frequencyValue.wrappedValue).lowercased())")
                }

                Text("This routine stays visible and never becomes overdue. The app will just give it a softer nudge after this much time has passed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Section(header: Text("Repeat Pattern")) {
                Picker("Repeat Pattern", selection: model.recurrenceKind) {
                    ForEach(RoutineRecurrenceRule.Kind.allCases, id: \.self) { kind in
                        Text(kind.pickerTitle).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                Text(presentation.recurrencePatternDescription).font(.caption).foregroundStyle(.secondary)
            }

            switch model.recurrenceKind.wrappedValue {
            case .intervalDays:
                Section(header: Text("Frequency")) {
                    Picker("Frequency", selection: model.frequencyUnit) {
                        ForEach(TaskFormFrequencyUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text("Repeat")) {
                    Stepper(value: model.frequencyValue, in: 1...365) {
                        Text(TaskFormPresentation.stepperLabel(unit: model.frequencyUnit.wrappedValue, value: model.frequencyValue.wrappedValue))
                    }
                }

            case .dailyTime:
                Section(header: Text("Time of Day")) {
                    DatePicker("Time", selection: model.recurrenceTimeOfDay, displayedComponents: .hourAndMinute)
                    Text("Due every day at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened)).")
                        .font(.caption).foregroundStyle(.secondary)
                }

            case .weekly:
                Section(header: Text("Weekday")) {
                    Picker("Weekday", selection: model.recurrenceWeekday) {
                        ForEach(presentation.weekdayOptions, id: \.id) { option in
                            Text(option.name).tag(option.id)
                        }
                    }
                    Text(presentation.weeklyRecurrenceSummary)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section(header: Text("Time of Day")) {
                    Toggle("Set exact time", isOn: model.recurrenceHasExplicitTime)
                    if model.recurrenceHasExplicitTime.wrappedValue {
                        DatePicker("Time", selection: model.recurrenceTimeOfDay, displayedComponents: .hourAndMinute)
                    }
                    Text(presentation.weeklyRecurrenceTimeHelpText())
                        .font(.caption).foregroundStyle(.secondary)
                }

            case .monthlyDay:
                Section(header: Text("Day of Month")) {
                    Stepper(value: model.recurrenceDayOfMonth, in: 1...31) {
                        Text("Every \(TaskFormPresentation.ordinalDay(model.recurrenceDayOfMonth.wrappedValue))")
                    }
                    Text(presentation.monthlyRecurrenceSummary)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section(header: Text("Time of Day")) {
                    Toggle("Set exact time", isOn: model.recurrenceHasExplicitTime)
                    if model.recurrenceHasExplicitTime.wrappedValue {
                        DatePicker("Time", selection: model.recurrenceTimeOfDay, displayedComponents: .hourAndMinute)
                    }
                    Text(presentation.monthlyRecurrenceTimeHelpText())
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }

        if model.taskType.wrappedValue == .routine {
            Section(header: Text("Assumed Done")) {
                Toggle("Assume done automatically", isOn: model.autoAssumeDailyDone)
                    .disabled(!model.canAutoAssumeDailyDone)
                Text(presentation.autoAssumeDailyDoneHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var manageTagsButton: some View {
        Button {
            isTagManagerPresented = true
        } label: {
            Label("Manage Tags", systemImage: "slider.horizontal.3")
        }
    }

    private var managePlacesButton: some View {
        Button {
            isPlaceManagerPresented = true
        } label: {
            Label("Manage Places", systemImage: "map")
        }
    }

    @ViewBuilder
    private var relatedTagSuggestionsContent: some View {
        let suggestions = model.suggestedRelatedTags
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested related tags")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(suggestions, id: \.self) { tag in
                        let tint = tagColor(for: tag) ?? .orange
                        Button { model.onToggleTagSelection(tag) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                Text("#\(tag)").lineLimit(1)
                            }
                            .foregroundStyle(tint)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(tint.opacity(0.10), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(tint.opacity(0.45), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add suggested related tag \(tag)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var availableTagSuggestionsContent: some View {
        if !model.availableTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose from existing tags")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(model.availableTags, id: \.self) { tag in
                        let isSelected = RoutineTag.contains(tag, in: model.routineTags)
                        let summary = model.availableTagSummaries.first(where: {
                            RoutineTag.normalized($0.name) == RoutineTag.normalized(tag)
                        })
                        let tint = tagColor(for: tag) ?? .accentColor
                        Button { model.onToggleTagSelection(tag) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.caption)
                                Text(tagChipTitle(tag: tag, summary: summary)).lineLimit(1)
                            }
                            .foregroundStyle(isSelected ? tint : (tagColor(for: tag) ?? .secondary))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(
                                Capsule().fill(
                                    isSelected
                                        ? tint.opacity(0.16)
                                        : (tagColor(for: tag) ?? .secondary).opacity(0.10)
                                )
                            )
                            .overlay {
                                Capsule()
                                    .stroke((tagColor(for: tag) ?? .secondary).opacity(0.24), lineWidth: 1)
                            }
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
    private var availableGoalSuggestionsContent: some View {
        if !model.availableGoals.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose from existing goals")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(model.availableGoals) { goal in
                        let isSelected = model.selectedGoals.contains(where: { $0.id == goal.id })
                        Button { model.onToggleGoalSelection(goal) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.caption)
                                Text(goal.displayTitle).lineLimit(1)
                            }
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(
                                Capsule().fill(
                                    isSelected
                                        ? Color.accentColor.opacity(0.16)
                                        : Color.secondary.opacity(0.10)
                                )
                            )
                            .overlay {
                                Capsule()
                                    .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(isSelected ? "Remove" : "Add") goal \(goal.displayTitle)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func tagChipTitle(tag: String, summary: RoutineTagSummary?) -> String {
        TagCounterFormatting.chipTitle(
            tag: tag,
            summary: summary,
            mode: model.tagCounterDisplayMode
        )
    }

    private func tagColor(for tag: String) -> Color? {
        model.availableTagSummaries.first {
            RoutineTag.normalized($0.name) == RoutineTag.normalized(tag)
        }?.displayColor
        ?? Color(routineTagHex: RoutineTagColors.colorHex(for: tag, in: appSettingsClient.tagColors()))
    }

    @ViewBuilder
    private var imageAttachmentContent: some View {
        let imagePickerLabel = model.imageData == nil ? "Choose Image" : "Replace Image"
        VStack(alignment: .leading, spacing: 10) {
            if let imageData = model.imageData {
                TaskImageView(data: imageData)
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    )
            } else {
                Label("No image selected", systemImage: "photo")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(imagePickerLabel, systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                if model.imageData != nil {
                    Button("Remove") {
                        selectedPhotoItem = nil
                        model.onRemoveImage()
                    }
                    .buttonStyle(.bordered)
                }
            }
            Text("Images are resized and compressed before saving to reduce storage use.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4).padding(.horizontal, 2)
    }
}

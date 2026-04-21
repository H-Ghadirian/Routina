import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct TaskFormContent: View {
    let model: TaskFormModel
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
            importanceUrgencySection
            estimationSection
            imageSection
            attachmentSection
            tagsSection
            relationshipsSection
            if model.scheduleMode.wrappedValue.taskType == .routine {
                scheduleTypeSection
            }
            if isStepBasedMode {
                stepsSection
            } else {
                checklistSection
            }
            placeSection
            if showsRepeatControls {
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

    private var isStepBasedMode: Bool {
        let mode = model.scheduleMode.wrappedValue
        return mode == .fixedInterval || mode == .oneOff
    }

    private var showsRepeatControls: Bool {
        let mode = model.scheduleMode.wrappedValue
        return mode != .derivedFromChecklist && mode != .oneOff
    }

    private var derivedPriority: RoutineTaskPriority {
        let score = model.importance.wrappedValue.sortOrder + model.urgency.wrappedValue.sortOrder
        switch score {
        case ..<4: return .low
        case 4...5: return .medium
        case 6...7: return .high
        default: return .urgent
        }
    }

    private var taskTypeDescription: String {
        switch model.taskType.wrappedValue {
        case .routine: return "Routines repeat on a schedule and stay in your rotation."
        case .todo: return "Todos are one-off tasks. Once you finish one, it stays completed."
        }
    }

    private var notesHelpText: String {
        model.taskType.wrappedValue == .todo
            ? "Capture extra context, links, or reminders for this todo."
            : "Add any details you want to keep with this routine."
    }

    private var importanceUrgencyDescription: String {
        "\(model.importance.wrappedValue.title) importance and \(model.urgency.wrappedValue.title.lowercased()) urgency map to \(derivedPriority.title.lowercased()) priority for sorting."
    }

    private var estimationHelpText: String {
        "Use either field when it helps. Leave both off when you do not want to estimate."
    }

    private var tagSectionHelpText: String {
        if model.availableTags.isEmpty {
            return "Press return or Add. Separate multiple tags with commas, or open Manage Tags."
        }
        return "Tap an existing tag below, open Manage Tags, or press return/Add to create a new one. Separate multiple tags with commas."
    }

    private var scheduleModeDescription: String {
        switch model.scheduleMode.wrappedValue {
        case .fixedInterval: return "Use one overall repeat interval for the whole routine."
        case .fixedIntervalChecklist: return "Use one overall repeat interval and complete every checklist item to finish the routine."
        case .derivedFromChecklist: return "Use checklist item due dates to decide when the routine is due."
        case .oneOff: return "This task does not repeat."
        }
    }

    private var stepsSectionDescription: String {
        model.scheduleMode.wrappedValue == .oneOff
            ? "Steps run in order. Leave this empty for a single-step todo."
            : "Steps run in order. Leave this empty for a one-step routine."
    }

    private var checklistSectionDescription: String {
        switch model.scheduleMode.wrappedValue {
        case .fixedIntervalChecklist: return "The routine is done when every checklist item is completed."
        case .derivedFromChecklist: return "The routine becomes due when the earliest checklist item is due."
        case .fixedInterval, .oneOff: return ""
        }
    }

    private var placeSelectionDescription: String {
        if let id = model.selectedPlaceID.wrappedValue,
           let place = model.availablePlaces.first(where: { $0.id == id }) {
            return "Show this task when you are at \(place.name)."
        }
        return "Anywhere means the task is always visible."
    }

    private var recurrencePatternDescription: String {
        switch model.recurrenceKind.wrappedValue {
        case .intervalDays: return "Repeat after a fixed number of days, weeks, or months."
        case .dailyTime: return "Repeat every day at a specific time."
        case .weekly: return "Repeat on the same weekday each week, with an optional exact time."
        case .monthlyDay: return "Repeat on the same calendar day each month, with an optional exact time."
        }
    }

    private var autoAssumeDailyDoneHelpText: String {
        if model.canAutoAssumeDailyDone {
            return "Show this simple daily routine as assumed done by default. You can still confirm it or mark it not done later."
        }
        return "Available only for simple daily routines without steps or checklist items."
    }

    private var weekdayOptions: [(id: Int, name: String)] {
        Calendar.current.weekdaySymbols.enumerated().map { (id: $0.offset + 1, name: $0.element) }
    }

    private func weekdayName(for weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        return symbols[min(max(weekday - 1, 0), symbols.count - 1)]
    }

    private func ordinalDay(_ day: Int) -> String {
        let d = min(max(day, 1), 31)
        let suffix: String
        switch d % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch d % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(d)\(suffix)"
    }

    private func stepperLabel(unit: TaskFormFrequencyUnit, value: Int) -> String {
        if value == 1 {
            switch unit {
            case .day: return "Every day"
            case .week: return "Every week"
            case .month: return "Every month"
            }
        }
        return "Every \(value) \(unit.singularLabel)s"
    }

    private func checklistIntervalLabel(for days: Int) -> String {
        days == 1 ? "Runs out in 1 day" : "Runs out in \(days) days"
    }

    private func estimatedDurationLabel(for minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        switch (hours, remainingMinutes) {
        case (0, let remainingMinutes):
            return remainingMinutes == 1 ? "1 minute" : "\(remainingMinutes) minutes"
        case (let hours, 0):
            return hours == 1 ? "1 hour" : "\(hours) hours"
        default:
            let hourText = hours == 1 ? "1 hour" : "\(hours) hours"
            let minuteText = remainingMinutes == 1 ? "1 minute" : "\(remainingMinutes) minutes"
            return "\(hourText) \(minuteText)"
        }
    }

    private func storyPointsLabel(for points: Int) -> String {
        points == 1 ? "1 story point" : "\(points) story points"
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

    private var weeklyRecurrenceSummary: String {
        "Due every \(weekdayName(for: model.recurrenceWeekday.wrappedValue))."
    }

    private var weeklyRecurrenceTimeHelpText: String {
        if model.recurrenceHasExplicitTime.wrappedValue {
            return weeklyRecurrenceSummary
        }
        return "Optional. Leave this off to keep the routine due any time on \(weekdayName(for: model.recurrenceWeekday.wrappedValue))."
    }

    private var monthlyRecurrenceSummary: String {
        "Due on the \(ordinalDay(model.recurrenceDayOfMonth.wrappedValue)) of each month."
    }

    private var monthlyRecurrenceTimeHelpText: String {
        if model.recurrenceHasExplicitTime.wrappedValue {
            return monthlyRecurrenceSummary
        }
        return "Optional. Leave this off to keep the routine due any time on the \(ordinalDay(model.recurrenceDayOfMonth.wrappedValue)) of each month."
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
            Text(taskTypeDescription).font(.caption).foregroundStyle(.secondary)
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
            Text(notesHelpText).font(.caption).foregroundStyle(.secondary)
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
            }
        }
    }

    private var importanceUrgencySection: some View {
        Section(header: Text("Importance & Urgency")) {
            ImportanceUrgencyMatrixPicker(importance: model.importance, urgency: model.urgency)
            Text(importanceUrgencyDescription).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var estimationSection: some View {
        Section(header: Text("Estimation")) {
            Toggle("Set duration estimate", isOn: estimatedDurationEnabledBinding)
            if estimatedDurationEnabledBinding.wrappedValue {
                Stepper(value: estimatedDurationStepperBinding, in: 5...10_080, step: 5) {
                    Text(estimatedDurationLabel(for: estimatedDurationStepperBinding.wrappedValue))
                }
            }

            Toggle("Set story points", isOn: storyPointsEnabledBinding)
            if storyPointsEnabledBinding.wrappedValue {
                Stepper(value: storyPointsStepperBinding, in: 1...100) {
                    Text(storyPointsLabel(for: storyPointsStepperBinding.wrappedValue))
                }
            }

            Text(estimationHelpText).font(.caption).foregroundStyle(.secondary)
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
                TextField("health, focus, morning", text: model.tagDraft)
                    .onSubmit { model.onAddTag() }
                Button("Add") { model.onAddTag() }
                    .disabled(RoutineTag.parseDraft(model.tagDraft.wrappedValue).isEmpty)
            }
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
                        Button { model.onRemoveTag(tag) } label: {
                            HStack(spacing: 6) {
                                Text("#\(tag)").lineLimit(1)
                                Image(systemName: "xmark.circle.fill").font(.caption)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            Text(tagSectionHelpText).font(.caption).foregroundStyle(.secondary)
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
                Text("Checklist").tag(RoutineScheduleMode.fixedIntervalChecklist)
                Text("Runout").tag(RoutineScheduleMode.derivedFromChecklist)
            }
            .pickerStyle(.segmented)
            Text(scheduleModeDescription).font(.caption).foregroundStyle(.secondary)
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
            Text(stepsSectionDescription).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var checklistSection: some View {
        Section(header: Text("Checklist Items")) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Bread", text: model.checklistItemDraftTitle)
                    .onSubmit { model.onAddChecklistItem() }
                if model.scheduleMode.wrappedValue == .derivedFromChecklist {
                    Stepper(value: model.checklistItemDraftInterval, in: 1...365) {
                        Text(checklistIntervalLabel(for: model.checklistItemDraftInterval.wrappedValue))
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
                                    Text(checklistIntervalLabel(for: item.intervalDays))
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
            Text(checklistSectionDescription).font(.caption).foregroundStyle(.secondary)
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
            Text(placeSelectionDescription).font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var repeatPatternSections: some View {
        Section(header: Text("Repeat Pattern")) {
            Picker("Repeat Pattern", selection: model.recurrenceKind) {
                ForEach(RoutineRecurrenceRule.Kind.allCases, id: \.self) { kind in
                    Text(kind.pickerTitle).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            Text(recurrencePatternDescription).font(.caption).foregroundStyle(.secondary)
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
                    Text(stepperLabel(unit: model.frequencyUnit.wrappedValue, value: model.frequencyValue.wrappedValue))
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
                    ForEach(weekdayOptions, id: \.id) { option in
                        Text(option.name).tag(option.id)
                    }
                }
                Text(weeklyRecurrenceSummary)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(header: Text("Time of Day")) {
                Toggle("Set exact time", isOn: model.recurrenceHasExplicitTime)
                if model.recurrenceHasExplicitTime.wrappedValue {
                    DatePicker("Time", selection: model.recurrenceTimeOfDay, displayedComponents: .hourAndMinute)
                }
                Text(weeklyRecurrenceTimeHelpText)
                    .font(.caption).foregroundStyle(.secondary)
            }

        case .monthlyDay:
            Section(header: Text("Day of Month")) {
                Stepper(value: model.recurrenceDayOfMonth, in: 1...31) {
                    Text("Every \(ordinalDay(model.recurrenceDayOfMonth.wrappedValue))")
                }
                Text(monthlyRecurrenceSummary)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(header: Text("Time of Day")) {
                Toggle("Set exact time", isOn: model.recurrenceHasExplicitTime)
                if model.recurrenceHasExplicitTime.wrappedValue {
                    DatePicker("Time", selection: model.recurrenceTimeOfDay, displayedComponents: .hourAndMinute)
                }
                Text(monthlyRecurrenceTimeHelpText)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }

        if model.taskType.wrappedValue == .routine {
            Section(header: Text("Assumed Done")) {
                Toggle("Assume done automatically", isOn: model.autoAssumeDailyDone)
                    .disabled(!model.canAutoAssumeDailyDone)
                Text(autoAssumeDailyDoneHelpText)
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
                        Button { model.onToggleTagSelection(tag) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.caption)
                                Text(tagChipTitle(tag: tag, summary: summary)).lineLimit(1)
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
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(isSelected ? "Remove" : "Add") tag \(tag)")
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

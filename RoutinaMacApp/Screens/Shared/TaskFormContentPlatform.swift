import ComposableArchitecture
import AppKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct TaskFormContent: View {
    let model: TaskFormModel

    @FocusState private var fallbackNameFocused: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isFileImporterPresented = false
    @State private var isAttachmentDropTargeted = false
    @State private var isImageDropTargeted = false
    @State private var isTagManagerPresented = false
    @State private var tagManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    @State private var isPlaceManagerPresented = false
    @State private var placeManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    @Environment(\.addEditFormCoordinator) private var formCoordinator
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) private var showPersianDates = false

    private var sectionCardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor)
    }

    private var sectionCardStroke: Color {
        Color.gray.opacity(0.18)
    }

    private var nameFocusBinding: FocusState<Bool>.Binding {
        model.nameFocus ?? $fallbackNameFocused
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                identityCard
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    scrollableFormSections
                        .padding(.horizontal, 24)
                        .padding(.bottom, 22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .onChange(of: formCoordinator.scrollTarget) { _, target in
                guard let target else { return }
                if target == .identity {
                    formCoordinator.scrollTarget = nil
                    return
                }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(target, anchor: .top)
                }
                formCoordinator.scrollTarget = nil
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
                nameFocusBinding.wrappedValue = true
            }
        }
    }

    // MARK: - Form sections

    /// All sections that are available given the current form state (excluding `.identity`).
    private var availableSections: [FormSection] {
        var sections: [FormSection] = [.color, .behavior, .pressure, .estimation, .places, .importanceUrgency, .tags, .goals, .linkedTasks, .linkURL, .notes]
        if isStepBasedMode { sections.append(.steps) }
        sections.append(.image)
        sections.append(.attachment)
        if model.onDelete != nil || model.pauseResumeAction != nil {
            sections.append(.dangerZone)
        }
        return sections
    }

    @ViewBuilder
    private var scrollableFormSections: some View {
        let ordered = formCoordinator.orderedSections(available: availableSections)
        VStack(alignment: .leading, spacing: 20) {
            ForEach(ordered, id: \.self) { section in
                formSectionView(for: section)
            }
        }
    }

    @ViewBuilder
    private func formSectionView(for section: FormSection) -> some View {
        switch section {
        case .identity:           EmptyView() // identityCard is rendered separately above the ScrollView
        case .color:              colorCard
        case .behavior:           behaviorCard
        case .pressure:           pressureCard
        case .estimation:         estimationCard
        case .places:             placesCard
        case .importanceUrgency:  importanceCard
        case .tags:               tagsCard
        case .goals:              goalsCard
        case .linkedTasks:        linkedTasksCard
        case .linkURL:            linkURLCard
        case .notes:              notesCard
        case .steps:              stepsCard
        case .image:              imageCard
        case .attachment:         attachmentCard
        case .dangerZone:         dangerZoneCard
        }
    }

    // MARK: Identity

    private var identityCard: some View {
        macSectionCard(
            title: "Identity"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                if model.autofocusName {
                    HStack(alignment: .top, spacing: 16) {
                        Text(model.emoji.wrappedValue)
                            .font(.system(size: 30))
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.accentColor.opacity(0.16)))

                        VStack(alignment: .leading, spacing: 10) {
                            taskNameField

                            if let msg = model.nameValidationMessage {
                                Text(msg)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if let scheduleModeTitle = previewScheduleModeTitle {
                                        macInfoPill(scheduleModeTitle, systemImage: "repeat")
                                    }
                                    if let previewPlaceSummary {
                                        macInfoPill(previewPlaceSummary, systemImage: "mappin.and.ellipse")
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 0)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        taskNameField

                        if let msg = model.nameValidationMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                macControlBlock(title: "") {
                    VStack(alignment: .leading, spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button("More Emoji") {
                                    model.isEmojiPickerPresented.wrappedValue = true
                                }
                                .buttonStyle(.bordered)

                                ForEach(Array(model.emojiOptions.prefix(8)), id: \.self) { emoji in
                                    Button {
                                        model.emoji.wrappedValue = emoji
                                    } label: {
                                        Text(emoji)
                                            .font(.title3)
                                            .frame(width: 34, height: 34)
                                            .background(
                                                Circle().fill(
                                                    model.emoji.wrappedValue == emoji
                                                        ? Color.accentColor.opacity(0.20)
                                                        : Color.secondary.opacity(0.08)
                                                )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .id(FormSection.identity)
    }

    private var taskNameField: some View {
        MacFocusableTextField(
            placeholder: "Task name",
            text: model.name,
            isFocusRequested: model.autofocusName,
            focusRequestID: model.nameFocusRequestID
        )
        .frame(height: 28)
    }

    // MARK: Color

    private var colorCard: some View {
        macSectionCard(title: "Color") {
            macControlBlock(
                title: "Background Color",
                caption: "Sets a tint on the task row and detail screen background."
            ) {
                HStack(spacing: 12) {
                    ForEach(RoutineTaskColor.allCases, id: \.self) { color in
                        Button {
                            model.color.wrappedValue = color
                        } label: {
                            ZStack {
                                if let c = color.swiftUIColor {
                                    Circle()
                                        .fill(c)
                                        .frame(width: 26, height: 26)
                                } else {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.12))
                                        .frame(width: 26, height: 26)
                                    Image(systemName: "circle.slash")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                }
                                if model.color.wrappedValue == color {
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: 2)
                                        .frame(width: 32, height: 32)
                                }
                            }
                            .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .help(color.displayName)
                    }

                    // Custom colour picker
                    ZStack {
                        ColorPicker(
                            "",
                            selection: customColorPickerBinding,
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())

                        if case .custom = model.color.wrappedValue {
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: 2)
                                .frame(width: 32, height: 32)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .help("Custom color")
                }
                .padding(.vertical, 4)
            }
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

    // MARK: Behavior

    private var behaviorCard: some View {
        macSectionCard(
            title: "Behavior"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                macControlBlock(title: "Type") {
                    HStack(spacing: 0) {
                        Picker("Task Type", selection: model.taskType) {
                            Text("Routine").tag(RoutineTaskType.routine)
                            Text("Todo").tag(RoutineTaskType.todo)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .fixedSize()
                        Spacer(minLength: 0)
                    }
                }

                if model.taskType.wrappedValue == .routine {
                    macControlBlock(title: "Schedule style") {
                        HStack(spacing: 0) {
                            Picker("Schedule Type", selection: model.scheduleMode) {
                                Text("Fixed").tag(RoutineScheduleMode.fixedInterval)
                                Text("Soft").tag(RoutineScheduleMode.softInterval)
                                Text("Checklist").tag(RoutineScheduleMode.fixedIntervalChecklist)
                                Text("Runout").tag(RoutineScheduleMode.derivedFromChecklist)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .fixedSize()
                            Spacer(minLength: 0)
                        }
                    }

                    if !isStepBasedMode {
                        macControlBlock(title: "Checklist") {
                            VStack(alignment: .leading, spacing: 12) {
                                checklistItemComposer
                                checklistItemsContent
                            }
                        }
                    }
                }

                if showsRepeatControls {
                    if model.scheduleMode.wrappedValue == .softInterval {
                        macControlBlock(title: "Soft reminder") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Text("Highlight again after")
                                        .foregroundStyle(.secondary)

                                    Stepper(value: model.frequencyValue, in: 1...365) {
                                        Text("\(model.frequencyValue.wrappedValue)")
                                            .font(.body.monospacedDigit())
                                            .frame(minWidth: 28, alignment: .trailing)
                                    }
                                    .fixedSize()

                                    Picker("Unit", selection: model.frequencyUnit) {
                                        ForEach(TaskFormFrequencyUnit.allCases, id: \.self) { unit in
                                            Text(unit.rawValue).tag(unit)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.segmented)
                                    .frame(width: 220)

                                    Spacer(minLength: 0)
                                }

                                Text("This routine stays visible and never becomes overdue. The app will just give it a softer nudge after this much time has passed.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        macControlBlock(title: "Repeat pattern") {
                            HStack(spacing: 0) {
                                Picker("Repeat Pattern", selection: model.recurrenceKind) {
                                    ForEach(RoutineRecurrenceRule.Kind.allCases, id: \.self) { kind in
                                        Text(kind.pickerTitle).tag(kind)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .fixedSize()
                                Spacer(minLength: 0)
                            }
                        }

                        switch model.recurrenceKind.wrappedValue {
                        case .intervalDays:
                            macControlBlock(title: "Repeat") {
                                HStack(spacing: 10) {
                                    Text("Every")
                                        .foregroundStyle(.secondary)

                                    Stepper(value: model.frequencyValue, in: 1...365) {
                                        Text("\(model.frequencyValue.wrappedValue)")
                                            .font(.body.monospacedDigit())
                                            .frame(minWidth: 28, alignment: .trailing)
                                    }
                                    .fixedSize()

                                    Picker("Unit", selection: model.frequencyUnit) {
                                        ForEach(TaskFormFrequencyUnit.allCases, id: \.self) { unit in
                                            Text(unit.rawValue).tag(unit)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.segmented)
                                    .frame(width: 220)

                                    Spacer(minLength: 0)
                                }
                            }

                        case .dailyTime:
                            macControlBlock(title: "Time") {
                                DatePicker(
                                    "Time",
                                    selection: model.recurrenceTimeOfDay,
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                            }

                        case .weekly:
                            macControlBlock(title: "Weekday") {
                                Picker("Weekday", selection: model.recurrenceWeekday) {
                                    ForEach(weekdayOptions, id: \.id) { option in
                                        Text(option.name).tag(option.id)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }

                            macControlBlock(title: "Time") {
                                VStack(alignment: .leading, spacing: 10) {
                                    Toggle("Set exact time", isOn: model.recurrenceHasExplicitTime)
                                    if model.recurrenceHasExplicitTime.wrappedValue {
                                        DatePicker(
                                            "Time",
                                            selection: model.recurrenceTimeOfDay,
                                            displayedComponents: .hourAndMinute
                                        )
                                        .labelsHidden()
                                    }
                                    Text(weeklyRecurrenceTimeHelpText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                        case .monthlyDay:
                            macControlBlock(title: "Month day") {
                                Stepper(value: model.recurrenceDayOfMonth, in: 1...31) {
                                    Text(ordinalDay(model.recurrenceDayOfMonth.wrappedValue))
                                        .frame(minWidth: 40, alignment: .leading)
                                }
                                .fixedSize()
                            }

                            macControlBlock(title: "Time") {
                                VStack(alignment: .leading, spacing: 10) {
                                    Toggle("Set exact time", isOn: model.recurrenceHasExplicitTime)
                                    if model.recurrenceHasExplicitTime.wrappedValue {
                                        DatePicker(
                                            "Time",
                                            selection: model.recurrenceTimeOfDay,
                                            displayedComponents: .hourAndMinute
                                        )
                                        .labelsHidden()
                                    }
                                    Text(monthlyRecurrenceTimeHelpText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    macControlBlock(
                        title: "Assumed done",
                        caption: model.canAutoAssumeDailyDone
                            ? "Show this simple daily routine as assumed done by default. You can still confirm it or mark it not done later."
                            : "Available only for simple daily routines without steps or checklist items."
                    ) {
                        Toggle("Assume done automatically", isOn: model.autoAssumeDailyDone)
                            .disabled(!model.canAutoAssumeDailyDone)
                    }
                }

                if model.taskType.wrappedValue == .todo {
                    macControlBlock(title: "Deadline") {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Set deadline", isOn: model.deadlineEnabled)
                            if model.deadlineEnabled.wrappedValue {
                                DatePicker("Deadline", selection: model.deadline)
                                    .labelsHidden()
                                if let persianDeadlineText {
                                    Text(persianDeadlineText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                macControlBlock(
                    title: "Reminder",
                    caption: "Send one notification at an exact date and time."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Set reminder", isOn: model.reminderEnabled)
                        if model.reminderEnabled.wrappedValue {
                            DatePicker("Reminder", selection: model.reminderAt)
                                .labelsHidden()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .id(FormSection.behavior)
    }

    // MARK: Places

    private var pressureCard: some View {
        macSectionCard(
            title: "Pressure"
        ) {
            macControlBlock(
                title: "Mental load",
                caption: "Use this for tasks that keep occupying your mind, even when they are not the most urgent."
            ) {
                HStack(spacing: 0) {
                    Picker("Pressure", selection: model.pressure) {
                        ForEach(RoutineTaskPressure.allCases, id: \.self) { pressure in
                            Text(pressure.title).tag(pressure)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                    Spacer(minLength: 0)
                }
            }
        }
        .id(FormSection.pressure)
    }

    private var estimationCard: some View {
        macSectionCard(
            title: "Estimation"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                macControlBlock(
                    title: "Duration",
                    caption: model.taskType.wrappedValue == .todo
                        ? "Estimate is the plan. Actual time records what really happened."
                        : "Estimate is the plan. Routines record actual time on each completion."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Set duration estimate", isOn: estimatedDurationEnabledBinding)
                        if estimatedDurationEnabledBinding.wrappedValue {
                            Stepper(value: estimatedDurationStepperBinding, in: 5...10_080, step: 5) {
                                Text(estimatedDurationLabel(for: estimatedDurationStepperBinding.wrappedValue))
                                    .frame(minWidth: 160, alignment: .leading)
                            }
                            .fixedSize()
                        }
                        if model.taskType.wrappedValue == .todo, model.actualDurationMinutes != nil {
                            Toggle("Set actual time spent", isOn: actualDurationEnabledBinding)
                            if actualDurationEnabledBinding.wrappedValue {
                                Stepper(value: actualDurationStepperBinding, in: 1...1_440, step: 5) {
                                    Text(estimatedDurationLabel(for: actualDurationStepperBinding.wrappedValue))
                                        .frame(minWidth: 160, alignment: .leading)
                                }
                                .fixedSize()
                            }
                        }
                    }
                }

                macControlBlock(title: "Story points") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Set story points", isOn: storyPointsEnabledBinding)
                        if storyPointsEnabledBinding.wrappedValue {
                            Stepper(value: storyPointsStepperBinding, in: 1...100) {
                                Text(storyPointsLabel(for: storyPointsStepperBinding.wrappedValue))
                                    .frame(minWidth: 160, alignment: .leading)
                            }
                            .fixedSize()
                        }
                    }
                }

                macControlBlock(title: "Focus") {
                    Toggle("Show focus timer", isOn: model.focusModeEnabled)
                }
            }
        }
        .id(FormSection.estimation)
    }

    // MARK: Places

    private var placesCard: some View {
        macSectionCard(
            title: "Places"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                macControlBlock(title: "Place") {
                    Picker("Place", selection: model.selectedPlaceID) {
                        Text("Anywhere").tag(Optional<UUID>.none)
                        ForEach(model.availablePlaces) { place in
                            Text(place.name).tag(Optional(place.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                macControlBlock(title: "") {
                    Button {
                        isPlaceManagerPresented = true
                    } label: {
                        Label("Manage Places", systemImage: "map")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .id(FormSection.places)
    }

    // MARK: Importance

    private var importanceCard: some View {
        macSectionCard(
            title: "Importance & Urgency"
        ) {
            macControlBlock(title: "Priority matrix") {
                ImportanceUrgencyMatrixPicker(
                    importance: model.importance,
                    urgency: model.urgency
                )
                .frame(maxWidth: 420, alignment: .leading)
            }
        }
        .id(FormSection.importanceUrgency)
    }

    // MARK: Tags

    private var tagsCard: some View {
        macSectionCard(
            title: "Tags"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                tagComposer
                tagsContent
                relatedTagSuggestionsContent
                availableTagSuggestionsContent
                manageTagsButton
            }
        }
        .id(FormSection.tags)
    }

    // MARK: Goals

    private var goalsCard: some View {
        macSectionCard(
            title: "Goals"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                goalComposer
                goalsContent
                availableGoalSuggestionsContent
                Text(goalSectionHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .id(FormSection.goals)
    }

    // MARK: Linked Tasks

    private var linkedTasksCard: some View {
        macSectionCard(
            title: "Linked tasks"
        ) {
            TaskRelationshipsEditor(
                relationships: model.relationships,
                candidates: model.availableRelationshipTasks,
                addRelationship: model.onAddRelationship,
                removeRelationship: model.onRemoveRelationship
            )
        }
        .id(FormSection.linkedTasks)
    }

    // MARK: Link URL

    private var linkURLCard: some View {
        macSectionCard(
            title: "Link URL"
        ) {
            TextField("https://example.com", text: model.link)
                .textFieldStyle(.roundedBorder)
                .routinaAddRoutinePlatformLinkField()
        }
        .id(FormSection.linkURL)
    }

    // MARK: Notes

    private var notesCard: some View {
        macSectionCard(
            title: "Notes"
        ) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: model.notes)
                    .frame(minHeight: 120)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(sectionCardStroke, lineWidth: 1)
                    )

                if model.notes.wrappedValue.isEmpty {
                    Text("Add notes, reminders, or context")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
        }
        .id(FormSection.notes)
    }

    // MARK: Steps

    private var stepsCard: some View {
        macSectionCard(title: "Steps") {
            VStack(alignment: .leading, spacing: 12) {
                stepComposer
                stepsContent
            }
        }
        .id(FormSection.steps)
    }

    // MARK: Image

    private var imageCard: some View {
        macSectionCard(
            title: "Image"
        ) {
            imageAttachmentContent
        }
        .id(FormSection.image)
    }

    // MARK: Attachment

    private var attachmentCard: some View {
        macSectionCard(
            title: "File Attachment"
        ) {
            attachmentContent
        }
        .id(FormSection.attachment)
    }

    @ViewBuilder
    private var attachmentContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.attachments.isEmpty {
                Label("No files attached", systemImage: "doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.attachments) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.title3)
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

            Button("Add File") {
                isFileImporterPresented = true
            }
            .buttonStyle(.bordered)

            Text("Attach any file up to 20 MB. You can also drag a file from Finder onto this area.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isAttachmentDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isAttachmentDropTargeted ? Color.accentColor : Color.secondary.opacity(0.18),
                    style: StrokeStyle(lineWidth: isAttachmentDropTargeted ? 2 : 1, dash: [8, 6])
                )
        )
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty else { return false }
            urls.forEach { loadAttachment(fromFileAt: $0) }
            return true
        } isTargeted: { isTargeted in
            isAttachmentDropTargeted = isTargeted
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            guard case let .success(urls) = result else { return }
            urls.forEach { loadAttachment(fromFileAt: $0) }
        }
    }

    // MARK: Danger Zone

    private var dangerZoneCard: some View {
        macSectionCard(title: "Danger Zone") {
            VStack(alignment: .leading, spacing: 10) {
                if let pauseAction = model.pauseResumeAction,
                   let pauseTitle = model.pauseResumeTitle {
                    Button(pauseTitle) { pauseAction() }
                        .buttonStyle(.bordered)
                        .tint(model.pauseResumeTint)

                    if let pauseDesc = model.pauseResumeDescription {
                        Text(pauseDesc)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    Divider()
                }

                if let deleteAction = model.onDelete {
                    Button(role: .destructive) {
                        deleteAction()
                    } label: {
                        Text("Delete Task")
                    }
                    .buttonStyle(.borderless)

                    Text("This action cannot be undone.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .id(FormSection.dangerZone)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var tagComposer: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .trailing) {
                MacTagAutocompleteTextField(
                    placeholder: "health, focus, morning",
                    text: model.tagDraft,
                    suggestion: model.tagAutocompleteSuggestion,
                    onSubmit: model.onAddTag,
                    onAcceptSuggestion: model.acceptTagAutocompleteSuggestion
                )
                .frame(height: 28)

                if let suggestion = model.tagAutocompleteSuggestion {
                    Button {
                        model.acceptTagAutocompleteSuggestion()
                    } label: {
                        HStack(spacing: 6) {
                            Text("#\(suggestion)")
                            Text("Tab")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(.secondary)
                        .background(.regularMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 5)
                    .help("Press Tab to complete #\(suggestion)")
                }
            }

            Button("Add") { model.onAddTag() }
                .buttonStyle(.bordered)
                .disabled(RoutineTag.parseDraft(model.tagDraft.wrappedValue).isEmpty)
        }
    }

    @ViewBuilder
    private var tagsContent: some View {
        if model.routineTags.isEmpty {
            Text(model.availableTags.isEmpty ? "No tags yet" : "No selected tags yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            TagFlowLayout(itemSpacing: 8, lineSpacing: 8) {
                ForEach(model.routineTags, id: \.self) { tag in
                    Button { model.onRemoveTag(tag) } label: {
                        HStack(spacing: 6) {
                            Text("#\(tag)")
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Image(systemName: "xmark.circle.fill").font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityLabel("Remove tag \(tag)")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var goalComposer: some View {
        HStack(spacing: 10) {
            TextField("Ship portfolio, improve health", text: model.goalDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.onAddGoal() }

            Button("Add") { model.onAddGoal() }
                .buttonStyle(.bordered)
                .disabled(!canAddGoalDraft)
        }
    }

    @ViewBuilder
    private var goalsContent: some View {
        if model.selectedGoals.isEmpty {
            Text(model.availableGoals.isEmpty ? "No goals yet" : "No selected goals yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            TagFlowLayout(itemSpacing: 8, lineSpacing: 8) {
                ForEach(model.selectedGoals) { goal in
                    Button { model.onRemoveGoal(goal.id) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                                .font(.caption)
                            Text(goal.displayTitle)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Image(systemName: "xmark.circle.fill").font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityLabel("Remove goal \(goal.displayTitle)")
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var relatedTagSuggestionsContent: some View {
        let suggestions = model.suggestedRelatedTags
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested related tags")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                TagFlowLayout(itemSpacing: 8, lineSpacing: 8) {
                    ForEach(suggestions, id: \.self) { tag in
                        Button { model.onToggleTagSelection(tag) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                Text("#\(tag)")
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.10), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color.orange.opacity(0.45), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
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
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                TagFlowLayout(itemSpacing: 8, lineSpacing: 8) {
                    ForEach(model.availableTags, id: \.self) { tag in
                        let isSelected = RoutineTag.contains(tag, in: model.routineTags)
                        let summary = model.availableTagSummaries.first(where: {
                            RoutineTag.normalized($0.name) == RoutineTag.normalized(tag)
                        })
                        Button { model.onToggleTagSelection(tag) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.caption)
                                Text(tagChipTitle(tag: tag, summary: summary))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(
                                    isSelected
                                        ? Color.accentColor.opacity(0.16)
                                        : Color.secondary.opacity(0.10)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
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
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                TagFlowLayout(itemSpacing: 8, lineSpacing: 8) {
                    ForEach(model.availableGoals) { goal in
                        let isSelected = model.selectedGoals.contains(where: { $0.id == goal.id })
                        Button { model.onToggleGoalSelection(goal) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.caption)
                                Text(goal.displayTitle)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(
                                    isSelected
                                        ? Color.accentColor.opacity(0.16)
                                        : Color.secondary.opacity(0.10)
                                )
                            )
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
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

    private var manageTagsButton: some View {
        Button {
            isTagManagerPresented = true
        } label: {
            Label("Manage Tags", systemImage: "slider.horizontal.3")
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var stepComposer: some View {
        HStack(spacing: 10) {
            TextField("Wash clothes", text: model.stepDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.onAddStep() }

            Button("Add") { model.onAddStep() }
                .buttonStyle(.bordered)
                .disabled(RoutineStep.normalizedTitle(model.stepDraft.wrappedValue) == nil)
        }
    }

    @ViewBuilder
    private var stepsContent: some View {
        if model.routineSteps.isEmpty {
            Text("No steps yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(Array(model.routineSteps.enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 10) {
                        Text("\(index + 1).")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .leading)

                        Text(step.title)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 6) {
                            Button { model.onMoveStepUp(step.id) } label: {
                                Image(systemName: "arrow.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)

                            Button { model.onMoveStepDown(step.id) } label: {
                                Image(systemName: "arrow.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == model.routineSteps.count - 1)

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
    }

    @ViewBuilder
    private var checklistItemComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Bread", text: model.checklistItemDraftTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.onAddChecklistItem() }

            if model.scheduleMode.wrappedValue == .derivedFromChecklist {
                Stepper(value: model.checklistItemDraftInterval, in: 1...365) {
                    Text(checklistIntervalLabel(for: model.checklistItemDraftInterval.wrappedValue))
                }
            }

            Button("Add Item") { model.onAddChecklistItem() }
                .buttonStyle(.bordered)
                .disabled(RoutineChecklistItem.normalizedTitle(model.checklistItemDraftTitle.wrappedValue) == nil)
        }
    }

    @ViewBuilder
    private var checklistItemsContent: some View {
        if model.routineChecklistItems.isEmpty {
            Text("No checklist items yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(model.routineChecklistItems) { item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if model.scheduleMode.wrappedValue == .derivedFromChecklist {
                                Text(checklistIntervalLabel(for: item.intervalDays))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(imagePickerLabel, systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)

                Button(model.imageData == nil ? "Browse in Finder" : "Browse Another File") {
                    browseForImageFile()
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
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("You can also drag an image from Finder onto this area.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
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
            guard let imageURL = urls.first(where: { isSupportedImageFile($0) }) else { return false }
            loadPickedImage(fromFileAt: imageURL)
            return true
        } isTargeted: { isTargeted in
            isImageDropTargeted = isTargeted
        }
    }

    // MARK: - Card helpers

    @ViewBuilder
    private func macSectionCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(sectionCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(sectionCardStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func macControlBlock<Content: View>(
        title: String,
        caption: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func macInfoPill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.secondary.opacity(0.10)))
    }

    // MARK: - Computed helpers

    private var isStepBasedMode: Bool {
        let mode = model.scheduleMode.wrappedValue
        return mode == .fixedInterval || mode == .softInterval || mode == .oneOff
    }

    private var showsRepeatControls: Bool {
        let mode = model.scheduleMode.wrappedValue
        return mode != .derivedFromChecklist && mode != .oneOff
    }

    private var taskTypeDescription: String {
        switch model.taskType.wrappedValue {
        case .routine: return "Routines repeat on a schedule and stay in your rotation."
        case .todo: return "Todos are one-off tasks. Once you finish one, it stays completed."
        }
    }

    private var scheduleModeDescription: String {
        switch model.scheduleMode.wrappedValue {
        case .fixedInterval: return "Use one overall repeat interval for the whole routine."
        case .softInterval: return "Keep this routine visible all the time and gently highlight it again after a while."
        case .fixedIntervalChecklist: return "Use one overall repeat interval and complete every checklist item to finish the routine."
        case .derivedFromChecklist: return "Use checklist item due dates to decide when the routine is due."
        case .oneOff: return "This task does not repeat."
        }
    }

    private var checklistSectionDescription: String {
        switch model.scheduleMode.wrappedValue {
        case .fixedIntervalChecklist: return "The routine is done when every checklist item is completed."
        case .derivedFromChecklist: return "Each item gets its own due date. The routine becomes due when the earliest item is due."
        case .fixedInterval, .softInterval, .oneOff: return ""
        }
    }

    private var recurrencePatternDescription: String {
        switch model.recurrenceKind.wrappedValue {
        case .intervalDays: return "Repeat after a fixed number of days, weeks, or months."
        case .dailyTime: return "Repeat every day at a specific time."
        case .weekly: return "Repeat on the same weekday each week, with an optional exact time."
        case .monthlyDay: return "Repeat on the same calendar day each month, with an optional exact time."
        }
    }

    private var placeSelectionDescription: String {
        if let id = model.selectedPlaceID.wrappedValue,
           let place = model.availablePlaces.first(where: { $0.id == id }) {
            return "Show this task when you are at \(place.name)."
        }
        return "Anywhere means the task is always visible."
    }

    private var importanceUrgencyDescription: String {
        let imp = model.importance.wrappedValue
        let urg = model.urgency.wrappedValue
        return "\(imp.title) importance and \(urg.title.lowercased()) urgency."
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

    private var stepsSectionDescription: String {
        model.scheduleMode.wrappedValue == .oneOff
            ? "Steps run in order. Leave this empty for a single-step todo."
            : "Steps run in order. Leave this empty for a one-step routine."
    }

    private var tagSectionHelpText: String {
        model.availableTags.isEmpty
            ? "Press return or Add. Separate multiple tags with commas, or open Manage Tags."
            : "Tap an existing tag below, open Manage Tags, or press return/Add to create a new one. Separate multiple tags with commas."
    }

    private var goalSectionHelpText: String {
        model.availableGoals.isEmpty
            ? "Press return or Add. Separate multiple goals with commas."
            : "Tap an existing goal below, or press return/Add to create a new one. Separate multiple goals with commas."
    }

    private var canAddGoalDraft: Bool {
        model.goalDraft.wrappedValue
            .split(separator: ",")
            .contains { RoutineGoal.cleanedTitle(String($0)) != nil }
    }

    // MARK: - Live preview helpers

    private var previewTitle: String {
        let trimmed = model.name.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
            ? "New \(model.taskType.wrappedValue == .todo ? "todo" : "routine")"
            : trimmed
    }

    private var previewSubtitle: String {
        if model.taskType.wrappedValue == .todo {
            return model.deadlineEnabled.wrappedValue
                ? "A one-off task with a deadline."
                : "A one-off task you can finish once."
        }
        switch model.scheduleMode.wrappedValue {
        case .fixedInterval: return "A repeating routine with one shared cadence."
        case .softInterval: return "A soft routine that stays visible and gently resurfaces after a while."
        case .fixedIntervalChecklist: return "A routine you complete by finishing every checklist item."
        case .derivedFromChecklist: return "A routine driven by the due dates of its checklist items."
        case .oneOff: return "A one-off task you can finish once."
        }
    }

    private var previewScheduleModeTitle: String? {
        guard model.taskType.wrappedValue == .routine else { return nil }
        switch model.scheduleMode.wrappedValue {
        case .fixedInterval: return "Fixed"
        case .softInterval: return "Soft"
        case .fixedIntervalChecklist: return "Checklist"
        case .derivedFromChecklist: return "Runout"
        case .oneOff: return nil
        }
    }

    private var previewScheduleSummary: String {
        if model.taskType.wrappedValue == .todo {
            return model.deadlineEnabled.wrappedValue
                ? "Due \(deadlineSummaryText)"
                : "One-off"
        }
        switch model.recurrenceKind.wrappedValue {
        case .intervalDays:
            return stepperLabel(
                frequencyUnit: model.frequencyUnit.wrappedValue,
                frequencyValue: model.frequencyValue.wrappedValue
            )
        case .dailyTime:
            return "Daily at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened))"
        case .weekly:
            if model.recurrenceHasExplicitTime.wrappedValue {
                return "Every \(weekdayName(for: model.recurrenceWeekday.wrappedValue)) at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened))"
            }
            return "Every \(weekdayName(for: model.recurrenceWeekday.wrappedValue))"
        case .monthlyDay:
            if model.recurrenceHasExplicitTime.wrappedValue {
                return "Monthly on the \(ordinalDay(model.recurrenceDayOfMonth.wrappedValue)) at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened))"
            }
            return "Monthly on the \(ordinalDay(model.recurrenceDayOfMonth.wrappedValue))"
        }
    }

    private var deadlineSummaryText: String {
        PersianDateDisplay.appendingSupplementaryDate(
            to: model.deadline.wrappedValue.formatted(date: .abbreviated, time: .omitted),
            for: model.deadline.wrappedValue,
            enabled: showPersianDates
        )
    }

    private var persianDeadlineText: String? {
        PersianDateDisplay.supplementaryText(
            for: model.deadline.wrappedValue,
            enabled: showPersianDates
        )
    }

    private var previewPlaceSummary: String? {
        guard let id = model.selectedPlaceID.wrappedValue,
              let place = model.availablePlaces.first(where: { $0.id == id }) else {
            return nil
        }
        return place.name
    }

    // MARK: - Utilities

    private func stepperLabel(frequencyUnit: TaskFormFrequencyUnit, frequencyValue: Int) -> String {
        frequencyValue == 1
            ? "Every \(frequencyUnit.singularLabel)"
            : "Every \(frequencyValue) \(frequencyUnit.singularLabel)s"
    }

    private func checklistIntervalLabel(for intervalDays: Int) -> String {
        intervalDays == 1 ? "Runs out in 1 day" : "Runs out in \(intervalDays) days"
    }

    private var weeklyRecurrenceTimeHelpText: String {
        if model.recurrenceHasExplicitTime.wrappedValue {
            return "Due every \(weekdayName(for: model.recurrenceWeekday.wrappedValue)) at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened))."
        }
        return "Optional. Leave this off to keep the routine due any time on \(weekdayName(for: model.recurrenceWeekday.wrappedValue))."
    }

    private var monthlyRecurrenceTimeHelpText: String {
        if model.recurrenceHasExplicitTime.wrappedValue {
            return "Due on the \(ordinalDay(model.recurrenceDayOfMonth.wrappedValue)) of each month at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened))."
        }
        return "Optional. Leave this off to keep the routine due any time on the \(ordinalDay(model.recurrenceDayOfMonth.wrappedValue)) of each month."
    }

    private var weekdayOptions: [(id: Int, name: String)] {
        Calendar.current.weekdaySymbols.enumerated().map { (id: $0.offset + 1, name: $0.element) }
    }

    private func weekdayName(for weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let safeIndex = min(max(weekday - 1, 0), symbols.count - 1)
        return symbols[safeIndex]
    }

    private func ordinalDay(_ day: Int) -> String {
        let resolvedDay = min(max(day, 1), 31)
        let suffix: String
        switch resolvedDay % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch resolvedDay % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(resolvedDay)\(suffix)"
    }

    private func isSupportedImageFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    private func loadPickedImage(from item: PhotosPickerItem) {
        _ = Task {
            let data = try? await item.loadTransferable(type: Data.self)
            _ = await MainActor.run {
                model.onImagePicked(data)
            }
        }
    }

    private func loadPickedImage(fromFileAt url: URL) {
        let compressedData = TaskImageProcessor.compressedImageData(fromFileAt: url)
        model.onImagePicked(compressedData)
    }

    private func browseForImageFile() {
        Task { @MainActor in
            guard let url = await PlatformSupport.selectTaskImageURL(),
                  isSupportedImageFile(url)
            else {
                return
            }
            loadPickedImage(fromFileAt: url)
        }
    }

    private func loadAttachment(fromFileAt url: URL) {
        let maxSize = 20 * 1024 * 1024  // 20 MB
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url), data.count <= maxSize else { return }
        model.onAttachmentPicked(data, url.lastPathComponent)
    }
}

private struct MacTagAutocompleteTextField: NSViewRepresentable {
    let placeholder: String
    let text: Binding<String>
    let suggestion: String?
    let onSubmit: () -> Void
    let onAcceptSuggestion: () -> Void

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacTagAutocompleteTextField

        init(parent: MacTagAutocompleteTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            if parent.text.wrappedValue != textField.stringValue {
                parent.text.wrappedValue = textField.stringValue
            }
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertTab(_:)):
                guard parent.suggestion != nil else { return false }
                parent.onAcceptSuggestion()
                return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            default:
                return false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text.wrappedValue)
        textField.placeholderString = placeholder
        textField.isBordered = true
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .default
        textField.delegate = context.coordinator
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self

        if nsView.stringValue != text.wrappedValue {
            nsView.stringValue = text.wrappedValue
        }

        nsView.placeholderString = placeholder
    }
}

private struct MacFocusableTextField: NSViewRepresentable {
    let placeholder: String
    let text: Binding<String>
    let isFocusRequested: Bool
    let focusRequestID: Int

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacFocusableTextField
        var lastAppliedFocusRequestID: Int?

        init(parent: MacFocusableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            if parent.text.wrappedValue != textField.stringValue {
                parent.text.wrappedValue = textField.stringValue
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text.wrappedValue)
        textField.placeholderString = placeholder
        textField.isBordered = true
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .default
        textField.delegate = context.coordinator
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self

        if nsView.stringValue != text.wrappedValue {
            nsView.stringValue = text.wrappedValue
        }

        guard isFocusRequested else {
            context.coordinator.lastAppliedFocusRequestID = nil
            return
        }

        guard context.coordinator.lastAppliedFocusRequestID != focusRequestID else {
            return
        }

        context.coordinator.lastAppliedFocusRequestID = focusRequestID
        let delays: [TimeInterval] = [0, 0.05, 0.15, 0.3, 0.6, 1.0, 1.5]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                focus(nsView)
            }
        }
    }

    private func focus(_ textField: NSTextField) {
        guard let window = textField.window else { return }
        window.makeFirstResponder(textField)
        textField.currentEditor()?.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
    }
}

private struct TagFlowLayout: Layout {
    let itemSpacing: CGFloat
    let lineSpacing: CGFloat

    init(itemSpacing: CGFloat = 8, lineSpacing: CGFloat = 8) {
        self.itemSpacing = itemSpacing
        self.lineSpacing = lineSpacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var currentX: CGFloat = 0
        var currentLineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let requiredWidth = currentX == 0 ? size.width : currentX + itemSpacing + size.width

            if requiredWidth > maxWidth && currentX > 0 {
                totalHeight += currentLineHeight + lineSpacing
                maxLineWidth = max(maxLineWidth, currentX)
                currentX = size.width
                currentLineHeight = size.height
            } else {
                currentX = requiredWidth
                currentLineHeight = max(currentLineHeight, size.height)
            }
        }

        if currentLineHeight > 0 {
            totalHeight += currentLineHeight
            maxLineWidth = max(maxLineWidth, currentX)
        }

        return CGSize(width: maxLineWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var currentLineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let extraSpacing = currentX == bounds.minX ? 0 : itemSpacing
            let proposedMaxX = currentX + extraSpacing + size.width

            if proposedMaxX > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += currentLineHeight + lineSpacing
                currentLineHeight = 0
            }

            let placementX = currentX == bounds.minX ? currentX : currentX + itemSpacing
            subview.place(
                at: CGPoint(x: placementX, y: currentY),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )

            currentX = placementX + size.width
            currentLineHeight = max(currentLineHeight, size.height)
        }
    }
}

import ComposableArchitecture
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
        FormSection.taskFormSections(
            scheduleMode: model.scheduleMode.wrappedValue,
            includesIdentity: false,
            includesDangerZone: model.onDelete != nil || model.pauseResumeAction != nil
        )
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
        TaskFormMacIdentityCard(
            model: model,
            previewScheduleModeTitle: previewScheduleModeTitle,
            previewPlaceSummary: previewPlaceSummary
        ) {
            taskNameField
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
        TaskFormMacBehaviorCard(
            model: model,
            presentation: presentation,
            persianDeadlineText: persianDeadlineText
        ) {
            checklistItemComposer
        } checklistItemsContent: {
            checklistItemsContent
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
                                Text(TaskFormPresentation.estimatedDurationLabel(for: estimatedDurationStepperBinding.wrappedValue))
                                    .frame(minWidth: 160, alignment: .leading)
                            }
                            .fixedSize()
                        }
                        if model.taskType.wrappedValue == .todo, model.actualDurationMinutes != nil {
                            Toggle("Set actual time spent", isOn: actualDurationEnabledBinding)
                            if actualDurationEnabledBinding.wrappedValue {
                                Stepper(value: actualDurationStepperBinding, in: 1...1_440, step: 5) {
                                    Text(TaskFormPresentation.estimatedDurationLabel(for: actualDurationStepperBinding.wrappedValue))
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
                                Text(TaskFormPresentation.storyPointsLabel(for: storyPointsStepperBinding.wrappedValue))
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
                Text(presentation.goalSectionHelpText)
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
            ) { searchText in
                TextField("Search tasks", text: searchText)
                    .routinaTaskRelationshipSearchFieldPlatform()
            }
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
        TaskFormMacDangerZoneCard(
            pauseResumeAction: model.pauseResumeAction,
            pauseResumeTitle: model.pauseResumeTitle,
            pauseResumeDescription: model.pauseResumeDescription,
            pauseResumeTint: model.pauseResumeTint,
            onDelete: model.onDelete
        )
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
                .disabled(!presentation.canAddGoalDraft)
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
                    Text(TaskFormPresentation.checklistIntervalLabel(for: model.checklistItemDraftInterval.wrappedValue))
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
                                Text(TaskFormPresentation.checklistIntervalLabel(for: item.intervalDays))
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
        TaskFormMacSectionCard(title: title, subtitle: subtitle) {
            content()
        }
    }

    @ViewBuilder
    private func macControlBlock<Content: View>(
        title: String,
        caption: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        TaskFormMacControlBlock(title: title, caption: caption) {
            content()
        }
    }

    // MARK: - Computed helpers

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
            return TaskFormPresentation.stepperLabel(
                unit: model.frequencyUnit.wrappedValue,
                value: model.frequencyValue.wrappedValue
            )
        case .dailyTime:
            return "Daily at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened))"
        case .weekly:
            if model.recurrenceHasExplicitTime.wrappedValue {
                return "Every \(TaskFormPresentation.weekdayName(for: model.recurrenceWeekday.wrappedValue)) at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened))"
            }
            return "Every \(TaskFormPresentation.weekdayName(for: model.recurrenceWeekday.wrappedValue))"
        case .monthlyDay:
            if model.recurrenceHasExplicitTime.wrappedValue {
                return "Monthly on the \(TaskFormPresentation.ordinalDay(model.recurrenceDayOfMonth.wrappedValue)) at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened))"
            }
            return "Monthly on the \(TaskFormPresentation.ordinalDay(model.recurrenceDayOfMonth.wrappedValue))"
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
        selectedPlaceName
    }

    // MARK: - Utilities

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

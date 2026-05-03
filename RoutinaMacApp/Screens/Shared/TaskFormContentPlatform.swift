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
            TaskFormMacTagsContent(model: model) {
                isTagManagerPresented = true
            }
        }
        .id(FormSection.tags)
    }

    // MARK: Goals

    private var goalsCard: some View {
        macSectionCard(
            title: "Goals"
        ) {
            TaskFormMacGoalsContent(model: model, presentation: presentation)
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
            TaskFormMacImageContent(
                model: model,
                selectedPhotoItem: $selectedPhotoItem,
                isDropTargeted: $isImageDropTargeted,
                isSupportedImageFile: { isSupportedImageFile($0) },
                onLoadPickedImageURL: { loadPickedImage(fromFileAt: $0) },
                onBrowseImageFile: browseForImageFile
            )
        }
        .id(FormSection.image)
    }

    // MARK: Attachment

    private var attachmentCard: some View {
        macSectionCard(
            title: "File Attachment"
        ) {
            TaskFormMacAttachmentContent(
                model: model,
                isFileImporterPresented: $isFileImporterPresented,
                isDropTargeted: $isAttachmentDropTargeted,
                onLoadAttachment: { loadAttachment(fromFileAt: $0) }
            )
        }
        .id(FormSection.attachment)
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

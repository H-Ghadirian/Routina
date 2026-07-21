import ComposableArchitecture
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

enum TaskFormContentLayout {
    case fullForm
    case embeddedSections([FormSection])
}

struct TaskFormContent: View {
    let model: TaskFormModel
    let layout: TaskFormContentLayout

    @FocusState private var fallbackNameFocused: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isFileImporterPresented = false
    @State private var isAttachmentDropTargeted = false
    @State private var isImageDropTargeted = false
    @State private var hasAppliedInitialNameAutofocus = false
    @State private var isTagManagerPresented = false
    @State private var tagManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    @State private var isPlaceManagerPresented = false
    @State private var placeManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    @Environment(\.calendar) private var calendar
    @Environment(\.addEditFormCoordinator) private var formCoordinator
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) private var showPersianDates = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isGoalsTabEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isNotesEnabled = false

    init(
        model: TaskFormModel,
        layout: TaskFormContentLayout = .fullForm
    ) {
        self.model = model
        self.layout = layout
    }

    private var nameFocusBinding: FocusState<Bool>.Binding {
        model.nameFocus ?? $fallbackNameFocused
    }

    var body: some View {
        content
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
                guard model.autofocusName, !hasAppliedInitialNameAutofocus else { return }
                hasAppliedInitialNameAutofocus = true
                Task { @MainActor in
                    await Task.yield()
                    nameFocusBinding.wrappedValue = true
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch layout {
        case .fullForm:
            fullFormContent
        case let .embeddedSections(sections):
            embeddedSectionsContent(sections)
        }
    }

    private var fullFormContent: some View {
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
    }

    private func embeddedSectionsContent(_ sections: [FormSection]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(sections, id: \.self) { section in
                formSectionView(for: section)
            }

            embeddedActionButtons
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var embeddedActionButtons: some View {
        if model.onCancel != nil || model.onSave != nil {
            HStack(spacing: 8) {
                Spacer(minLength: 0)

                if let onCancel = model.onCancel {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                if let onSave = model.onSave {
                    Button {
                        onSave()
                    } label: {
                        saveButtonLabel
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(model.isSaveDisabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var saveButtonLabel: some View {
        if model.isSaving {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Saving…")
            }
            .accessibilityLabel("Saving task")
        } else {
            Text("Save")
        }
    }

    // MARK: - Form sections

    /// All sections that are available given the current form state (excluding `.identity`).
    private var availableSections: [FormSection] {
        FormSection.taskFormSections(
            scheduleMode: model.scheduleMode.wrappedValue,
            includesIdentity: false,
            includesDangerZone: model.onDelete != nil || model.pauseResumeAction != nil
        ).filter { section in
            (section != .planning || model.supportsPlanning) && shouldDisplayFormSection(section)
        }
    }

    private func shouldDisplayFormSection(_ section: FormSection) -> Bool {
        if section == .places {
            return isPlacesEnabled
        }
        if section == .notes || section == .voiceNote {
            return isNotesEnabled
        }
        return section != .goals || isGoalsTabEnabled
    }

    private var visibleSections: [FormSection] {
        FormSection.visibleTaskFormSections(
            from: availableSections,
            mode: model.visibilityMode,
            revealedSections: formCoordinator.revealedTaskFormSections,
            populatedSections: model.populatedMacFormSections,
            allowsOptionalChecklistReveal: model.allowsOptionalChecklistReveal
        )
    }

    private var hiddenOptionalSections: [FormSection] {
        let visibleSet = Set(visibleSections)
        return formCoordinator.orderedSections(available: availableSections).filter {
            $0 != .identity
                && !visibleSet.contains($0)
                && canRevealOptionalSection($0)
        }
    }

    private func canRevealOptionalSection(_ section: FormSection) -> Bool {
        section != .checklist || model.allowsOptionalChecklistReveal
    }

    @ViewBuilder
    private var scrollableFormSections: some View {
        let ordered = formCoordinator.orderedSections(available: visibleSections)
        VStack(alignment: .leading, spacing: 20) {
            ForEach(ordered, id: \.self) { section in
                formSectionView(for: section)
            }

            if model.visibilityMode.usesProgressiveDisclosure && !hiddenOptionalSections.isEmpty {
                addDetailsCard(sections: hiddenOptionalSections)
            }
        }
    }

    private func addDetailsCard(sections: [FormSection]) -> some View {
        TaskFormMacSectionCard(title: "Add More Details") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 132), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(sections, id: \.self) { section in
                    Button {
                        revealOptionalSection(section)
                    } label: {
                        Label(section.addButtonTitle, systemImage: section.icon)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Add \(section.title)")
                }
            }
        }
    }

    private func revealOptionalSection(_ section: FormSection) {
        withAnimation(.easeInOut(duration: 0.18)) {
            formCoordinator.revealTaskFormSection(section)
        }

        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeInOut(duration: 0.25)) {
                formCoordinator.scrollTarget = section
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
        case .places:
            if isPlacesEnabled {
                placesCard
            }
        case .importanceUrgency:  importanceCard
        case .tags:               tagsCard
        case .goals:              goalsCard
        case .events:             eventsCard
        case .linkedTasks:        linkedTasksCard
        case .planning:           planningCard
        case .linkURL:            linkURLCard
        case .notes:
            if isNotesEnabled {
                notesCard
            }
        case .steps:              stepsCard
        case .checklist:          checklistCard
        case .image:              imageCard
        case .voiceNote:
            if isNotesEnabled {
                voiceNoteCard
            }
        case .attachment:         attachmentCard
        case .dangerZone:         dangerZoneCard
        }
    }

    // MARK: Identity

    private var identityCard: some View {
        TaskFormMacIdentityCard(
            model: model,
            smartNameDraft: smartNameDraft,
            smartNameCalendar: calendar,
            onApplySmartName: model.onApplySmartName
        ) {
            taskNameField
        }
        .id(FormSection.identity)
    }

    private var smartNameDraft: RoutinaQuickAddDraft? {
        guard let draft = RoutinaQuickAddParser.parse(
            model.name.wrappedValue,
            calendar: calendar,
            includingPlaces: isPlacesEnabled
        ),
              draft.hasDetectedMetadata else {
            return nil
        }
        return draft
    }

    private var taskNameField: some View {
        MacFocusableTextField(
            placeholder: smartNamePlaceholder,
            text: model.name,
            isFocusRequested: model.autofocusName,
            focusRequestID: model.nameFocusRequestID,
            onTab: smartNameDraft == nil ? nil : model.onApplySmartName
        )
        .frame(height: 50)
    }

    private var smartNamePlaceholder: String {
        if isPlacesEnabled {
            return "Water plants every Sat at 9am #home @Balcony !high 25m"
        }
        return "Water plants every Sat at 9am #home !high 25m"
    }

    // MARK: Color

    private var colorCard: some View {
        TaskFormMacColorCard(model: model)
    }

    // MARK: Behavior

    private var behaviorCard: some View {
        TaskFormMacBehaviorCard(
            model: model,
            presentation: presentation,
            persianDeadlineText: persianDeadlineText
        )
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
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Pressure",
                        options: RoutineTaskPressure.allCases,
                        selection: model.pressure
                    ) { pressure in
                        Text(pressure.title)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .id(FormSection.pressure)
    }

    private var estimationCard: some View {
        TaskFormMacEstimationCard(model: model)
        .id(FormSection.estimation)
    }

    // MARK: Places

    private var placesCard: some View {
        TaskFormMacPlacesCard(model: model) {
            isPlaceManagerPresented = true
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

    // MARK: Events

    private var eventsCard: some View {
        macSectionCard(
            title: "Events"
        ) {
            TaskFormLinkedEventsContent(
                events: model.availableEvents,
                selectedEventIDs: model.selectedEventIDs,
                onToggleEvent: model.onToggleEventSelection
            )
        }
        .id(FormSection.events)
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

    // MARK: Planning

    @ViewBuilder
    private var planningCard: some View {
        if model.supportsPlanning {
            TaskFormMacPlanningCard(model: model)
                .id(FormSection.planning)
        }
    }

    // MARK: Links

    private var linkURLCard: some View {
        TaskFormMacLinkCard(model: model, presentation: presentation)
        .id(FormSection.linkURL)
    }

    // MARK: Notes

    private var notesCard: some View {
        TaskFormMacNotesCard(model: model)
        .id(FormSection.notes)
    }

    // MARK: Steps

    private var stepsCard: some View {
        macSectionCard(title: "Steps") {
            TaskFormMacStepsContent(model: model)
        }
        .id(FormSection.steps)
    }

    // MARK: Checklist

    private var checklistCard: some View {
        macSectionCard(
            title: "Checklist",
            subtitle: presentation.checklistSectionDescription(includesDerivedChecklistDueDetail: true)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TaskFormMacChecklistComposer(model: model)
                if let message = model.checklistValidationMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                TaskFormMacChecklistItemsContent(model: model)
            }
        }
        .id(FormSection.checklist)
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

    // MARK: Voice Note

    private var voiceNoteCard: some View {
        macSectionCard(
            title: "Voice Note"
        ) {
            TaskFormMacVoiceNoteContent(model: model)
        }
        .id(FormSection.voiceNote)
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
            recurrenceHasTimeRange: model.recurrenceHasTimeRange.wrappedValue,
            recurrenceWeekday: model.recurrenceWeekday.wrappedValue,
            recurrenceDayOfMonth: model.recurrenceDayOfMonth.wrappedValue,
            recurrenceWeekdays: model.effectiveRecurrenceWeekdays,
            recurrenceDaysOfMonth: model.effectiveRecurrenceDaysOfMonth,
            importance: model.importance.wrappedValue,
            urgency: model.urgency.wrappedValue,
            hasAvailableTags: !model.availableTags.isEmpty,
            hasAvailableGoals: !model.availableGoals.isEmpty,
            goalDraft: model.goalDraft.wrappedValue,
            selectedPlaceName: isPlacesEnabled ? selectedPlaceName : nil,
            canAutoAssumeDailyDone: model.canAutoAssumeDailyDone
        )
    }

    private var selectedPlaceName: String? {
        if let id = model.selectedPlaceIDsValue.first,
           let place = model.availablePlaces.first(where: { $0.id == id }) {
            return place.name
        }
        return nil
    }

    // MARK: - Live preview helpers

    private var previewTitle: String {
        let trimmed = model.name.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
            ? "New \(model.taskType.wrappedValue.rawValue.lowercased())"
            : trimmed
    }

    private var previewSubtitle: String {
        switch model.taskType.wrappedValue {
        case .todo:
            return model.deadlineEnabled.wrappedValue
                ? "A one-off task with a deadline."
                : "A one-off task you can finish once."
        case .routine, .record:
            break
        }
        switch model.scheduleMode.wrappedValue {
        case .fixedInterval: return "A repeating routine with one shared cadence."
        case .softInterval: return "A gentle routine that stays visible and resurfaces without overdue pressure."
        case .fixedIntervalChecklist: return "A routine you complete by finishing every checklist item."
        case .softIntervalChecklist: return "A gentle routine you complete by finishing every checklist item."
        case .derivedFromChecklist: return "A routine driven by the due dates of its checklist items."
        case .softDerivedFromChecklist: return "A gentle routine driven by checklist item timing."
        case .oneOff: return "A one-off task you can finish once."
        case .record: return "Gentle tracking for what happened and how time was spent."
        case .recordChecklist: return "Gentle tracking completed by finishing every checklist item."
        case .recordDerivedFromChecklist: return "Gentle tracking driven by checklist item timing."
        }
    }

    private var previewScheduleSummary: String {
        switch model.taskType.wrappedValue {
        case .todo:
            return model.deadlineEnabled.wrappedValue
                ? "Due \(deadlineSummaryText)"
                : "One-off"
        case .routine, .record:
            break
        }
        switch model.recurrenceKind.wrappedValue {
        case .intervalDays:
            return TaskFormPresentation.stepperLabel(
                unit: model.frequencyUnit.wrappedValue,
                value: model.frequencyValue.wrappedValue
            )
        case .dailyTime:
            if model.recurrenceHasTimeRange.wrappedValue {
                return "Daily \(previewTimeRangeText)"
            }
            return "Daily at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened))"
        case .weekly:
            let weekdayText = TaskFormPresentation.weekdayListText(for: model.effectiveRecurrenceWeekdays)
            if model.recurrenceHasTimeRange.wrappedValue {
                return "Every \(weekdayText) \(previewTimeRangeText)"
            }
            if model.recurrenceHasExplicitTime.wrappedValue {
                return "Every \(weekdayText) at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened))"
            }
            return "Every \(weekdayText)"
        case .monthlyDay:
            if model.recurrenceHasTimeRange.wrappedValue {
                return TaskFormPresentation.monthlyScheduleSummary(
                    for: model.effectiveRecurrenceDaysOfMonth,
                    timingText: previewTimeRangeText
                )
            }
            if model.recurrenceHasExplicitTime.wrappedValue {
                return TaskFormPresentation.monthlyScheduleSummary(
                    for: model.effectiveRecurrenceDaysOfMonth,
                    timingText: "at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened))"
                )
            }
            return TaskFormPresentation.monthlyScheduleSummary(for: model.effectiveRecurrenceDaysOfMonth)
        }
    }

    private var deadlineSummaryText: String {
        PersianDateDisplay.appendingSupplementaryDate(
            to: model.deadline.wrappedValue.formatted(date: .abbreviated, time: .omitted),
            for: model.deadline.wrappedValue,
            enabled: showPersianDates
        )
    }

    private var previewTimeRangeText: String {
        "\(model.recurrenceTimeRangeStart.wrappedValue.formatted(date: .omitted, time: .shortened))-\(model.recurrenceTimeRangeEnd.wrappedValue.formatted(date: .omitted, time: .shortened))"
    }

    private var persianDeadlineText: String? {
        PersianDateDisplay.supplementaryText(
            for: model.deadline.wrappedValue,
            enabled: showPersianDates
        )
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

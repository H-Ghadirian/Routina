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
    @State private var hasAppliedInitialNameAutofocus = false
    @State private var isPlaceManagerPresented = false
    @State private var placeManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isFileImporterPresented = false
    @State private var revealedSections: Set<TaskFormCompactSection> = []
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) private var showPersianDates = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isNotesEnabled = false

    init(model: TaskFormModel) {
        self.model = model
        _revealedSections = State(initialValue: model.initiallyRevealedCompactSections)
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                ForEach(
                    visibleCompactSections.filter { $0 != .delete },
                    id: \.self
                ) { section in
                    compactSection(section)
                        .id(section)
                }

                if model.visibilityMode.usesProgressiveDisclosure,
                   !hiddenOptionalSections.isEmpty {
                    addDetailsSection(
                        hiddenOptionalSections,
                        proxy: proxy
                    )
                }

                if visibleCompactSections.contains(.delete) {
                    compactSection(.delete)
                        .id(TaskFormCompactSection.delete)
                }
            }
            .formStyle(.grouped)
            .listSectionSpacing(20)
            .contentMargins(.top, 10, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
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
            guard model.autofocusName, !hasAppliedInitialNameAutofocus else { return }
            hasAppliedInitialNameAutofocus = true
            Task { @MainActor in
                await Task.yield()
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

    private func addDetailsSection(
        _ sections: [TaskFormCompactSection],
        proxy: ScrollViewProxy
    ) -> some View {
        Section {
            Menu {
                ForEach(sections, id: \.self) { section in
                    Button {
                        reveal(section, proxy: proxy)
                    } label: {
                        Label(
                            section.iosAddDetailsTitle,
                            systemImage: section.iosAddDetailsSystemImage
                        )
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Label("Add details", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

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

    private var visibleCompactSections: [TaskFormCompactSection] {
        let availableSections = filteredCompactSections(showingAllDetails: true)
        guard model.visibilityMode.usesProgressiveDisclosure else {
            return availableSections
        }

        let defaultSections = Set(filteredCompactSections(showingAllDetails: false))
        return availableSections.filter {
            defaultSections.contains($0)
                || revealedSections.contains($0)
                || $0 == .delete
        }
    }

    private var hiddenOptionalSections: [TaskFormCompactSection] {
        let visibleSections = Set(visibleCompactSections)
        return filteredCompactSections(showingAllDetails: true).filter {
            !visibleSections.contains($0) && $0 != .delete
        }
    }

    private func filteredCompactSections(
        showingAllDetails: Bool
    ) -> [TaskFormCompactSection] {
        model.visibleCompactSections(isShowingMoreDetails: showingAllDetails).filter {
            switch $0 {
            case .place:
                return isPlacesEnabled
            case .notes, .voiceNote:
                return isNotesEnabled
            default:
                return true
            }
        }
    }

    private func reveal(
        _ section: TaskFormCompactSection,
        proxy: ScrollViewProxy
    ) {
        withAnimation(.easeInOut(duration: 0.2)) {
            _ = revealedSections.insert(section)
        }

        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(section, anchor: .top)
            }
        }
    }

    private var selectedPlaceName: String? {
        if let id = model.selectedPlaceIDsValue.first,
           let place = model.availablePlaces.first(where: { $0.id == id }) {
            return place.name
        }
        return nil
    }

    @ViewBuilder
    private func compactSection(_ section: TaskFormCompactSection) -> some View {
        switch section {
        case .name:
            nameSection
        case .taskType:
            taskTypeSection
        case .taskDescription:
            taskDescriptionSection
        case .emoji:
            emojiSection
        case .color:
            colorSection
        case .notes:
            notesSection
        case .voiceNote:
            voiceNoteSection
        case .link:
            linkSection
        case .planning:
            planningSection
        case .deadline:
            if model.taskType.wrappedValue == .todo {
                deadlineSection
            }
        case .reminder:
            if model.supportsExactDateReminder {
                reminderSection
            }
        case .importanceUrgency:
            importanceUrgencySection
        case .pressure:
            pressureSection
        case .thinkingNeeded:
            thinkingNeededSection
        case .estimation:
            estimationSection
        case .image:
            imageSection
        case .attachment:
            attachmentSection
        case .tags:
            tagsSection
        case .goals:
            goalsSection
        case .events:
            eventsSection
        case .relationships:
            relationshipsSection
        case .scheduleType:
            if model.scheduleMode.wrappedValue.taskType == .routine || model.scheduleMode.wrappedValue.taskType == .record {
                scheduleTypeSection
            }
        case .steps:
            if presentation.isStepBasedMode {
                stepsSection
            }
        case .checklist:
            checklistSection
        case .place:
            if isPlacesEnabled {
                placeSection
            }
        case .repeatPattern:
            if presentation.showsRepeatControls {
                repeatPatternSections
            }
        case .delete:
            if let onDelete = model.onDelete {
                deleteSection(onDelete: onDelete)
            }
        }
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
        TaskFormIOSNameSection(model: model, isNameFocused: $isNameFocused)
    }

    private var taskTypeSection: some View {
        TaskFormIOSTaskTypeSection(model: model, presentation: presentation)
    }

    private var taskDescriptionSection: some View {
        TaskFormIOSDescriptionSection(model: model)
    }

    private var emojiSection: some View {
        TaskFormIOSEmojiSection(model: model)
    }

    private var colorSection: some View {
        TaskFormIOSColorSection(model: model)
    }

    private var notesSection: some View {
        TaskFormIOSNotesSection(model: model, presentation: presentation)
    }

    private var linkSection: some View {
        TaskFormIOSLinkSection(model: model, presentation: presentation)
    }

    private var planningSection: some View {
        TaskFormIOSPlanningSection(model: model)
    }

    private var deadlineSection: some View {
        TaskFormIOSDeadlineSection(model: model, persianDeadlineText: persianDeadlineText)
    }

    private var persianDeadlineText: String? {
        PersianDateDisplay.supplementaryText(
            for: model.deadline.wrappedValue,
            enabled: showPersianDates
        )
    }

    private var reminderSection: some View {
        TaskFormIOSReminderSection(model: model)
    }

    private var importanceUrgencySection: some View {
        TaskFormIOSImportanceUrgencySection(model: model, presentation: presentation)
    }

    private var pressureSection: some View {
        TaskFormIOSPressureSection(model: model)
    }

    private var thinkingNeededSection: some View {
        TaskFormIOSThinkingNeededSection(model: model)
    }

    private var estimationSection: some View {
        TaskFormIOSEstimationSection(model: model)
    }

    private var imageSection: some View {
        Section(header: Text("Image")) {
            TaskFormIOSImageContent(
                model: model,
                selectedPhotoItem: $selectedPhotoItem
            )
        }
    }

    private var voiceNoteSection: some View {
        Section(header: Text("Voice Note")) {
            TaskFormIOSVoiceNoteContent(model: model)
        }
    }

    private var attachmentSection: some View {
        Section(header: Text("File Attachment")) {
            TaskFormIOSAttachmentContent(model: model) {
                isFileImporterPresented = true
            }
        }
    }

    private var tagsSection: some View {
        TaskFormIOSTagsSection(
            model: model,
            tagColor: tagColor(for:)
        ) {
            isTagManagerPresented = true
        }
    }

    private var goalsSection: some View {
        TaskFormIOSGoalsSection(model: model, presentation: presentation)
    }

    private var eventsSection: some View {
        TaskFormIOSEventsSection(model: model)
    }

    private var relationshipsSection: some View {
        TaskFormIOSRelationshipsSection(model: model)
    }

    private var scheduleTypeSection: some View {
        TaskFormIOSScheduleTypeSection(model: model, presentation: presentation)
    }

    private var stepsSection: some View {
        TaskFormIOSStepsSection(model: model, presentation: presentation)
    }

    private var checklistSection: some View {
        TaskFormIOSChecklistSection(model: model, presentation: presentation)
    }

    private var placeSection: some View {
        TaskFormIOSPlaceSection(model: model, presentation: presentation) {
            isPlaceManagerPresented = true
        }
    }

    @ViewBuilder
    private var repeatPatternSections: some View {
        TaskFormIOSRepeatPatternSections(model: model, presentation: presentation)
    }

    private func tagColor(for tag: String) -> Color? {
        model.availableTagSummaries.first {
            RoutineTag.normalized($0.name) == RoutineTag.normalized(tag)
        }?.displayColor
        ?? Color(routineTagHex: RoutineTagColors.colorHex(for: tag, in: appSettingsClient.tagColors()))
    }

    private func deleteSection(onDelete: @escaping () -> Void) -> some View {
        Section {
            Button(role: .destructive) { onDelete() } label: {
                Text("Delete Task")
            }
        } footer: {
            Text("This action cannot be undone.")
        }
    }

}

private extension TaskFormCompactSection {
    var iosAddDetailsTitle: String {
        switch self {
        case .name: return "Name"
        case .taskType: return "Task type"
        case .taskDescription: return "Description"
        case .emoji: return "Emoji"
        case .color: return "Color"
        case .notes: return "Notes"
        case .voiceNote: return "Voice note"
        case .link: return "Links"
        case .planning: return "Planning"
        case .deadline: return "Deadline"
        case .reminder: return "Reminder"
        case .importanceUrgency: return "Importance & urgency"
        case .pressure: return "Pressure"
        case .thinkingNeeded: return "Thinking needed"
        case .estimation: return "Estimation"
        case .image: return "Image"
        case .attachment: return "File attachment"
        case .tags: return "Tags"
        case .goals: return "Goals"
        case .events: return "Events"
        case .relationships: return "Relationships"
        case .scheduleType: return "Schedule behavior"
        case .steps: return "Steps"
        case .checklist: return "Checklist"
        case .place: return "Places"
        case .repeatPattern: return "Repeat"
        case .delete: return "Delete task"
        }
    }

    var iosAddDetailsSystemImage: String {
        switch self {
        case .name: return "text.cursor"
        case .taskType: return "repeat"
        case .taskDescription: return "text.alignleft"
        case .emoji: return "face.smiling"
        case .color: return "paintpalette"
        case .notes: return "note.text"
        case .voiceNote: return "waveform"
        case .link: return "link"
        case .planning: return "calendar.badge.clock"
        case .deadline: return "calendar.badge.exclamationmark"
        case .reminder: return "bell"
        case .importanceUrgency: return "square.grid.2x2"
        case .pressure: return "brain.head.profile"
        case .thinkingNeeded: return "lightbulb"
        case .estimation: return "timer"
        case .image: return "photo"
        case .attachment: return "paperclip"
        case .tags: return "tag"
        case .goals: return "target"
        case .events: return "calendar"
        case .relationships: return "point.3.connected.trianglepath.dotted"
        case .scheduleType: return "calendar.badge.clock"
        case .steps: return "list.number"
        case .checklist: return "checklist"
        case .place: return "mappin.and.ellipse"
        case .repeatPattern: return "repeat"
        case .delete: return "trash"
        }
    }
}

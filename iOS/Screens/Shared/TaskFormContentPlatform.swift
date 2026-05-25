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
    @State private var isShowingMoreDetails = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) private var showPersianDates = false

    var body: some View {
        Form {
            ForEach(model.visibleCompactSections(isShowingMoreDetails: isShowingMoreDetails), id: \.self) { section in
                compactSection(section)
            }

            if model.visibilityMode.usesProgressiveDisclosure {
                moreDetailsSection
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

    private var moreDetailsSection: some View {
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isShowingMoreDetails.toggle()
                }
            } label: {
                Label(
                    isShowingMoreDetails ? "Hide More Details" : "More Details",
                    systemImage: isShowingMoreDetails ? "chevron.up.circle" : "ellipsis.circle"
                )
            }
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

    @ViewBuilder
    private func compactSection(_ section: TaskFormCompactSection) -> some View {
        switch section {
        case .name:
            nameSection
        case .taskType:
            taskTypeSection
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
        case .deadline:
            if model.taskType.wrappedValue == .todo {
                deadlineSection
            }
        case .reminder:
            reminderSection
        case .importanceUrgency:
            importanceUrgencySection
        case .pressure:
            pressureSection
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
        case .relationships:
            relationshipsSection
        case .scheduleType:
            if model.scheduleMode.wrappedValue.taskType == .routine {
                scheduleTypeSection
            }
        case .stepsOrChecklist:
            if presentation.isStepBasedMode {
                stepsSection
            } else {
                checklistSection
            }
        case .place:
            placeSection
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
        TaskFormIOSLinkSection(model: model)
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

    private var estimationSection: some View {
        TaskFormIOSEstimationSection(model: model, presentation: presentation)
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
            presentation: presentation,
            tagColor: tagColor(for:)
        ) {
            isTagManagerPresented = true
        }
    }

    private var goalsSection: some View {
        TaskFormIOSGoalsSection(model: model, presentation: presentation)
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

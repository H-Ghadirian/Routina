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
        TaskFormIOSColorSection(model: model)
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
        Section(header: Text("Relationships")) {
            TaskRelationshipsEditor(
                relationships: model.relationships,
                candidates: model.availableRelationshipTasks,
                addRelationship: model.onAddRelationship,
                removeRelationship: model.onRemoveRelationship
            ) { searchText in
                TextField("Search tasks", text: searchText)
                    .routinaTaskRelationshipSearchFieldPlatform()
            }
            Text("Link this task to another task as related work or a blocker.")
                .font(.caption).foregroundStyle(.secondary)
        }
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

}

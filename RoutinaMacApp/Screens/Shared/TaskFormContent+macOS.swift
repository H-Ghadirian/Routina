import ComposableArchitecture
import PhotosUI
import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

struct TaskFormContent: View {
    let model: TaskFormModel

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isImageFileImporterPresented = false
    @State private var isFileImporterPresented = false
    @State private var isAttachmentDropTargeted = false
    @State private var isImageDropTargeted = false
    @State private var isTagManagerPresented = false
    @State private var tagManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    @Environment(\.addEditFormCoordinator) private var formCoordinator

    private var sectionCardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor)
    }

    private var sectionCardStroke: Color {
        Color.gray.opacity(0.18)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                formSections
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: formCoordinator.scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(target, anchor: .top)
                }
                formCoordinator.scrollTarget = nil
            }
        }
        .sheet(isPresented: $isTagManagerPresented) {
            SettingsTagManagerPresentationView(store: tagManagerStore)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            loadPickedImage(from: newItem)
        }
    }

    // MARK: - Form sections

    @ViewBuilder
    private var formSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            identityCard
            behaviorCard
            contextCard
            notesCard

            if isStepBasedMode {
                stepsCard
            }

            imageCard
            attachmentCard

            if model.onDelete != nil || model.pauseResumeAction != nil {
                dangerZoneCard
            }
        }
    }

    // MARK: Identity

    private var identityCard: some View {
        macSectionCard(
            title: "Identity",
            subtitle: "Start with the essentials so the task feels defined right away."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                if model.autofocusName {
                    livePreviewHeader
                }

                macControlBlock(title: "Task name") {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Task name", text: model.name)
                            .textFieldStyle(.roundedBorder)

                        if let msg = model.nameValidationMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                macControlBlock(title: "Emoji") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Text(model.emoji.wrappedValue)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.accentColor.opacity(0.16)))

                            Button("Choose Emoji") {
                                model.isEmojiPickerPresented.wrappedValue = true
                            }
                            .buttonStyle(.bordered)

                            Text("Quick picks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
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
        .id("Identity")
    }

    @ViewBuilder
    private var livePreviewHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(model.emoji.wrappedValue)
                .font(.system(size: 30))
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.accentColor.opacity(0.16)))

            VStack(alignment: .leading, spacing: 8) {
                Text(previewTitle)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)

                Text(previewSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let scheduleModeTitle = previewScheduleModeTitle {
                            macInfoPill(scheduleModeTitle, systemImage: "repeat")
                        }
                        macInfoPill(previewScheduleSummary, systemImage: "calendar")
                        macInfoPill(previewPlaceSummary, systemImage: "mappin.and.ellipse")
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: Behavior

    private var behaviorCard: some View {
        macSectionCard(
            title: "Behavior",
            subtitle: "Choose how this task repeats, where it appears, and when it is due."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                macControlBlock(title: "Type", caption: taskTypeDescription) {
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
                    macControlBlock(title: "Schedule style", caption: scheduleModeDescription) {
                        HStack(spacing: 0) {
                            Picker("Schedule Type", selection: model.scheduleMode) {
                                Text("Fixed").tag(RoutineScheduleMode.fixedInterval)
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
                        macControlBlock(title: "Checklist", caption: checklistSectionDescription) {
                            VStack(alignment: .leading, spacing: 12) {
                                checklistItemComposer
                                checklistItemsContent
                            }
                        }
                    }
                }

                if showsRepeatControls {
                    macControlBlock(title: "Repeat pattern", caption: recurrencePatternDescription) {
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
                        macControlBlock(
                            title: "Repeat",
                            caption: stepperLabel(
                                frequencyUnit: model.frequencyUnit.wrappedValue,
                                frequencyValue: model.frequencyValue.wrappedValue
                            )
                        ) {
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
                        macControlBlock(title: "Time", caption: "Due every day at a specific time.") {
                            DatePicker(
                                "Time",
                                selection: model.recurrenceTimeOfDay,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                        }

                    case .weekly:
                        macControlBlock(
                            title: "Weekday",
                            caption: "Due every \(weekdayName(for: model.recurrenceWeekday.wrappedValue))."
                        ) {
                            Picker("Weekday", selection: model.recurrenceWeekday) {
                                ForEach(weekdayOptions, id: \.id) { option in
                                    Text(option.name).tag(option.id)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                    case .monthlyDay:
                        macControlBlock(
                            title: "Month day",
                            caption: "Due on the \(ordinalDay(model.recurrenceDayOfMonth.wrappedValue)) of each month."
                        ) {
                            Stepper(value: model.recurrenceDayOfMonth, in: 1...31) {
                                Text(ordinalDay(model.recurrenceDayOfMonth.wrappedValue))
                                    .frame(minWidth: 40, alignment: .leading)
                            }
                            .fixedSize()
                        }
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    macControlBlock(title: "Place", caption: placeSelectionDescription) {
                        Picker("Place", selection: model.selectedPlaceID) {
                            Text("Anywhere").tag(Optional<UUID>.none)
                            ForEach(model.availablePlaces) { place in
                                Text(place.name).tag(Optional(place.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if model.taskType.wrappedValue == .todo {
                        macControlBlock(
                            title: "Deadline",
                            caption: model.deadlineEnabled.wrappedValue
                                ? "This todo will use the selected due date."
                                : "Leave this off until the task has a real deadline."
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("Set deadline", isOn: model.deadlineEnabled)
                                if model.deadlineEnabled.wrappedValue {
                                    DatePicker("Deadline", selection: model.deadline)
                                        .labelsHidden()
                                }
                            }
                        }
                        .frame(width: 320, alignment: .leading)
                    }
                }

                macControlBlock(title: "Importance & Urgency", caption: importanceUrgencyDescription) {
                    ImportanceUrgencyMatrixPicker(
                        importance: model.importance,
                        urgency: model.urgency
                    )
                    .frame(maxWidth: 420, alignment: .leading)
                }
            }
        }
        .id("Behavior")
    }

    // MARK: Context

    private var contextCard: some View {
        macSectionCard(
            title: "Context",
            subtitle: "Keep supporting metadata lightweight and easy to scan."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                macControlBlock(title: "Tags", caption: tagSectionHelpText) {
                    VStack(alignment: .leading, spacing: 10) {
                        tagComposer
                        tagsContent
                        availableTagSuggestionsContent
                        manageTagsButton
                    }
                }

                macControlBlock(
                    title: "Linked tasks",
                    caption: "Link this task to another task as related work or a blocker."
                ) {
                    TaskRelationshipsEditor(
                        relationships: model.relationships,
                        candidates: model.availableRelationshipTasks,
                        addRelationship: model.onAddRelationship,
                        removeRelationship: model.onRemoveRelationship
                    )
                }

                macControlBlock(
                    title: "Open link",
                    caption: "Add a website to open from the task detail screen. If you skip the scheme, https will be used."
                ) {
                    TextField("https://example.com", text: model.link)
                        .textFieldStyle(.roundedBorder)
                        .routinaAddRoutinePlatformLinkField()
                }
            }
        }
        .id("Context")
    }

    // MARK: Notes

    private var notesCard: some View {
        macSectionCard(
            title: "Notes",
            subtitle: model.taskType.wrappedValue == .todo
                ? "Capture extra context, links, or reminders for this todo."
                : "Add any details you want to keep with this routine."
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
        .id("Notes")
    }

    // MARK: Steps

    private var stepsCard: some View {
        macSectionCard(title: "Steps", subtitle: stepsSectionDescription) {
            VStack(alignment: .leading, spacing: 12) {
                stepComposer
                stepsContent
            }
        }
        .id("Steps")
    }

    // MARK: Image

    private var imageCard: some View {
        macSectionCard(
            title: "Image",
            subtitle: "Optional artwork or reference material for this task."
        ) {
            imageAttachmentContent
        }
        .id("Image")
    }

    // MARK: Attachment

    private var attachmentCard: some View {
        macSectionCard(
            title: "File Attachment",
            subtitle: "Attach a file up to 20 MB to keep reference material with this task."
        ) {
            attachmentContent
        }
        .id("Attachment")
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
        .id("Danger Zone")
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var tagComposer: some View {
        HStack(spacing: 10) {
            TextField("health, focus, morning", text: model.tagDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.onAddTag() }

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
    private var availableTagSuggestionsContent: some View {
        if !model.availableTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose from existing tags")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(model.availableTags, id: \.self) { tag in
                        let isSelected = RoutineTag.contains(tag, in: model.routineTags)
                        Button { model.onToggleTagSelection(tag) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.caption)
                                Text("#\(tag)").lineLimit(1)
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
                        .accessibilityLabel("\(isSelected ? "Remove" : "Add") tag \(tag)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
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
                    isImageFileImporterPresented = true
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
        .fileImporter(
            isPresented: $isImageFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result,
                  let imageURL = urls.first(where: { isSupportedImageFile($0) }) else { return }
            loadPickedImage(fromFileAt: imageURL)
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
        return mode == .fixedInterval || mode == .oneOff
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
        case .fixedIntervalChecklist: return "Use one overall repeat interval and complete every checklist item to finish the routine."
        case .derivedFromChecklist: return "Use checklist item due dates to decide when the routine is due."
        case .oneOff: return "This task does not repeat."
        }
    }

    private var checklistSectionDescription: String {
        switch model.scheduleMode.wrappedValue {
        case .fixedIntervalChecklist: return "The routine is done when every checklist item is completed."
        case .derivedFromChecklist: return "Each item gets its own due date. The routine becomes due when the earliest item is due."
        case .fixedInterval, .oneOff: return ""
        }
    }

    private var recurrencePatternDescription: String {
        switch model.recurrenceKind.wrappedValue {
        case .intervalDays: return "Repeat after a fixed number of days, weeks, or months."
        case .dailyTime: return "Repeat every day at a specific time."
        case .weekly: return "Repeat on the same weekday each week."
        case .monthlyDay: return "Repeat on the same calendar day each month."
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
        case .fixedIntervalChecklist: return "A routine you complete by finishing every checklist item."
        case .derivedFromChecklist: return "A routine driven by the due dates of its checklist items."
        case .oneOff: return "A one-off task you can finish once."
        }
    }

    private var previewScheduleModeTitle: String? {
        guard model.taskType.wrappedValue == .routine else { return nil }
        switch model.scheduleMode.wrappedValue {
        case .fixedInterval: return "Fixed"
        case .fixedIntervalChecklist: return "Checklist"
        case .derivedFromChecklist: return "Runout"
        case .oneOff: return nil
        }
    }

    private var previewScheduleSummary: String {
        if model.taskType.wrappedValue == .todo {
            return model.deadlineEnabled.wrappedValue
                ? "Due \(model.deadline.wrappedValue.formatted(date: .abbreviated, time: .omitted))"
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
            return "Every \(weekdayName(for: model.recurrenceWeekday.wrappedValue))"
        case .monthlyDay:
            return "Monthly on the \(ordinalDay(model.recurrenceDayOfMonth.wrappedValue))"
        }
    }

    private var previewPlaceSummary: String {
        guard let id = model.selectedPlaceID.wrappedValue,
              let place = model.availablePlaces.first(where: { $0.id == id }) else {
            return "Anywhere"
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

    private func loadAttachment(fromFileAt url: URL) {
        let maxSize = 20 * 1024 * 1024  // 20 MB
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url), data.count <= maxSize else { return }
        model.onAttachmentPicked(data, url.lastPathComponent)
    }
}

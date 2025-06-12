import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers

struct TaskDetailTCAView: View {
    let store: StoreOf<TaskDetailFeature>
    @Environment(\.dismiss) private var dismiss
    @State var displayedMonthStart = Calendar.current.startOfMonth(for: Date())
    @State var isShowingAllLogs = false
    @State var isEditEmojiPickerPresented = false
    @State var syncedMacOverviewHeight: CGFloat = 0
    @State var attachmentTempURL: URL?
    @State var fileToSave: AttachmentItem?
    @State private var isRelationshipGraphPresented = false
    let emojiOptions = EmojiCatalog.uniqueQuick
    let allEmojiOptions = EmojiCatalog.searchableAll

    var body: some View {
        WithPerceptionTracking {
            detailBody
            .routinaInlineTitleDisplayMode()
            .toolbar {
                if !isInlineEditPresented {
                    ToolbarItem(placement: .principal) {
                        Text(store.routineEmoji)
                            .font(TaskDetailPlatformStyle.principalTitleFont)
                    }
                }
                if isInlineEditPresented {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 8) {
                            Text("✏️")
                            Text("Edit Task")
                                .lineLimit(1)
                        }
                        .font(TaskDetailPlatformStyle.principalTitleFont)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                    }
                }
                if isInlineEditPresented {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            store.send(.setEditSheet(false))
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.send(.editSaveTapped)
                        }
                        .disabled(!canSaveCurrentEdit)
                    }
                } else {
                    ToolbarItemGroup(placement: .primaryAction) {
                        toolbarActionButtons
                        Button("Edit") {
                            store.send(.setEditSheet(true))
                        }
                    }
                }
            }
            .routinaPlatformEditPresentation(
                isPresented: editSheetBinding,
                store: store,
                isEditEmojiPickerPresented: $isEditEmojiPickerPresented,
                emojiOptions: emojiOptions,
                canSaveCurrentEdit: canSaveCurrentEdit
            )
            .sheet(isPresented: $isEditEmojiPickerPresented) {
                EmojiPickerSheet(
                    selectedEmoji: Binding(
                        get: { store.editRoutineEmoji },
                        set: { store.send(.editRoutineEmojiChanged($0)) }
                    ),
                    emojis: allEmojiOptions
                )
            }
            .sheet(isPresented: $isRelationshipGraphPresented) {
                TaskRelationshipGraphSheet(
                    centerTask: store.task,
                    relationships: store.resolvedRelationships,
                    statusColor: TaskDetailPresentation.statusColor(for:),
                    onSelectTask: { taskID in
                        isRelationshipGraphPresented = false
                        store.send(.openLinkedTask(taskID))
                    }
                )
            }
            .alert(
                "Delete routine?",
                isPresented: Binding(
                    get: { store.isDeleteConfirmationPresented },
                    set: { store.send(.setDeleteConfirmation($0)) }
                )
            ) {
                Button("Delete", role: .destructive) {
                    store.send(.deleteRoutineConfirmed)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently remove \(store.task.name ?? "this routine") and its logs.")
            }
            .onAppear {
                displayedMonthStart = Calendar.current.startOfMonth(for: store.resolvedSelectedDate)
            }
            .onChange(of: store.shouldDismissAfterDelete) { _, shouldDismiss in
                guard shouldDismiss else { return }
                dismiss()
                store.send(.deleteDismissHandled)
            }
            .onChange(of: store.resolvedSelectedDate) { _, newValue in
                displayedMonthStart = Calendar.current.startOfMonth(for: newValue)
            }
            .routinaAttachmentShareSheet(url: $attachmentTempURL)
            .fileExporter(
                isPresented: Binding(
                    get: { fileToSave != nil },
                    set: { if !$0 { fileToSave = nil } }
                ),
                document: fileToSave.map { RoutineAttachmentFileDocument(data: $0.data) },
                contentType: .data,
                defaultFilename: fileToSave?.fileName
            ) { _ in
                fileToSave = nil
            }
        }
    }

    @ViewBuilder
    private var detailBody: some View {
        if isInlineEditPresented {
            TaskDetailEditRoutineContent(
                store: store,
                isEditEmojiPickerPresented: $isEditEmojiPickerPresented,
                emojiOptions: emojiOptions
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if store.task.isOneOffTask {
            todoDetailContent
                .background { taskColorBackground }
        } else {
            taskDetailContent
                .background { taskColorBackground }
        }
    }

    @ViewBuilder
    private var taskColorBackground: some View {
        if let color = store.task.color.swiftUIColor {
            color.opacity(0.07).ignoresSafeArea()
        }
    }

    private var todoDetailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                todoHeaderSection
                if !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
                    calendarSection
                }
                if store.task.hasChecklistItems {
                    checklistItemsSection
                }
                relationshipsSection
                if store.task.hasNotes || store.task.hasImage || !store.taskAttachments.isEmpty || store.task.resolvedLinkURL != nil {
                    taskExtrasSection
                }
            }
            .padding(TaskDetailPlatformStyle.detailContentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var taskDetailContent: some View {
        let _ = store.taskRefreshID

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                routineHeaderSection
                calendarSection
                routineLogsSection
                if store.task.hasChecklistItems {
                    checklistItemsSection
                }
                relationshipsSection
                if store.task.hasNotes || store.task.hasImage || !store.taskAttachments.isEmpty || store.task.resolvedLinkURL != nil {
                    taskExtrasSection
                }
            }
            .padding(TaskDetailPlatformStyle.detailContentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var canSaveCurrentEdit: Bool {
        canSaveEdit(
            name: store.editRoutineName,
            emoji: store.editRoutineEmoji,
            notes: store.editRoutineNotes,
            link: store.editRoutineLink,
            deadline: store.editDeadline,
            priority: store.editPriority,
            importance: store.editImportance,
            urgency: store.editUrgency,
            color: store.editColor,
            imageData: store.editImageData,
            editAttachments: store.editAttachments,
            taskAttachments: store.taskAttachments,
            selectedPlaceID: store.editSelectedPlaceID,
            tags: store.editRoutineTags,
            relationships: store.editRelationships,
            tagDraft: store.editTagDraft,
            scheduleMode: store.editScheduleMode,
            steps: store.editRoutineSteps,
            stepDraft: store.editStepDraft,
            checklistItems: store.editRoutineChecklistItems,
            checklistItemDraftTitle: store.editChecklistItemDraftTitle,
            checklistItemDraftInterval: store.editChecklistItemDraftInterval,
            frequency: store.editFrequency,
            frequencyValue: store.editFrequencyValue,
            recurrenceKind: store.editRecurrenceKind,
            recurrenceTimeOfDay: store.editRecurrenceTimeOfDay,
            recurrenceWeekday: store.editRecurrenceWeekday,
            recurrenceDayOfMonth: store.editRecurrenceDayOfMonth,
            task: store.task
        )
    }

    var editSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isEditSheetPresented },
            set: { store.send(.setEditSheet($0)) }
        )
    }

    var isInlineEditPresented: Bool {
        platformIsInlineEditPresented
    }

    @ViewBuilder
    func detailOverviewSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        platformDetailOverviewSection(pauseArchivePresentation: pauseArchivePresentation)
    }

    var calendarSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            calendarHeader
                .padding(.bottom, 8)

            calendarGrid(
                doneDates: doneDates(from: store.logs),
                dueDate: store.resolvedDueDate,
                pausedAt: store.task.pausedAt,
                isOrangeUrgencyToday: TaskDetailPresentation.isOrangeUrgency(store.task),
                selectedDate: store.resolvedSelectedDate,
                onSelectDate: { store.send(.selectedDateChanged($0)) }
            )
            .padding(.bottom, 12)

            Spacer(minLength: 0)

            Divider()
                .padding(.bottom, 12)

            calendarLegend
        }
        .padding(12)
        .routinaPlatformCalendarCardStyle()
    }

    func heightReader(id: String) -> some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: TaskDetailOverviewHeightsPreferenceKey.self,
                    value: [id: proxy.size.height]
                )
        }
    }

    func compactStatusSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            statusSummaryHeader(titleFont: .title3.weight(.semibold))

            if hasVisibleStatusMetadata {
                Divider()
                statusMetadataSection(showSelectedDate: true)
                Divider()
            }

            statusActionSection(pauseArchivePresentation: pauseArchivePresentation)
        }
        .padding(16)
        .background(TaskDetailPlatformStyle.summaryCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(TaskDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
        )
    }

    private var todoHeaderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.task.name ?? "Task")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let statusContextMessage {
                    Text(statusContextMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                taskHeaderBadge(
                    title: "Status",
                    value: store.summaryStatusTitle,
                    tint: summaryStatusColor
                )

                taskHeaderBadge(
                    title: "Selected",
                    value: store.selectedDateMetadataText,
                    tint: .accentColor
                )
            }

            HStack(alignment: .top, spacing: 8) {
                if let priorityLabel = store.task.priority.metadataLabel {
                    taskHeaderBadge(
                        title: "Priority",
                        value: store.state.priorityMetadataText(priorityLabel: priorityLabel),
                        systemImage: "flag.fill",
                        tint: .secondary
                    )
                }

                if let linkedPlace = store.linkedPlaceSummary {
                    taskHeaderBadge(
                        title: "Location",
                        value: linkedPlace.name,
                        tint: .blue
                    )
                }
            }

            if let dueDateMetadataText = store.dueDateMetadataText {
                taskHeaderBadge(
                    title: "Due",
                    value: dueDateMetadataText,
                    tint: .orange
                )
            }

            if !store.task.tags.isEmpty {
                taskHeaderTagSection(tags: store.task.tags)
            }
        }
        .padding(16)
        .detailCardStyle(cornerRadius: 16)
    }

    private var routineHeaderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.task.name ?? "Routine")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let statusContextMessage {
                    Text(statusContextMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                taskHeaderBadge(
                    title: "Status",
                    value: store.summaryStatusTitle,
                    tint: summaryStatusColor
                )

                taskHeaderBadge(
                    title: "Frequency",
                    value: store.frequencyText,
                    tint: .mint
                )
            }

            HStack(alignment: .top, spacing: 8) {
                taskHeaderBadge(
                    title: "Completed",
                    value: store.completedLogCountText,
                    tint: .green
                )

                if store.canceledLogCount > 0 {
                    taskHeaderBadge(
                        title: "Canceled",
                        value: store.canceledLogCountText,
                        tint: .orange
                    )
                }

                if let dueDateMetadataText = store.dueDateMetadataText {
                    taskHeaderBadge(
                        title: "Due",
                        value: dueDateMetadataText,
                        tint: .orange
                    )
                } else if let linkedPlace = store.linkedPlaceSummary {
                    taskHeaderBadge(
                        title: "Location",
                        value: linkedPlace.name,
                        tint: .blue
                    )
                }
            }

            HStack(alignment: .top, spacing: 8) {
                if let priorityLabel = store.task.priority.metadataLabel {
                    taskHeaderBadge(
                        title: "Priority",
                        value: store.state.priorityMetadataText(priorityLabel: priorityLabel),
                        systemImage: "flag.fill",
                        tint: .secondary
                    )
                }

                if let linkedPlace = store.linkedPlaceSummary, store.dueDateMetadataText != nil {
                    taskHeaderBadge(
                        title: "Location",
                        value: linkedPlace.name,
                        tint: .blue
                    )
                }
            }

            if !store.task.tags.isEmpty {
                taskHeaderTagSection(tags: store.task.tags)
            }
        }
        .padding(16)
        .detailCardStyle(cornerRadius: 16)
    }

    private func taskHeaderBadge(
        title: String,
        value: String,
        systemImage: String? = nil,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                }

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
    }

    private func taskHeaderTagSection(tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TAGS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(tags, id: \.self) { tag in
                    statusTagChip(tag)
                }
            }
        }
    }

    @ViewBuilder
    private var toolbarActionButtons: some View {
        Button {
            store.send(store.completionButtonAction)
        } label: {
            completionButtonLabel
        }
        .buttonStyle(.borderedProminent)
        .tint(toolbarCompletionTint)
        .disabled(store.isCompletionButtonDisabled)

        if store.task.isOneOffTask && !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
            Button {
                store.send(.cancelTodo)
            }
            label: {
                Label(store.cancelTodoButtonTitle, systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(store.isCancelTodoButtonDisabled)
        }

        if !store.task.isOneOffTask {
            Button {
                store.send(store.task.isPaused ? .resumeTapped : .pauseTapped)
            }
            label: {
                Label(toolbarPauseActionTitle, systemImage: toolbarPauseSystemImage)
            }
            .buttonStyle(.bordered)
            .tint(toolbarPauseTint)
        }
    }

    private var todoPrimaryActionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            primaryActionButton
            cancelTodoButton

            if store.task.isCompletedOneOff || store.task.isCanceledOneOff {
                Text("Select the logged date in the calendar if you want to undo it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !store.blockingRelationships.isEmpty {
                Text(store.blockerSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .detailCardStyle()
    }

    private func routinePrimaryActionSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.summaryStatusTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(summaryStatusColor)

                if let statusContextMessage {
                    Text(statusContextMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            primaryActionButton

            Button(pauseArchivePresentation.actionTitle) {
                store.send(store.task.isPaused ? .resumeTapped : .pauseTapped)
            }
            .buttonStyle(.bordered)
            .tint(store.task.isPaused ? .teal : .orange)
            .routinaPlatformSecondaryActionControlSize()
            .frame(maxWidth: .infinity)

            if store.isStepRoutineOffToday {
                Text("Step-based routines can only be progressed for today.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if store.task.isChecklistCompletionRoutine && !store.canUndoSelectedDate {
                Text("Complete checklist items below to finish this routine.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let pauseDescription = pauseArchivePresentation.description {
                Text(pauseDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !store.blockingRelationships.isEmpty {
                Text(store.blockerSummaryText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .detailCardStyle()
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        Button {
            store.send(store.completionButtonAction)
        } label: {
            completionButtonLabel
                .routinaPlatformPrimaryActionLabelLayout()
        }
        .buttonStyle(.borderedProminent)
        .routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: true)
        .routinaPlatformPrimaryActionButtonLayout()
        .disabled(store.isCompletionButtonDisabled)
    }

    @ViewBuilder
    private var cancelTodoButton: some View {
        if store.task.isOneOffTask && !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
            Button {
                store.send(.cancelTodo)
            } label: {
                Label(store.cancelTodoButtonTitle, systemImage: "xmark.circle")
                    .routinaPlatformPrimaryActionLabelLayout()
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: true)
            .routinaPlatformPrimaryActionButtonLayout()
            .disabled(store.isCancelTodoButtonDisabled)
        }
    }

    private var taskExtrasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            if let imageData = store.task.imageData {
                Button {
                    openTaskImage(data: imageData)
                } label: {
                    TaskImageView(data: imageData)
                        .frame(maxWidth: .infinity, maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .help("Open image in another app")
            }
            ForEach(store.taskAttachments) { item in
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(Color.accentColor)
                    Text(item.fileName)
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        saveAttachment(item: item)
                    } label: {
                        Image(systemName: "arrow.down.doc")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Save to Files")
                    Button {
                        openAttachment(data: item.data, fileName: item.fileName)
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open with…")
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if let notes = store.task.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let linkURL = store.task.resolvedLinkURL {
                Link(destination: linkURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .foregroundStyle(.blue)
                        Text(store.task.link ?? linkURL.absoluteString)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .background(routineLogsBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(TaskDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
        )
    }

    func macStatusSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            statusSummaryHeader(titleFont: .title2.weight(.semibold))

            if hasVisibleStatusMetadata {
                Divider()
                statusMetadataSection(showSelectedDate: true)
                Divider()
            }

            statusActionSection(pauseArchivePresentation: pauseArchivePresentation, useLargePrimaryControl: true)
        }
        .padding(18)
    }

    private func statusSummaryHeader(titleFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.summaryStatusTitle)
                .font(titleFont)
                .foregroundColor(summaryStatusColor)

            if let statusContextMessage {
                Text(statusContextMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statusMetadataSection(showSelectedDate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !store.task.isOneOffTask {
                statusMetadataRow(label: "Frequency", value: store.frequencyText)
            }

            if shouldShowCompletionCount {
                statusMetadataRow(label: "Completed", value: store.completedLogCountText)
            }

            if store.canceledLogCount > 0 {
                statusMetadataRow(label: "Canceled", value: store.canceledLogCountText, systemImage: "xmark.circle")
            }

            if let pausedAt = store.task.pausedAt {
                statusMetadataRow(
                    label: "Paused",
                    value: pausedAt.formatted(date: .abbreviated, time: .omitted)
                )
            } else if let dueDateMetadataText = store.dueDateMetadataText {
                statusMetadataRow(label: "Due", value: dueDateMetadataText)
            }

            if showSelectedDate && store.shouldShowSelectedDateMetadata {
                statusMetadataRow(label: "Selected", value: store.selectedDateMetadataText)
            }

            if store.task.hasImage || !store.taskAttachments.isEmpty {
                let fileCount = store.taskAttachments.count
                let parts: [String] = [
                    store.task.hasImage ? "1 image" : nil,
                    fileCount > 0 ? "\(fileCount) \(fileCount == 1 ? "file" : "files")" : nil
                ].compactMap { $0 }
                statusMetadataRow(label: "Attachment", value: parts.joined(separator: ", "), systemImage: "paperclip")
            }

            if store.task.isChecklistDriven {
                statusMetadataRow(
                    label: "Checklist",
                    value: "\(store.task.checklistItems.count) \(store.task.checklistItems.count == 1 ? "item" : "items")"
                )
                if let nextDueChecklistItemTitle = store.task.nextDueChecklistItem(referenceDate: Date())?.title {
                    statusMetadataRow(label: "Next Due", value: nextDueChecklistItemTitle)
                }
            } else if store.task.isChecklistCompletionRoutine {
                statusMetadataRow(
                    label: "Checklist",
                    value: "\(store.task.totalChecklistItemCount) \(store.task.totalChecklistItemCount == 1 ? "item" : "items")"
                )
                statusMetadataRow(label: "Progress", value: store.checklistProgressText)
                if let nextPendingChecklistItemTitle = store.task.nextPendingChecklistItemTitle {
                    statusMetadataRow(label: "Next Item", value: nextPendingChecklistItemTitle)
                }
            } else if store.task.hasSequentialSteps {
                statusMetadataRow(label: "Progress", value: store.stepProgressText)
                if let nextStepTitle = store.task.nextStepTitle {
                    statusMetadataRow(label: "Next Step", value: nextStepTitle)
                }
            }
        }
    }

    private func statusActionSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation,
        useLargePrimaryControl: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                store.send(store.completionButtonAction)
            } label: {
                completionButtonLabel
                    .routinaPlatformPrimaryActionLabelLayout()
            }
            .buttonStyle(.borderedProminent)
            .routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: useLargePrimaryControl)
            .routinaPlatformPrimaryActionButtonLayout(alignment: .leading)
            .disabled(store.isCompletionButtonDisabled)

            if !store.task.isOneOffTask {
                Button(pauseArchivePresentation.actionTitle) {
                    store.send(store.task.isPaused ? .resumeTapped : .pauseTapped)
                }
                .buttonStyle(.bordered)
                .tint(store.task.isPaused ? .teal : .orange)
                .routinaPlatformSecondaryActionControlSize()
                .routinaPlatformSecondaryActionButtonLayout(alignment: .leading)
            }

            if store.isStepRoutineOffToday {
                Text("Step-based routines can only be progressed for today.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if store.task.isChecklistCompletionRoutine && !store.canUndoSelectedDate {
                Text("Complete checklist items below to finish this routine.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let pauseDescription = pauseArchivePresentation.description {
                Text(pauseDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !store.blockingRelationships.isEmpty {
                Text(store.blockerSummaryText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statusMetadataRow(
        label: String,
        value: String,
        systemImage: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statusTagChip(_ tag: String) -> some View {
        Text("#\(tag)")
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
            )
    }

    private var statusContextMessage: String? {
        if store.task.isPaused {
            return "Resume it anytime to put it back in rotation."
        }
        if store.task.isOneOffTask {
            if store.task.isCompletedOneOff || store.task.isCanceledOneOff {
                return "Select the logged date to undo it if needed."
            }
            return nil
        }
        if Calendar.current.isDateInToday(store.resolvedSelectedDate) {
            return "Today is selected. Pick another date to review its history."
        }
        return "Reviewing \(store.resolvedSelectedDate.formatted(date: .abbreviated, time: .omitted))."
    }

    private var shouldShowCompletionCount: Bool {
        if store.task.isOneOffTask {
            return store.completedLogCount > 0 || store.canceledLogCount > 0
        }
        return true
    }

    private var hasVisibleStatusMetadata: Bool {
        !store.task.isOneOffTask
            || shouldShowCompletionCount
            || store.linkedPlaceSummary != nil
            || store.task.pausedAt != nil
            || store.dueDateMetadataText != nil
            || store.shouldShowSelectedDateMetadata
            || !store.task.tags.isEmpty
            || store.task.hasImage
            || !store.taskAttachments.isEmpty
            || store.task.isChecklistDriven
            || store.task.isChecklistCompletionRoutine
            || store.task.hasSequentialSteps
    }

    private var routineLogsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Routine Logs")
                .font(.headline)

            if store.logs.isEmpty {
                Text("No logs yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                let logs = displayedLogs(from: store.logs)
                ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                    HStack(spacing: 8) {
                        Text(log.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(log.kind == .completed ? "Done" : "Canceled")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(log.kind == .completed ? .green : .orange)
                    }
                    .padding(.vertical, 8)

                    if index < logs.count - 1 {
                        Divider()
                    }
                }

                if store.logs.count > 3 {
                    Button(isShowingAllLogs ? "Show less" : "See all (\(store.logs.count))") {
                        isShowingAllLogs.toggle()
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(routineLogsBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(TaskDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
        )
    }

    private var relationshipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Linked Tasks")
                    .font(.headline)

                Spacer(minLength: 0)

                Button {
                    isRelationshipGraphPresented = true
                } label: {
                    Label("Visualize", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.resolvedRelationships.isEmpty)
            }

            ForEach(store.groupedResolvedRelationships, id: \.kind) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Label(group.kind.title, systemImage: group.kind.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, relationship in
                        Button {
                            store.send(.openLinkedTask(relationship.taskID))
                        } label: {
                            HStack(spacing: 12) {
                                Text(relationship.taskEmoji)
                                    .font(.title3)
                                    .overlay(alignment: .topLeading) {
                                        if group.items.count > 1 {
                                            Text("\(index + 1)")
                                                .fixedSize()
                                                .font(.caption2.monospacedDigit().weight(.semibold))
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(.ultraThinMaterial, in: Capsule())
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                                )
                                                .offset(x: -10, y: -8)
                                        }
                                    }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(relationship.taskName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)

                                    if relationship.status != .onTrack {
                                        Label(relationship.status.title, systemImage: relationship.status.systemImage)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(TaskDetailPresentation.statusColor(for: relationship.status))
                                    }
                                }

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        if index < group.items.count - 1 {
                            Divider()
                        }
                    }
                }

                Divider()
            }

            HStack(spacing: 8) {
                Picker(
                    "",
                    selection: Binding(
                        get: { store.addLinkedTaskRelationshipKind },
                        set: { store.send(.addLinkedTaskRelationshipKindChanged($0)) }
                    )
                ) {
                    ForEach(RoutineTaskRelationshipKind.allCases, id: \.self) { kind in
                        Label(kind.title, systemImage: kind.systemImage).tag(kind)
                    }
                }
                .labelsHidden()
                .fixedSize()

                Button {
                    store.send(.openAddLinkedTask)
                } label: {
                    Label("Add Linked Task", systemImage: "plus")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .background(routineLogsBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(TaskDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
        )
    }

    private var checklistItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Checklist Items")
                .font(.headline)

            if store.task.checklistItems.isEmpty {
                Text("No checklist items yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(sortedChecklistItems, id: \.id) { item in
                    checklistRow(for: item)

                    if item.id != sortedChecklistItems.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(12)
        .background(routineLogsBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(TaskDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
        )
    }

    private var summaryStatusColor: Color {
        TaskDetailPresentation.summaryTitleColor(
            pausedAt: store.task.pausedAt,
            isDoneToday: store.isDoneToday,
            overdueDays: store.overdueDays,
            task: store.task
        )
    }

    @ViewBuilder
    private var completionButtonLabel: some View {
        if let systemImage = store.completionButtonSystemImage {
            Label(store.completionButtonTitle, systemImage: systemImage)
        } else {
            Text(store.completionButtonTitle)
        }
    }

    private var toolbarCompletionTint: Color {
        store.canUndoSelectedDate ? .orange : .green
    }

    private var toolbarPauseActionTitle: String {
        store.task.isPaused ? "Resume" : "Pause"
    }

    private var toolbarPauseSystemImage: String {
        store.task.isPaused ? "play.fill" : "pause.fill"
    }

    private var toolbarPauseTint: Color {
        store.task.isPaused ? .teal : .orange
    }

    private var calendarHeader: some View {
        HStack {
            Button {
                displayedMonthStart = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonthStart) ?? displayedMonthStart
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(displayedMonthStart.formatted(.dateTime.month(.wide).year()))
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button {
                displayedMonthStart = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonthStart) ?? displayedMonthStart
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var calendarLegend: some View {
        HStack(spacing: 12) {
            legendItem(color: .green, label: "Done")
            legendItem(color: .red, label: "Overdue")
            if store.task.pausedAt != nil {
                legendItem(color: .teal, label: "Paused")
            }
            HStack(spacing: 4) {
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 10, height: 10)
                Text("Today")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var routineLogsBackground: Color {
        TaskDetailPlatformStyle.routineLogsBackground
    }

    private func calendarGrid(
        doneDates: Set<Date>,
        dueDate: Date?,
        pausedAt: Date?,
        isOrangeUrgencyToday: Bool,
        selectedDate: Date,
        onSelectDate: @escaping (Date) -> Void
    ) -> some View {
        let calendar = Calendar.current
        let start = displayedMonthStart
        let days = calendar.daysInMonthGrid(for: start)
        let weekdaySymbols = calendar.orderedShortStandaloneWeekdaySymbols

        return VStack(spacing: 6) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        calendarDayCell(
                            day: day,
                            doneDates: doneDates,
                            dueDate: dueDate,
                            pausedAt: pausedAt,
                            isOrangeUrgencyToday: isOrangeUrgencyToday,
                            isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                            onSelectDate: onSelectDate
                        )
                    } else {
                        Color.clear
                            .frame(height: 28)
                    }
                }
            }
        }
    }

    private func calendarDayCell(
        day: Date,
        doneDates: Set<Date>,
        dueDate: Date?,
        pausedAt: Date?,
        isOrangeUrgencyToday: Bool,
        isSelected: Bool,
        onSelectDate: @escaping (Date) -> Void
    ) -> some View {
        let calendar = Calendar.current
        let isDueDate = dueDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isDoneDate = doneDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isToday = calendar.isDateInToday(day)
        let isDueToTodayRangeDate = isInDueToTodayRange(day: day, dueDate: dueDate)
        let isPausedDate = isInPausedRange(day: day, pausedAt: pausedAt)

        let backgroundColor: Color = {
            if isDoneDate { return .green }
            if isPausedDate { return .teal }
            if isDueToTodayRangeDate || isDueDate { return .red }
            if isToday && isOrangeUrgencyToday { return .orange }
            if isToday { return .blue }
            return .clear
        }()

        let foregroundColor: Color = (isDueDate || isDoneDate || isDueToTodayRangeDate || isPausedDate || isToday) ? .white : .primary

        return Button {
            onSelectDate(day)
        } label: {
            Text(day.formatted(.dateTime.day()))
                .font(.subheadline)
                .foregroundColor(foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(Circle().fill(backgroundColor))
                .overlay(
                    Circle()
                        .stroke(
                            TaskDetailPresentation.selectionStrokeColor(
                                isSelected: isSelected,
                                isToday: isToday,
                                isHighlightedDay: isDoneDate || isDueToTodayRangeDate || isDueDate || isPausedDate
                            ),
                            lineWidth: isSelected ? 3 : 2
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func doneDates(from logs: [RoutineLog]) -> Set<Date> {
        let calendar = Calendar.current
        return Set(logs.compactMap { $0.timestamp }.map { calendar.startOfDay(for: $0) })
    }

    private func isInDueToTodayRange(day: Date, dueDate: Date?) -> Bool {
        guard let dueDate else { return false }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let dueStart = calendar.startOfDay(for: dueDate)
        let todayStart = calendar.startOfDay(for: Date())

        guard dueStart <= todayStart else { return false }
        return dayStart >= dueStart && dayStart <= todayStart
    }

    private func isInPausedRange(day: Date, pausedAt: Date?) -> Bool {
        guard let pausedAt else { return false }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let pausedStart = calendar.startOfDay(for: pausedAt)
        let todayStart = calendar.startOfDay(for: Date())
        return dayStart >= pausedStart && dayStart <= todayStart
    }

    private func displayedLogs(from logs: [RoutineLog]) -> [RoutineLog] {
        if isShowingAllLogs { return logs }
        return Array(logs.prefix(3))
    }


    private var sortedChecklistItems: [RoutineChecklistItem] {
        if store.task.isChecklistCompletionRoutine {
            return store.task.checklistItems
        }
        return store.task.checklistItems.sorted {
            RoutineDateMath.dueDate(for: $0, referenceDate: Date())
                < RoutineDateMath.dueDate(for: $1, referenceDate: Date())
        }
    }

    @ViewBuilder
    private func checklistRow(for item: RoutineChecklistItem) -> some View {
        if store.task.isChecklistCompletionRoutine {
            completionChecklistRow(for: item)
        } else {
            dueChecklistRow(for: item)
        }
    }

    private func completionChecklistRow(for item: RoutineChecklistItem) -> some View {
        let isDone = store.state.isChecklistItemMarkedDone(item)
        let isInteractive = canToggleChecklistItem(item)

        return Button {
            store.send(.toggleChecklistItemCompletion(item.id))
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isDone ? .green : TaskDetailPresentation.checklistCompletionControlColor(isInteractive: isInteractive))
                    .frame(width: 24, height: 24)

                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDone ? .secondary : .primary)
                    .strikethrough(isDone, color: .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .accessibilityLabel(item.title)
        .accessibilityValue(isDone ? "Completed" : "Not completed")
    }

    private func dueChecklistRow(for item: RoutineChecklistItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text(checklistStatusText(for: item))
                    .font(.caption)
                    .foregroundStyle(TaskDetailPresentation.checklistStatusColor(for: item, task: store.task, isMarkedDone: store.state.isChecklistItemMarkedDone(item)))
            }

            Spacer(minLength: 0)

            Button("Bought") {
                store.send(.markChecklistItemPurchased(item.id))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(store.task.isPaused || !Calendar.current.isDateInToday(store.resolvedSelectedDate))
        }
    }

    private func checklistStatusText(for item: RoutineChecklistItem) -> String {
        if store.task.isChecklistCompletionRoutine {
            return store.state.isChecklistItemMarkedDone(item) ? "Done" : "Pending"
        }
        let calendar = Calendar.current
        let dueDate = RoutineDateMath.dueDate(for: item, referenceDate: Date(), calendar: calendar)
        let daysUntilDue = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? 0

        if daysUntilDue < 0 {
            return "Overdue by \(abs(daysUntilDue)) \(dayWord(abs(daysUntilDue)))"
        }
        if daysUntilDue == 0 {
            return "Due today"
        }
        if daysUntilDue == 1 {
            return "Due tomorrow"
        }
        return "Due in \(daysUntilDue) days"
    }

    private func canSaveEdit(
        name: String,
        emoji: String,
        notes: String,
        link: String,
        deadline: Date?,
        priority: RoutineTaskPriority,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        color: RoutineTaskColor,
        imageData: Data?,
        editAttachments: [AttachmentItem],
        taskAttachments: [AttachmentItem],
        selectedPlaceID: UUID?,
        tags: [String],
        relationships: [RoutineTaskRelationship],
        tagDraft: String,
        scheduleMode: RoutineScheduleMode,
        steps: [RoutineStep],
        stepDraft: String,
        checklistItems: [RoutineChecklistItem],
        checklistItemDraftTitle: String,
        checklistItemDraftInterval: Int,
        frequency: TaskDetailFeature.EditFrequency,
        frequencyValue: Int,
        recurrenceKind: RoutineRecurrenceRule.Kind,
        recurrenceTimeOfDay: RoutineTimeOfDay,
        recurrenceWeekday: Int,
        recurrenceDayOfMonth: Int,
        task: RoutineTask
    ) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        let currentName = (task.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let currentEmoji = task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨"
        let currentNotes = task.notes ?? ""
        let currentLink = task.link ?? ""
        let currentPriority = task.priority
        let currentImportance = task.importance
        let currentUrgency = task.urgency
        let currentTags = RoutineTag.deduplicated(task.tags)
        let currentRelationships = RoutineTaskRelationship.sanitized(task.relationships, ownerID: task.id)
        let currentDeadline = task.scheduleMode == .oneOff ? task.deadline : nil
        let currentImageData = task.imageData
        let candidateTags = RoutineTag.appending(tagDraft, to: tags)
        let candidateRelationships = RoutineTaskRelationship.sanitized(relationships, ownerID: task.id)
        let currentSteps = RoutineStep.sanitized(task.steps)
        let candidateSteps = RoutineStep.normalizedTitle(stepDraft).map { title in
            steps + [RoutineStep(title: title)]
        } ?? steps
        let currentChecklistItems = RoutineChecklistItem.sanitized(task.checklistItems)
        let candidateChecklistItems = RoutineChecklistItem.normalizedTitle(checklistItemDraftTitle).map { title in
            checklistItems + [RoutineChecklistItem(title: title, intervalDays: checklistItemDraftInterval)]
        } ?? checklistItems
        let currentRecurrenceRule = task.recurrenceRule
        let newRecurrenceRule: RoutineRecurrenceRule
        switch recurrenceKind {
        case .intervalDays:
            newRecurrenceRule = .interval(days: frequencyValue * frequency.daysMultiplier)
        case .dailyTime:
            newRecurrenceRule = .daily(at: recurrenceTimeOfDay)
        case .weekly:
            newRecurrenceRule = .weekly(on: recurrenceWeekday)
        case .monthlyDay:
            newRecurrenceRule = .monthly(on: recurrenceDayOfMonth)
        }
        let sanitizedCandidateChecklistItems = RoutineChecklistItem.sanitized(candidateChecklistItems)

        guard scheduleMode == .fixedInterval || scheduleMode == .oneOff || !sanitizedCandidateChecklistItems.isEmpty else {
            return false
        }

        return trimmedName != currentName
            || emoji != currentEmoji
            || notes != currentNotes
            || link != currentLink
            || deadline != currentDeadline
            || priority != currentPriority
            || importance != currentImportance
            || urgency != currentUrgency
            || color != task.color
            || imageData != currentImageData
            || editAttachments != taskAttachments
            || selectedPlaceID != task.placeID
            || candidateTags != currentTags
            || candidateRelationships != currentRelationships
            || scheduleMode != task.scheduleMode
            || RoutineStep.sanitized(candidateSteps) != currentSteps
            || sanitizedCandidateChecklistItems != currentChecklistItems
            || newRecurrenceRule != currentRecurrenceRule
    }

    private func canToggleChecklistItem(_ item: RoutineChecklistItem) -> Bool {
        guard store.task.isChecklistCompletionRoutine,
              !store.task.isPaused,
              Calendar.current.isDateInToday(store.resolvedSelectedDate) else {
            return false
        }

        if store.isDoneToday && !store.task.isChecklistInProgress {
            return false
        }

        if store.task.isChecklistItemCompleted(item.id) {
            return store.task.isChecklistInProgress
        }

        return true
    }

    private func dayWord(_ count: Int) -> String {
        abs(count) == 1 ? "day" : "days"
    }

    // MARK: - Attachment actions

    func saveAttachment(item: AttachmentItem) {
        fileToSave = item
    }

    func openAttachment(data: Data, fileName: String) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoutineAttachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent(fileName)
        try? data.write(to: fileURL)
        platformOpenAttachment(url: fileURL)
    }

    func openTaskImage(data: Data) {
        let fileName = taskImageFileName(for: store.task, data: data)
        openAttachment(data: data, fileName: fileName)
    }

    func taskImageFileName(for task: RoutineTask, data: Data) -> String {
        let baseName = sanitizedAttachmentBaseName(task.name ?? "Routine Image")
        let fileExtension = detectedImageFileExtension(for: data)
        return "\(baseName).\(fileExtension)"
    }

    func sanitizedAttachmentBaseName(_ rawValue: String) -> String {
        let sanitizedScalars = rawValue.unicodeScalars.map { scalar -> String in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "-"
        }
        let sanitized = sanitizedScalars.joined()
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return sanitized.isEmpty ? "attachment" : sanitized
    }

    func detectedImageFileExtension(for data: Data) -> String {
        if data.range(of: Data("ftypheic".utf8)) != nil || data.range(of: Data("ftypheix".utf8)) != nil {
            return "heic"
        }

        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }

        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }

        if data.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return "gif"
        }

        if data.starts(with: [0x42, 0x4D]) {
            return "bmp"
        }

        if data.starts(with: [0x52, 0x49, 0x46, 0x46]),
           data.dropFirst(8).starts(with: [0x57, 0x45, 0x42, 0x50]) {
            return "webp"
        }

        if data.starts(with: [0x00, 0x00, 0x01, 0x00]) {
            return "ico"
        }

        if data.starts(with: [0x49, 0x49, 0x2A, 0x00]) || data.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) {
            return "tiff"
        }

        return "png"
    }

}

private extension Calendar {
    var orderedShortStandaloneWeekdaySymbols: [String] {
        let symbols = shortStandaloneWeekdaySymbols
        let startIndex = firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }

    func daysInMonthGrid(for monthStart: Date) -> [Date?] {
        guard
            let monthRange = range(of: .day, in: .month, for: monthStart),
            let monthInterval = dateInterval(of: .month, for: monthStart)
        else { return [] }

        let firstDay = monthInterval.start
        let firstWeekday = component(.weekday, from: firstDay)
        let leadingEmptyDays = (firstWeekday - self.firstWeekday + 7) % 7

        var result: [Date?] = Array(repeating: nil, count: leadingEmptyDays)
        for day in monthRange {
            if let date = date(byAdding: .day, value: day - 1, to: firstDay) {
                result.append(date)
            }
        }
        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }
}

private extension View {
    func detailCardStyle(cornerRadius: CGFloat = 12) -> some View {
        background(TaskDetailPlatformStyle.summaryCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(TaskDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
            )
    }
}

struct RoutineAttachmentFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct TaskDetailOverviewHeightsPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}


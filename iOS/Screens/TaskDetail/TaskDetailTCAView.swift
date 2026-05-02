import SwiftUI
import ComposableArchitecture
import SwiftData
import UniformTypeIdentifiers

struct TaskDetailTCAView: View {
    let store: StoreOf<TaskDetailFeature>
    @Dependency(\.appSettingsClient) private var appSettingsClient
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var focusSessions: [FocusSession]
    @Query private var focusSessionTasks: [RoutineTask]
    @State var displayedMonthStart = Calendar.current.startOfMonth(for: Date())
    @State var isShowingAllLogs = false
    @State private var isRoutineLogsExpanded = true
    @State private var isTaskChangesExpanded = true
    @State private var editingTimeLog: RoutineLog?
    @State private var editingTimeSpentMinutes = 25
    @State private var isEditingTaskTimeSpent = false
    @State var isEditEmojiPickerPresented = false
    @State var syncedMacOverviewHeight: CGFloat = 0
    @State var attachmentTempURL: URL?
    @State var fileToSave: AttachmentItem?
    @State private var isCloudSharingPresented = false
    @State private var isRelationshipGraphPresented = false
    @State private var isMatrixExpanded = false
    @State private var isTodoStatePickerPresented = false
    @State private var isPressurePickerPresented = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) private var showPersianDates = false
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
                        Button {
                            isCloudSharingPresented = true
                        } label: {
                            Label("Share", systemImage: "person.crop.circle.badge.plus")
                        }
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
            .sheet(item: $editingTimeLog) { log in
                NavigationStack {
                    Form {
                        Section("Actual Time") {
                            Stepper(value: $editingTimeSpentMinutes, in: 1...1440) {
                                HStack {
                                    Text("Time spent")
                                    Spacer()
                                    Text(RoutineTimeSpentFormatting.compactMinutesText(editingTimeSpentMinutes))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if log.actualDurationMinutes != nil {
                            Section {
                                Button(role: .destructive) {
                                    store.send(.updateLogDuration(log.id, nil))
                                    editingTimeLog = nil
                                } label: {
                                    Label("Clear Time Spent", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .navigationTitle("Time Spent")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                editingTimeLog = nil
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                store.send(.updateLogDuration(log.id, editingTimeSpentMinutes))
                                editingTimeLog = nil
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $isEditingTaskTimeSpent) {
                NavigationStack {
                    Form {
                        Section("Actual Time") {
                            Stepper(value: $editingTimeSpentMinutes, in: 1...1440) {
                                HStack {
                                    Text("Time spent")
                                    Spacer()
                                    Text(RoutineTimeSpentFormatting.compactMinutesText(editingTimeSpentMinutes))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if store.task.actualDurationMinutes != nil {
                            Section {
                                Button(role: .destructive) {
                                    store.send(.updateTaskDuration(nil))
                                    isEditingTaskTimeSpent = false
                                } label: {
                                    Label("Clear Time Spent", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .navigationTitle("Time Spent")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isEditingTaskTimeSpent = false
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                store.send(.updateTaskDuration(editingTimeSpentMinutes))
                                isEditingTaskTimeSpent = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
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
            .alert(
                store.pendingLogRemovalTimestamp == nil ? "Undo log?" : "Remove log?",
                isPresented: Binding(
                    get: { store.isUndoCompletionConfirmationPresented },
                    set: { store.send(.setUndoCompletionConfirmation($0)) }
                )
            ) {
                Button(store.pendingLogRemovalTimestamp == nil ? "Undo" : "Remove", role: .destructive) {
                    store.send(.confirmUndoCompletion)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if store.pendingLogRemovalTimestamp == nil {
                    Text("This will remove the selected completion log and may update the routine's schedule.")
                } else {
                    Text("This will permanently remove this routine log and may update the routine's schedule.")
                }
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
            .routinaCloudSharingSheet(
                isPresented: $isCloudSharingPresented,
                task: store.task
            )
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
                notificationDisabledWarningSection
                if !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
                    calendarSection
                }
                todoPrimaryActionSection
                todoStateTimingSection
                if store.task.focusModeEnabled {
                    focusSessionSection
                }
                routineLogsSection
                taskChangesSection
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
        let pauseArchivePresentation = RoutinePauseArchivePresentation.make(
            isPaused: store.task.isArchived(),
            context: .detail
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                routineHeaderSection
                notificationDisabledWarningSection
                routinePrimaryActionSection(pauseArchivePresentation: pauseArchivePresentation)
                calendarSection
                if store.task.focusModeEnabled {
                    focusSessionSection
                }
                routineLogsSection
                taskChangesSection
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

    private var focusSessionSection: some View {
        FocusSessionCard(
            task: store.task,
            sessions: focusSessions,
            allTasks: focusSessionTasks
        )
    }

    private var canSaveCurrentEdit: Bool {
        canSaveEdit(
            name: store.editRoutineName,
            emoji: store.editRoutineEmoji,
            notes: store.editRoutineNotes,
            link: store.editRoutineLink,
            estimatedDurationMinutes: store.editEstimatedDurationMinutes,
            storyPoints: store.editStoryPoints,
            deadline: store.editDeadline,
            reminderAt: store.editReminderAt,
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
            recurrenceHasExplicitTime: store.editRecurrenceHasExplicitTime,
            recurrenceTimeOfDay: store.editRecurrenceTimeOfDay,
            recurrenceWeekday: store.editRecurrenceWeekday,
            recurrenceDayOfMonth: store.editRecurrenceDayOfMonth,
            autoAssumeDailyDone: store.editAutoAssumeDailyDone,
            focusModeEnabled: store.editFocusModeEnabled,
            pressure: store.editPressure,
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
                doneDates: doneDates(from: store.logs, task: store.task),
                assumedDates: assumedDates(from: store.logs, task: store.task),
                dueDate: store.resolvedDueDate,
                createdAt: store.task.createdAt,
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
        TaskDetailHeaderSectionView(
            title: store.task.name ?? "Task",
            statusContextMessage: statusContextMessage,
            badgeRows: todoHeaderBadgeRows,
            tags: store.task.tags
        ) { tag in
            statusTagChip(tag)
        } additionalContent: {
            VStack(alignment: .leading, spacing: 8) {
                priorityDisclosureBox
                todoTimeSpentHeaderBox
            }
        }
    }

    @ViewBuilder
    private var todoStateTimingSection: some View {
        if let summary = TodoStateTiming.summary(
            for: store.task,
            referenceDate: Date(),
            calendar: Calendar.current
        ) {
            TodoStateTimingSectionView(
                summary: summary,
                showPersianDates: showPersianDates
            )
        }
    }

    private var routineHeaderSection: some View {
        TaskDetailHeaderSectionView(
            title: store.task.name ?? "Routine",
            statusContextMessage: statusContextMessage,
            badgeRows: routineHeaderBadgeRows,
            tags: store.task.tags
        ) { tag in
            statusTagChip(tag)
        } additionalContent: {
            priorityDisclosureBox
        }
    }

    private var todoTimeSpentHeaderBox: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TIME SPENT")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(store.task.actualDurationMinutes.map(estimatedDurationBadgeValue(for:)) ?? "Not logged")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(store.task.actualDurationMinutes == nil ? .secondary : .primary)
            }

            Spacer(minLength: 8)

            Button {
                beginEditingTaskTime()
            } label: {
                Label(
                    store.task.actualDurationMinutes == nil ? "Add Time" : "Edit Time",
                    systemImage: "clock.badge"
                )
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .detailHeaderBoxStyle(tint: .cyan)
    }

    private var priorityDisclosureBox: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isMatrixExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PRIORITY")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        prioritySummaryRow
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isMatrixExpanded ? 180 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isMatrixExpanded {
                Divider()
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                ImportanceUrgencyMatrixPicker(
                    importance: Binding(
                        get: { store.task.importance },
                        set: { store.send(.importanceChanged($0)) }
                    ),
                    urgency: Binding(
                        get: { store.task.urgency },
                        set: { store.send(.urgencyChanged($0)) }
                    ),
                    showsSummaryChip: false
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .detailHeaderBoxStyle()
    }

    private var prioritySummaryRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 8) {
                priorityFlagChip
                priorityMetadataChip(
                    title: "Importance",
                    value: store.task.importance.title,
                    tint: importanceTint(for: store.task.importance)
                )
                priorityMetadataChip(
                    title: "Urgency",
                    value: store.task.urgency.title,
                    tint: urgencyTint(for: store.task.urgency)
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                priorityFlagChip
                HStack(alignment: .center, spacing: 8) {
                    priorityMetadataChip(
                        title: "Importance",
                        value: store.task.importance.title,
                        tint: importanceTint(for: store.task.importance)
                    )
                    priorityMetadataChip(
                        title: "Urgency",
                        value: store.task.urgency.title,
                        tint: urgencyTint(for: store.task.urgency)
                    )
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var priorityFlagChip: some View {
        Label(store.task.priority.title, systemImage: "flag.fill")
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(prioritySummaryColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(prioritySummaryColor.opacity(0.12), in: Capsule())
    }

    private func priorityMetadataChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.10), in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var prioritySummaryColor: Color {
        switch store.task.priority {
        case .none:
            return .secondary
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .urgent:
            return .red
        }
    }

    private func importanceTint(for importance: RoutineTaskImportance) -> Color {
        switch importance {
        case .level1:
            return .green
        case .level2:
            return .yellow
        case .level3:
            return .orange
        case .level4:
            return .red
        }
    }

    private func urgencyTint(for urgency: RoutineTaskUrgency) -> Color {
        switch urgency {
        case .level1:
            return .green
        case .level2:
            return .yellow
        case .level3:
            return .orange
        case .level4:
            return .red
        }
    }

    @ViewBuilder
    private var notificationDisabledWarningSection: some View {
        if let warningText = store.notificationDisabledWarningText,
           let actionTitle = store.notificationDisabledWarningActionTitle {
            Button {
                store.send(.notificationDisabledWarningTapped)
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "bell.slash.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No notification will fire")
                            .font(.subheadline.weight(.semibold))
                        Text(warningText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(actionTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange.opacity(0.8))
                }
            }
            .buttonStyle(.plain)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.orange.opacity(0.25), lineWidth: 1)
            )
        }
    }

    private var todoHeaderBadgeRows: [[TaskDetailHeaderBadgeItem]] {
        var rows: [[TaskDetailHeaderBadgeItem]] = [
            [
                TaskDetailHeaderBadgeItem(
                    title: "Status",
                    value: store.summaryStatusTitle,
                    systemImage: nil,
                    tint: summaryStatusColor
                ),
                TaskDetailHeaderBadgeItem(
                    title: "Selected",
                    value: store.selectedDateMetadataText,
                    systemImage: nil,
                    tint: .accentColor
                )
            ]
        ]

        var secondRow: [TaskDetailHeaderBadgeItem] = []
        if let linkedPlace = store.linkedPlaceSummary {
            secondRow.append(
                TaskDetailHeaderBadgeItem(
                    title: "Location",
                    value: linkedPlace.name,
                    systemImage: nil,
                    tint: .blue
                )
            )
        }
        if !secondRow.isEmpty {
            rows.append(secondRow)
        }

        if let dueDateMetadataText = dueDateMetadataDisplayText {
            rows.append([
                TaskDetailHeaderBadgeItem(
                    title: "Due",
                    value: dueDateMetadataText,
                    systemImage: nil,
                    tint: .orange
                )
            ])
        }

        if let reminderMetadataText = store.reminderMetadataText {
            rows.append([
                TaskDetailHeaderBadgeItem(
                    title: "Reminder",
                    value: reminderMetadataText,
                    systemImage: "bell.fill",
                    tint: .indigo
                )
            ])
        }

        if !estimationHeaderBadges.isEmpty {
            rows.append(estimationHeaderBadges)
        }

        return rows
    }

    private var routineHeaderBadgeRows: [[TaskDetailHeaderBadgeItem]] {
        var rows: [[TaskDetailHeaderBadgeItem]] = [
            [
                TaskDetailHeaderBadgeItem(
                    title: "Status",
                    value: store.summaryStatusTitle,
                    systemImage: nil,
                    tint: summaryStatusColor
                ),
                TaskDetailHeaderBadgeItem(
                    title: "Frequency",
                    value: store.frequencyText,
                    systemImage: nil,
                    tint: .mint
                )
            ]
        ]

        if let dueDateMetadataText = dueDateMetadataDisplayText {
            rows.append([
                TaskDetailHeaderBadgeItem(
                    title: "Due",
                    value: dueDateMetadataText,
                    systemImage: nil,
                    tint: .orange
                )
            ])
        }

        var completedLocationRow: [TaskDetailHeaderBadgeItem] = []
        if let linkedPlace = store.linkedPlaceSummary {
            completedLocationRow.append(
                TaskDetailHeaderBadgeItem(
                    title: "Location",
                    value: linkedPlace.name,
                    systemImage: nil,
                    tint: .blue
                )
            )
        }
        completedLocationRow.append(
            TaskDetailHeaderBadgeItem(
                title: "Completed",
                value: store.completedLogCountText,
                systemImage: nil,
                tint: .green
            )
        )
        rows.append(completedLocationRow)

        if store.canceledLogCount > 0 {
            rows.append([
                TaskDetailHeaderBadgeItem(
                    title: "Canceled",
                    value: store.canceledLogCountText,
                    systemImage: nil,
                    tint: .orange
                )
            ])
        }

        if let reminderMetadataText = store.reminderMetadataText {
            rows.append([
                TaskDetailHeaderBadgeItem(
                    title: "Reminder",
                    value: reminderMetadataText,
                    systemImage: "bell.fill",
                    tint: .indigo
                )
            ])
        }

        if !estimationHeaderBadges.isEmpty {
            rows.append(estimationHeaderBadges)
        }

        return rows
    }

    private var estimationHeaderBadges: [TaskDetailHeaderBadgeItem] {
        var badges: [TaskDetailHeaderBadgeItem] = []

        if let estimatedDurationMinutes = store.task.estimatedDurationMinutes {
            badges.append(
                TaskDetailHeaderBadgeItem(
                    title: "Estimate",
                    value: estimatedDurationBadgeValue(for: estimatedDurationMinutes),
                    systemImage: nil,
                    tint: .teal
                )
            )
        }

        if displayedActualDurationMinutes > 0 {
            badges.append(
                TaskDetailHeaderBadgeItem(
                    title: "Spent",
                    value: estimatedDurationBadgeValue(for: displayedActualDurationMinutes),
                    systemImage: "clock.fill",
                    tint: .cyan
                )
            )
        }

        if let storyPoints = store.task.storyPoints {
            badges.append(
                TaskDetailHeaderBadgeItem(
                    title: "Points",
                    value: storyPointsBadgeValue(for: storyPoints),
                    systemImage: nil,
                    tint: .purple
                )
            )
        }

        return badges
    }

    private var totalLoggedActualDurationMinutes: Int {
        store.logs.reduce(0) { partialResult, log in
            partialResult + (log.kind == .completed ? (log.actualDurationMinutes ?? 0) : 0)
        }
    }

    private var displayedActualDurationMinutes: Int {
        store.task.isOneOffTask ? (store.task.actualDurationMinutes ?? 0) : totalLoggedActualDurationMinutes
    }

    private var latestCompletedLog: RoutineLog? {
        store.logs
            .filter { $0.kind == .completed }
            .max { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
    }

    private func estimatedDurationBadgeValue(for minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        switch (hours, remainingMinutes) {
        case (0, let minutes):
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        case (let hours, 0):
            return hours == 1 ? "1 hour" : "\(hours) hours"
        case (let hours, let minutes):
            let hourText = hours == 1 ? "1 hour" : "\(hours) hours"
            let minuteText = minutes == 1 ? "1 minute" : "\(minutes) minutes"
            return "\(hourText) \(minuteText)"
        }
    }

    private func storyPointsBadgeValue(for points: Int) -> String {
        points == 1 ? "1 story point" : "\(points) story points"
    }

    private var todoPrimaryActionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        todoStatePickerPill
                        pressurePickerPill
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        todoStatePickerPill
                        pressurePickerPill
                    }
                }
            } else {
                pressurePickerPill
            }
            primaryActionButton
            cancelTodoButton

            if !store.task.isCompletedOneOff && !store.task.isCanceledOneOff && !store.blockingRelationships.isEmpty {
                Text(store.blockerSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .detailCardStyle()
    }

    private var pressurePickerPill: some View {
        let pressure = store.task.pressure
        return Button {
            isPressurePickerPresented = true
        } label: {
            Label("Pressure: \(pressure.title)", systemImage: pressurePillSystemImage(pressure))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(pressurePillColor(pressure))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(pressurePillColor(pressure).opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .confirmationDialog("Set Pressure", isPresented: $isPressurePickerPresented) {
            ForEach(RoutineTaskPressure.allCases, id: \.self) { option in
                if option != pressure {
                    Button(option.title) {
                        store.send(.pressureChanged(option))
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Current: \(pressure.title)")
        }
    }

    private var todoStatePickerPill: some View {
        let currentState = store.task.todoState ?? .ready
        return Button {
            isTodoStatePickerPresented = true
        } label: {
            Label(currentState.displayTitle, systemImage: currentState.systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(todoStatePillColor(currentState))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(todoStatePillColor(currentState).opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .confirmationDialog("Set State", isPresented: $isTodoStatePickerPresented) {
            ForEach(TodoState.allCases, id: \.self) { state in
                if state != currentState {
                    Button(state.displayTitle) {
                        if state == .done && store.hasActiveRelationshipBlocker {
                            store.send(.setBlockedStateConfirmation(true))
                        } else {
                            store.send(.todoStateChanged(state))
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Current: \(currentState.displayTitle)")
        }
        .alert(
            "Blocked Task",
            isPresented: Binding(
                get: { store.isBlockedStateConfirmationPresented },
                set: { store.send(.setBlockedStateConfirmation($0)) }
            )
        ) {
            Button("Mark Done Anyway", role: .destructive) {
                store.send(.confirmBlockedStateCompletion)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(store.blockerSummaryText)
        }
    }

    private func todoStatePillColor(_ state: TodoState) -> Color {
        switch state {
        case .ready: return .secondary
        case .inProgress: return .blue
        case .blocked: return .orange
        case .done: return .green
        case .paused: return .purple
        }
    }

    private func pressurePillColor(_ pressure: RoutineTaskPressure) -> Color {
        switch pressure {
        case .none: return .secondary
        case .low: return .teal
        case .medium: return .orange
        case .high: return .red
        }
    }

    private func pressurePillSystemImage(_ pressure: RoutineTaskPressure) -> String {
        switch pressure {
        case .none: return "circle"
        case .low: return "circle.lefthalf.filled"
        case .medium: return "circle.fill"
        case .high: return "exclamationmark.circle.fill"
        }
    }

    private func routinePrimaryActionSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            pressurePickerPill

            primaryActionButton

            if store.shouldShowBulkConfirmAssumedDays {
                Button(store.bulkConfirmAssumedDaysTitle) {
                    store.send(.confirmAssumedPastDays)
                }
                .buttonStyle(.bordered)
                .tint(.mint)
                .routinaPlatformSecondaryActionControlSize()
                .frame(maxWidth: .infinity)
            }

            routineSecondaryActionControls(pauseArchivePresentation: pauseArchivePresentation)

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

            if let secondaryActionDescription = pauseArchivePresentation.secondaryActionDescription {
                Text(secondaryActionDescription)
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

    private func routineSecondaryActionControls(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                routinePauseResumeButton(pauseArchivePresentation: pauseArchivePresentation)
                routineNotTodayButton(pauseArchivePresentation: pauseArchivePresentation)
                routineStartOngoingButton
            }

            VStack(alignment: .leading, spacing: 10) {
                routinePauseResumeButton(pauseArchivePresentation: pauseArchivePresentation)
                routineNotTodayButton(pauseArchivePresentation: pauseArchivePresentation)
                routineStartOngoingButton
            }
        }
    }

    private func routinePauseResumeButton(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        Button {
            store.send(store.task.isArchived() ? .resumeTapped : .pauseTapped)
        } label: {
            Label(
                pauseArchivePresentation.actionTitle,
                systemImage: store.task.isArchived() ? "play.circle" : "pause.circle"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(store.task.isArchived() ? .teal : .orange)
        .routinaPlatformSecondaryActionControlSize()
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func routineNotTodayButton(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        if let secondaryActionTitle = pauseArchivePresentation.secondaryActionTitle {
            Button {
                store.send(.notTodayTapped)
            } label: {
                Label(secondaryActionTitle, systemImage: "moon.zzz.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.indigo)
            .routinaPlatformSecondaryActionControlSize()
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var routineStartOngoingButton: some View {
        if store.task.isSoftIntervalRoutine && !store.task.isOngoing && !store.task.isArchived() {
            Button {
                store.send(.startOngoingTapped)
            } label: {
                Label("Start ongoing", systemImage: "play.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.teal)
            .routinaPlatformSecondaryActionControlSize()
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var timeSpentActionButton: some View {
        if store.task.isOneOffTask {
            Button {
                beginEditingTaskTime()
            } label: {
                Label(
                    store.task.actualDurationMinutes == nil ? "Add Time Spent" : "Edit Time Spent",
                    systemImage: "clock.badge"
                )
                .routinaPlatformPrimaryActionLabelLayout()
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
            .routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: false)
            .routinaPlatformPrimaryActionButtonLayout()
        } else if let log = latestCompletedLog {
            Button {
                beginEditingTime(for: log)
            } label: {
                Label(
                    log.actualDurationMinutes == nil ? "Add Time Spent" : "Edit Time Spent",
                    systemImage: "clock.badge"
                )
                .routinaPlatformPrimaryActionLabelLayout()
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
            .routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: false)
            .routinaPlatformPrimaryActionButtonLayout()
        }
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
                TaskImageView(data: imageData)
                    .frame(maxWidth: .infinity, maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

            if let notes = CalendarTaskImportSupport.displayNotes(from: store.task.notes) {
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

            if displayedActualDurationMinutes > 0 {
                statusMetadataRow(
                    label: "Time Spent",
                    value: estimatedDurationBadgeValue(for: displayedActualDurationMinutes),
                    systemImage: "clock"
                )
            }

            if store.canceledLogCount > 0 {
                statusMetadataRow(label: "Canceled", value: store.canceledLogCountText, systemImage: "xmark.circle")
            }

            if let pausedAt = store.task.pausedAt {
                statusMetadataRow(
                    label: "Paused",
                    value: pausedAt.formatted(date: .abbreviated, time: .omitted)
                )
            } else if let dueDateMetadataText = dueDateMetadataDisplayText {
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

            timeSpentActionButton

            if !store.task.isOneOffTask {
                Button(pauseArchivePresentation.actionTitle) {
                    store.send(store.task.isArchived() ? .resumeTapped : .pauseTapped)
                }
                .buttonStyle(.bordered)
                .tint(store.task.isArchived() ? .teal : .orange)
                .routinaPlatformSecondaryActionControlSize()
                .routinaPlatformSecondaryActionButtonLayout(alignment: .leading)

                if let secondaryActionTitle = pauseArchivePresentation.secondaryActionTitle {
                    Button(secondaryActionTitle) {
                        store.send(.notTodayTapped)
                    }
                    .buttonStyle(.bordered)
                    .tint(.indigo)
                    .routinaPlatformSecondaryActionControlSize()
                    .routinaPlatformSecondaryActionButtonLayout(alignment: .leading)
                }
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

            if let secondaryActionDescription = pauseArchivePresentation.secondaryActionDescription {
                Text(secondaryActionDescription)
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
        let tint = Color(routineTagHex: RoutineTagColors.colorHex(for: tag, in: appSettingsClient.tagColors()))
            ?? Color.accentColor

        return Text("#\(tag)")
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
    }

    private var statusContextMessage: String? {
        if store.task.isArchived() {
            return "Resume it anytime to put it back in rotation."
        }
        if store.task.isOneOffTask {
            if store.task.isCompletedOneOff || store.task.isCanceledOneOff {
                return nil
            }
            return nil
        }
        if store.isSelectedDateAssumedDone {
            if Calendar.current.isDateInToday(store.resolvedSelectedDate) {
                return "Today is assumed done. Confirm it to count it in your history, or use Not Today if plans changed."
            }
            return "This day is assumed done. Confirm it to count it in stats and history."
        }
        if Calendar.current.isDateInToday(store.resolvedSelectedDate) {
            return nil
        }
        let dateText = PersianDateDisplay.appendingSupplementaryDate(
            to: store.resolvedSelectedDate.formatted(date: .abbreviated, time: .omitted),
            for: store.resolvedSelectedDate,
            enabled: showPersianDates
        )
        return "Reviewing \(dateText)."
    }

    private var dueDateMetadataDisplayText: String? {
        guard let dueDateMetadataText = store.dueDateMetadataText else { return nil }
        guard let dueDate = store.resolvedDueDate else { return dueDateMetadataText }
        return PersianDateDisplay.appendingSupplementaryDate(
            to: dueDateMetadataText,
            for: dueDate,
            enabled: showPersianDates
        )
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
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isRoutineLogsExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Routine Logs")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(store.logs.count.formatted())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12), in: Capsule())

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isRoutineLogsExpanded ? 180 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let createdAtBadgeValue = store.state.createdAtBadgeValue {
                Label("Created \(createdAtBadgeValue)", systemImage: "calendar.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isRoutineLogsExpanded {
                if store.logs.isEmpty {
                    Text("No logs yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    let logs = displayedLogs(from: store.logs)
                    ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                        RoutineLogSwipeRow(
                            timestampText: logTimestampText(log.timestamp),
                            timeSpentText: logTimeSpentText(log),
                            statusText: log.kind == .completed ? "Done" : "Canceled",
                            statusColor: log.kind == .completed ? .green : .orange,
                            actionTitle: routineLogActionTitle(for: log),
                            actionColor: log.kind == .completed ? .green : .orange,
                            isActionEnabled: log.timestamp != nil
                        ) {
                            if let timestamp = log.timestamp {
                                store.send(.requestRemoveLogEntry(timestamp))
                            }
                        } editTimeAction: {
                            beginEditingTime(for: log)
                        }

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
        }
        .padding(12)
        .background(routineLogsBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(TaskDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
        )
    }

    private func routineLogActionTitle(for log: RoutineLog) -> String {
        log.kind == .completed ? "Undo" : "Remove"
    }

    private func logTimestampText(_ timestamp: Date?) -> String {
        guard let timestamp else { return "Unknown date" }
        return PersianDateDisplay.appendingSupplementaryDate(
            to: timestamp.formatted(date: .abbreviated, time: .shortened),
            for: timestamp,
            enabled: showPersianDates
        )
    }

    private func logTimeSpentText(_ log: RoutineLog) -> String {
        guard let duration = log.actualDurationMinutes else { return "Add time" }
        return RoutineTimeSpentFormatting.compactMinutesText(duration)
    }

    private func beginEditingTime(for log: RoutineLog) {
        editingTimeSpentMinutes = log.actualDurationMinutes ?? store.task.estimatedDurationMinutes ?? 25
        editingTimeLog = log
    }

    private func beginEditingTaskTime() {
        editingTimeSpentMinutes = store.task.actualDurationMinutes ?? store.task.estimatedDurationMinutes ?? 25
        isEditingTaskTimeSpent = true
    }

    private var taskChangesSection: some View {
        let changes = store.task.changeLogEntries
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTaskChangesExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Task Changes")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(changes.count.formatted())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12), in: Capsule())

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isTaskChangesExpanded ? 180 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isTaskChangesExpanded {
                if changes.isEmpty {
                    Text("No changes yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(changes.prefix(12).enumerated()), id: \.element.id) { index, change in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: taskChangeSystemImage(change))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 18, height: 18)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(taskChangeTitle(change))
                                    .font(.subheadline.weight(.medium))
                                Text(logTimestampText(change.timestamp))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 7)

                        if index < min(changes.count, 12) - 1 {
                            Divider()
                        }
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

    private func taskChangeTitle(_ change: RoutineTaskChangeLogEntry) -> String {
        switch change.kind {
        case .created:
            return "Task created"
        case .stateChanged:
            return "State changed from \(change.previousValue ?? "Unknown") to \(change.newValue ?? "Unknown")"
        case .linkedTaskAdded:
            return "Linked \(relatedTaskName(for: change)) as \(change.relationshipKind?.title ?? "Related")"
        case .linkedTaskRemoved:
            return "Removed link to \(relatedTaskName(for: change))"
        case .timeSpentAdded:
            return "Added \(durationText(for: change.durationMinutes ?? change.newValue.flatMap(Int.init))) time spent"
        case .timeSpentChanged:
            return "Changed time spent to \(durationText(for: change.durationMinutes ?? change.newValue.flatMap(Int.init)))"
        case .timeSpentRemoved:
            return "Removed time spent"
        }
    }

    private func taskChangeSystemImage(_ change: RoutineTaskChangeLogEntry) -> String {
        switch change.kind {
        case .created:
            return "plus.circle"
        case .stateChanged:
            return "arrow.triangle.2.circlepath"
        case .linkedTaskAdded:
            return "link.badge.plus"
        case .linkedTaskRemoved:
            return "link.badge.minus"
        case .timeSpentAdded, .timeSpentChanged, .timeSpentRemoved:
            return "clock"
        }
    }

    private func relatedTaskName(for change: RoutineTaskChangeLogEntry) -> String {
        guard let relatedTaskID = change.relatedTaskID else { return "task" }
        return focusSessionTasks.first(where: { $0.id == relatedTaskID })?.name ?? "task"
    }

    private func durationText(for minutes: Int?) -> String {
        guard let minutes else { return "time" }
        return RoutineTimeSpentFormatting.compactMinutesText(minutes)
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
            isAssumedDoneToday: store.isAssumedDoneToday,
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
            if store.task.createdAt != nil {
                legendItem(color: .purple, label: "Created")
            }
            legendItem(color: .green, label: "Done")
            if store.task.autoAssumeDailyDone {
                legendItem(color: .mint, label: "Assumed")
            }
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
        assumedDates: Set<Date>,
        dueDate: Date?,
        createdAt: Date?,
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
                            assumedDates: assumedDates,
                            dueDate: dueDate,
                            createdAt: createdAt,
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
        assumedDates: Set<Date>,
        dueDate: Date?,
        createdAt: Date?,
        pausedAt: Date?,
        isOrangeUrgencyToday: Bool,
        isSelected: Bool,
        onSelectDate: @escaping (Date) -> Void
    ) -> some View {
        let calendar = Calendar.current
        let isDueDate = dueDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isCreatedDate = createdAt.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isDoneDate = doneDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isAssumedDate = !isDoneDate && assumedDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isToday = calendar.isDateInToday(day)
        let isDueToTodayRangeDate = isInDueToTodayRange(day: day, dueDate: dueDate)
        let isPausedDate = isInPausedRange(day: day, pausedAt: pausedAt)

        let backgroundColor: Color = {
            if isDoneDate { return .green }
            if isAssumedDate { return .mint }
            if isPausedDate { return .teal }
            if isDueToTodayRangeDate || isDueDate { return .red }
            if isCreatedDate { return .purple }
            if isToday && isOrangeUrgencyToday { return .orange }
            if isToday { return .blue }
            return .clear
        }()

        let foregroundColor: Color = (isDueDate || isDoneDate || isAssumedDate || isDueToTodayRangeDate || isPausedDate || isCreatedDate || isToday) ? .white : .primary

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
                                isHighlightedDay: isDoneDate || isAssumedDate || isDueToTodayRangeDate || isDueDate || isPausedDate || isCreatedDate
                            ),
                            lineWidth: isSelected ? 3 : 2
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func doneDates(from logs: [RoutineLog], task: RoutineTask) -> Set<Date> {
        let calendar = Calendar.current
        var dates = Set<Date>(logs.compactMap { log in
            guard let timestamp = log.timestamp, log.kind == .completed else { return nil }
            return RoutineDateMath.completionDisplayDay(for: task, completionDate: timestamp, calendar: calendar)
        })
        if let lastDone = task.lastDone {
            if let displayDay = RoutineDateMath.completionDisplayDay(
                for: task,
                completionDate: lastDone,
                calendar: calendar
            ) {
                dates.insert(displayDay)
            }
        }
        return dates
    }

    private func assumedDates(from logs: [RoutineLog], task: RoutineTask) -> Set<Date> {
        let calendar = Calendar.current
        return Set(
            RoutineAssumedCompletion.assumedDates(for: task, logs: logs)
                .map { calendar.startOfDay(for: $0) }
        )
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
            .disabled(store.task.isArchived() || !Calendar.current.isDateInToday(store.resolvedSelectedDate))
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
        estimatedDurationMinutes: Int?,
        storyPoints: Int?,
        deadline: Date?,
        reminderAt: Date?,
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
        recurrenceHasExplicitTime: Bool,
        recurrenceTimeOfDay: RoutineTimeOfDay,
        recurrenceWeekday: Int,
        recurrenceDayOfMonth: Int,
        autoAssumeDailyDone: Bool,
        focusModeEnabled: Bool,
        pressure: RoutineTaskPressure,
        task: RoutineTask
    ) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        let currentName = (task.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let currentEmoji = CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "✨"
        let currentNotes = CalendarTaskImportSupport.displayNotes(from: task.notes) ?? ""
        let currentLink = task.link ?? ""
        let currentPriority = task.priority
        let currentImportance = task.importance
        let currentUrgency = task.urgency
        let currentTags = RoutineTag.deduplicated(task.tags)
        let currentRelationships = RoutineTaskRelationship.sanitized(task.relationships, ownerID: task.id)
        let currentDeadline = task.scheduleMode == .oneOff ? task.deadline : nil
        let currentReminderAt = task.reminderAt
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
            newRecurrenceRule = .weekly(
                on: recurrenceWeekday,
                at: recurrenceHasExplicitTime ? recurrenceTimeOfDay : nil
            )
        case .monthlyDay:
            newRecurrenceRule = .monthly(
                on: recurrenceDayOfMonth,
                at: recurrenceHasExplicitTime ? recurrenceTimeOfDay : nil
            )
        }
        let sanitizedCandidateChecklistItems = RoutineChecklistItem.sanitized(candidateChecklistItems)

        guard scheduleMode == .fixedInterval || scheduleMode == .softInterval || scheduleMode == .oneOff || !sanitizedCandidateChecklistItems.isEmpty else {
            return false
        }

        return trimmedName != currentName
            || emoji != currentEmoji
            || notes != currentNotes
            || link != currentLink
            || estimatedDurationMinutes != task.estimatedDurationMinutes
            || storyPoints != task.storyPoints
            || deadline != currentDeadline
            || reminderAt != currentReminderAt
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
            || autoAssumeDailyDone != task.autoAssumeDailyDone
            || focusModeEnabled != task.focusModeEnabled
            || pressure != task.pressure
    }

    private func canToggleChecklistItem(_ item: RoutineChecklistItem) -> Bool {
        guard store.task.isChecklistCompletionRoutine,
              !store.task.isArchived(),
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

extension View {
    func detailCardStyle(cornerRadius: CGFloat = 12) -> some View {
        background(TaskDetailPlatformStyle.summaryCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(TaskDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
            )
    }
}

private struct RoutineLogSwipeRow: View {
    private let actionWidth: CGFloat = 88
    private let fullSwipeThreshold: CGFloat = 132

    let timestampText: String
    let timeSpentText: String
    let statusText: String
    let statusColor: Color
    let actionTitle: String
    let actionColor: Color
    let isActionEnabled: Bool
    let action: () -> Void
    let editTimeAction: () -> Void

    @State private var restingOffset: CGFloat = 0
    @GestureState private var dragTranslation: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            if isActionEnabled {
                Button(actionTitle) {
                    performAction()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: actionWidth)
                .frame(maxHeight: .infinity)
                .background(actionColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.vertical, 6)
            }

            rowContent
                .background(TaskDetailPlatformStyle.summaryCardBackground)
                .offset(x: currentOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(swipeGesture)
                .animation(.snappy(duration: 0.18), value: restingOffset)
        }
        .clipped()
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(timestampText)
                    .font(.subheadline)

                Button {
                    editTimeAction()
                } label: {
                    Label(timeSpentText, systemImage: "clock")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 8)
    }

    private var currentOffset: CGFloat {
        guard isActionEnabled else { return 0 }
        return min(0, max(-actionWidth, restingOffset + dragTranslation))
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragTranslation) { value, state, _ in
                guard isHorizontalSwipe(value) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard isHorizontalSwipe(value) else { return }
                let translation = value.translation.width
                let predictedTranslation = value.predictedEndTranslation.width

                if translation <= -fullSwipeThreshold || predictedTranslation <= -fullSwipeThreshold {
                    performAction()
                } else {
                    let finalOffset = min(0, max(-actionWidth, restingOffset + translation))
                    restingOffset = finalOffset <= -(actionWidth / 2) ? -actionWidth : 0
                }
            }
    }

    private func isHorizontalSwipe(_ value: DragGesture.Value) -> Bool {
        isActionEnabled && abs(value.translation.width) > abs(value.translation.height)
    }

    private func performAction() {
        restingOffset = 0
        action()
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

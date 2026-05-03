import SwiftUI
import ComposableArchitecture
import SwiftData

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
        TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: store.state))
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
        TaskDetailCalendarSectionView(
            displayedMonthStart: displayedMonthStart,
            onPreviousMonth: {
                displayedMonthStart = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonthStart) ?? displayedMonthStart
            },
            onNextMonth: {
                displayedMonthStart = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonthStart) ?? displayedMonthStart
            },
            showsAssumedLegend: store.task.autoAssumeDailyDone,
            showsPausedLegend: store.task.pausedAt != nil,
            showsCreatedLegend: store.task.createdAt != nil
        ) {
            TaskDetailCalendarGridView(
                displayedMonthStart: displayedMonthStart,
                doneDates: TaskDetailCalendarPresentation.doneDates(from: store.logs, task: store.task),
                assumedDates: TaskDetailCalendarPresentation.assumedDates(from: store.logs, task: store.task),
                dueDate: store.resolvedDueDate,
                createdAt: store.task.createdAt,
                pausedAt: store.task.pausedAt,
                isOrangeUrgencyToday: TaskDetailPresentation.isOrangeUrgency(store.task),
                selectedDate: store.resolvedSelectedDate,
                onSelectDate: { store.send(.selectedDateChanged($0)) }
            )
        }
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
                Text(store.task.actualDurationMinutes.map(TaskDetailHeaderBadgePresentation.durationText(for:)) ?? "Not logged")
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
                    tint: TaskDetailPriorityPresentation.importanceTint(for: store.task.importance)
                )
                priorityMetadataChip(
                    title: "Urgency",
                    value: store.task.urgency.title,
                    tint: TaskDetailPriorityPresentation.urgencyTint(for: store.task.urgency)
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                priorityFlagChip
                HStack(alignment: .center, spacing: 8) {
                    priorityMetadataChip(
                        title: "Importance",
                        value: store.task.importance.title,
                        tint: TaskDetailPriorityPresentation.importanceTint(for: store.task.importance)
                    )
                    priorityMetadataChip(
                        title: "Urgency",
                        value: store.task.urgency.title,
                        tint: TaskDetailPriorityPresentation.urgencyTint(for: store.task.urgency)
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
        TaskDetailPriorityPresentation.priorityTint(for: store.task.priority)
    }

    @ViewBuilder
    private var notificationDisabledWarningSection: some View {
        if let warningText = store.notificationDisabledWarningText,
           let actionTitle = store.notificationDisabledWarningActionTitle {
            TaskDetailNotificationDisabledWarningView(
                warningText: warningText,
                actionTitle: actionTitle
            ) {
                store.send(.notificationDisabledWarningTapped)
            }
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
        TaskDetailHeaderBadgePresentation.estimationBadges(
            task: store.task,
            displayedActualDurationMinutes: displayedActualDurationMinutes,
            includeSpent: true,
            includeStoryPoints: true
        )
    }

    private var displayedActualDurationMinutes: Int {
        TaskDetailHeaderBadgePresentation.displayedActualDurationMinutes(
            task: store.task,
            logs: store.logs
        )
    }

    private var displayedActualDurationText: String? {
        displayedActualDurationMinutes > 0
            ? TaskDetailHeaderBadgePresentation.durationText(for: displayedActualDurationMinutes)
            : nil
    }

    private var latestCompletedLog: RoutineLog? {
        TaskDetailHeaderBadgePresentation.latestCompletedLog(in: store.logs)
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
            Label("Pressure: \(pressure.title)", systemImage: TaskDetailPriorityPresentation.pressureSystemImage(for: pressure))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TaskDetailPriorityPresentation.pressureTint(for: pressure, style: .compactPill))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(TaskDetailPriorityPresentation.pressureTint(for: pressure, style: .compactPill).opacity(0.12), in: Capsule())
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
                .foregroundStyle(TaskDetailPriorityPresentation.todoStateTint(for: currentState, style: .compactPill))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(TaskDetailPriorityPresentation.todoStateTint(for: currentState, style: .compactPill).opacity(0.12), in: Capsule())
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
        TaskDetailStatusSummaryHeaderView(
            title: store.summaryStatusTitle,
            titleColor: summaryStatusColor,
            statusContextMessage: statusContextMessage,
            titleFont: titleFont
        )
    }

    private func statusMetadataSection(showSelectedDate: Bool) -> some View {
        TaskDetailStatusMetadataSectionView(
            items: TaskDetailStatusMetadataPresentation.items(
                for: store.state,
                showSelectedDate: showSelectedDate,
                displayedActualDurationText: displayedActualDurationText,
                dueDateMetadataDisplayText: dueDateMetadataDisplayText
            )
        )
    }

    private func statusActionSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation,
        useLargePrimaryControl: Bool = false
    ) -> some View {
        TaskDetailStatusActionSectionView(
            pauseArchivePresentation: pauseArchivePresentation,
            isOneOffTask: store.task.isOneOffTask,
            isArchived: store.task.isArchived(),
            isCompletionButtonDisabled: store.isCompletionButtonDisabled,
            isStepRoutineOffToday: store.isStepRoutineOffToday,
            isChecklistCompletionRoutine: store.task.isChecklistCompletionRoutine,
            canUndoSelectedDate: store.canUndoSelectedDate,
            hasBlockingRelationships: !store.blockingRelationships.isEmpty,
            blockerSummaryText: store.blockerSummaryText,
            useLargePrimaryControl: useLargePrimaryControl
        ) {
            completionButtonLabel
        } timeSpentButton: {
            timeSpentActionButton
        } onComplete: {
            store.send(store.completionButtonAction)
        } onPauseResume: {
            store.send(store.task.isArchived() ? .resumeTapped : .pauseTapped)
        } onNotToday: {
            store.send(.notTodayTapped)
        } onConfirmAssumedPastDays: {
            store.send(.confirmAssumedPastDays)
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
        TaskDetailStatusMetadataPresentation.shouldShowCompletionCount(for: store.state)
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
        TaskDetailRoutineLogsSectionView(
            logs: store.logs,
            isExpanded: $isRoutineLogsExpanded,
            isShowingAllLogs: $isShowingAllLogs,
            createdAtBadgeValue: store.state.createdAtBadgeValue,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke
        ) { _, log, _ in
            RoutineLogSwipeRow(
                timestampText: TaskDetailLogPresentation.timestampText(log.timestamp, showPersianDates: showPersianDates),
                timeSpentText: TaskDetailLogPresentation.timeSpentText(for: log, style: .compact),
                statusText: log.kind == .completed ? "Done" : "Canceled",
                statusColor: log.kind == .completed ? .green : .orange,
                actionTitle: TaskDetailLogPresentation.actionTitle(for: log),
                actionColor: log.kind == .completed ? .green : .orange,
                isActionEnabled: log.timestamp != nil
            ) {
                if let timestamp = log.timestamp {
                    store.send(.requestRemoveLogEntry(timestamp))
                }
            } editTimeAction: {
                beginEditingTime(for: log)
            }
        }
    }

    private func beginEditingTime(for log: RoutineLog) {
        editingTimeSpentMinutes = TaskDetailTimeSpentPresentation.defaultEditMinutes(
            currentMinutes: log.actualDurationMinutes,
            estimatedMinutes: store.task.estimatedDurationMinutes
        )
        editingTimeLog = log
    }

    private func beginEditingTaskTime() {
        editingTimeSpentMinutes = TaskDetailTimeSpentPresentation.defaultEditMinutes(
            currentMinutes: store.task.actualDurationMinutes,
            estimatedMinutes: store.task.estimatedDurationMinutes
        )
        isEditingTaskTimeSpent = true
    }

    private var taskChangesSection: some View {
        TaskDetailTaskChangesSectionView(
            changes: store.task.changeLogEntries,
            isExpanded: $isTaskChangesExpanded,
            showPersianDates: showPersianDates,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            relatedTaskName: relatedTaskName(for:)
        )
    }

    private func relatedTaskName(for change: RoutineTaskChangeLogEntry) -> String {
        guard let relatedTaskID = change.relatedTaskID else { return "task" }
        return focusSessionTasks.first(where: { $0.id == relatedTaskID })?.name ?? "task"
    }

    private var relationshipsSection: some View {
        TaskDetailRelationshipsSectionView(
            groups: store.groupedResolvedRelationships,
            selectedRelationshipKind: Binding(
                get: { store.addLinkedTaskRelationshipKind },
                set: { store.send(.addLinkedTaskRelationshipKindChanged($0)) }
            ),
            isVisualizeDisabled: store.resolvedRelationships.isEmpty,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            onVisualize: { isRelationshipGraphPresented = true },
            onOpenTask: { store.send(.openLinkedTask($0)) },
            onOpenAddLinkedTask: { store.send(.openAddLinkedTask) }
        )
    }

    private var checklistItemsSection: some View {
        TaskDetailChecklistSectionView(
            task: store.task,
            selectedDate: store.resolvedSelectedDate,
            isDoneToday: store.isDoneToday,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            isMarkedDone: { store.state.isChecklistItemMarkedDone($0) },
            onToggleCompletion: { store.send(.toggleChecklistItemCompletion($0)) },
            onMarkPurchased: { store.send(.markChecklistItemPurchased($0)) }
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

    private var routineLogsBackground: Color {
        TaskDetailPlatformStyle.routineLogsBackground
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

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
                TaskDetailToolbarContent(
                    store: store,
                    isInlineEditPresented: isInlineEditPresented,
                    canSaveCurrentEdit: canSaveCurrentEdit,
                    onShare: { isCloudSharingPresented = true }
                )
            }
            .routinaPlatformEditPresentation(
                isPresented: presentationRouting.editSheet,
                store: store,
                isEditEmojiPickerPresented: $isEditEmojiPickerPresented,
                emojiOptions: emojiOptions,
                canSaveCurrentEdit: canSaveCurrentEdit
            )
            .sheet(isPresented: $isEditEmojiPickerPresented) {
                EmojiPickerSheet(
                    selectedEmoji: presentationRouting.editRoutineEmoji,
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
                TaskDetailTimeSpentSheet(
                    title: "Time Spent",
                    minutes: $editingTimeSpentMinutes,
                    showsClearButton: log.actualDurationMinutes != nil,
                    onClear: {
                        store.send(.updateLogDuration(log.id, nil))
                        editingTimeLog = nil
                    },
                    onCancel: {
                        editingTimeLog = nil
                    },
                    onSave: {
                        store.send(.updateLogDuration(log.id, editingTimeSpentMinutes))
                        editingTimeLog = nil
                    }
                )
            }
            .sheet(isPresented: $isEditingTaskTimeSpent) {
                TaskDetailTimeSpentSheet(
                    title: "Time Spent",
                    minutes: $editingTimeSpentMinutes,
                    showsClearButton: store.task.actualDurationMinutes != nil,
                    onClear: {
                        store.send(.updateTaskDuration(nil))
                        isEditingTaskTimeSpent = false
                    },
                    onCancel: {
                        isEditingTaskTimeSpent = false
                    },
                    onSave: {
                        store.send(.updateTaskDuration(editingTimeSpentMinutes))
                        isEditingTaskTimeSpent = false
                    }
                )
            }
            .taskDetailDeleteConfirmationAlert(store: store)
            .taskDetailUndoCompletionConfirmationAlert(store: store, mode: .adaptiveRemoval)
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
                isPresented: TaskDetailAttachmentExportPresentation.isPresentedBinding(fileToSave: $fileToSave),
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
                if shouldShowTodoCalendar {
                    calendarSection
                }
                TaskDetailTodoPrimaryActionSection(store: store)
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
                TaskDetailRoutinePrimaryActionSection(
                    store: store,
                    pauseArchivePresentation: pauseArchivePresentation
                )
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

    private var presentationRouting: TaskDetailPresentationRouting {
        store.taskDetailPresentationRouting
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
            showsSoftDueLegend: store.resolvedSoftDueDate != nil,
            showsPausedLegend: store.task.pausedAt != nil,
            showsCreatedLegend: store.task.createdAt != nil
        ) {
            TaskDetailCalendarGridView(
                displayedMonthStart: displayedMonthStart,
                doneDates: TaskDetailCalendarPresentation.doneDates(from: store.logs, task: store.task),
                assumedDates: TaskDetailCalendarPresentation.assumedDates(from: store.logs, task: store.task),
                dueDate: store.resolvedDueDate,
                softDueDate: store.resolvedSoftDueDate,
                createdAt: store.task.createdAt,
                pausedAt: store.task.pausedAt,
                isOrangeUrgencyToday: TaskDetailPresentation.isOrangeUrgency(store.task),
                selectedDate: store.resolvedSelectedDate,
                onSelectDate: { store.send(.selectedDateChanged($0)) }
            )
        }
        .routinaPlatformCalendarCardStyle()
    }

    private var shouldShowTodoCalendar: Bool {
        guard store.task.isOneOffTask else { return true }
        guard !store.task.isCompletedOneOff && !store.task.isCanceledOneOff else { return false }
        return store.task.deadline != nil || store.task.reminderAt != nil
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
        statusSection(
            pauseArchivePresentation: pauseArchivePresentation,
            titleFont: .title3.weight(.semibold),
            useLargePrimaryControl: false,
            contentPadding: 16,
            cardBackground: TaskDetailPlatformStyle.summaryCardBackground,
            cardStroke: TaskDetailPlatformStyle.sectionCardStroke
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
        TaskDetailTimeSpentHeaderBox(
            actualDurationMinutes: store.task.actualDurationMinutes,
            onEdit: beginEditingTaskTime
        )
    }

    private var priorityDisclosureBox: some View {
        TaskDetailPriorityDisclosureBox(
            priority: store.task.priority,
            importance: store.task.importance,
            urgency: store.task.urgency,
            isExpanded: $isMatrixExpanded,
            onImportanceChanged: { store.send(.importanceChanged($0)) },
            onUrgencyChanged: { store.send(.urgencyChanged($0)) }
        )
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
        TaskDetailHeaderBadgePresentation.todoBadgeRows(
            state: store.state,
            summaryStatusColor: summaryStatusColor,
            dueDateMetadataDisplayText: dueDateMetadataDisplayText,
            layout: .mobile
        )
    }

    private var routineHeaderBadgeRows: [[TaskDetailHeaderBadgeItem]] {
        TaskDetailHeaderBadgePresentation.routineBadgeRows(
            state: store.state,
            summaryStatusColor: summaryStatusColor,
            dueDateMetadataDisplayText: dueDateMetadataDisplayText,
            layout: .mobile
        )
    }

    private var displayedActualDurationText: String? {
        TaskDetailHeaderBadgePresentation.displayedActualDurationText(
            task: store.task,
            logs: store.logs
        )
    }

    private var latestCompletedLog: RoutineLog? {
        TaskDetailHeaderBadgePresentation.latestCompletedLog(in: store.logs)
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

    private var taskExtrasSection: some View {
        TaskDetailExtrasSectionView(
            imageData: store.task.imageData,
            attachments: store.taskAttachments,
            notes: CalendarTaskImportSupport.displayNotes(from: store.task.notes),
            linkURL: store.task.resolvedLinkURL,
            linkText: store.task.link,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            onSaveAttachment: saveAttachment(item:),
            onOpenAttachment: { openAttachment(data: $0.data, fileName: $0.fileName) }
        )
    }

    func macStatusSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        statusSection(
            pauseArchivePresentation: pauseArchivePresentation,
            titleFont: .title2.weight(.semibold),
            useLargePrimaryControl: true,
            contentPadding: 18
        )
    }

    private func statusSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation,
        titleFont: Font,
        useLargePrimaryControl: Bool,
        contentPadding: CGFloat,
        cardBackground: Color? = nil,
        cardStroke: Color? = nil
    ) -> some View {
        TaskDetailStatusSectionView(
            title: store.summaryStatusTitle,
            titleColor: summaryStatusColor,
            statusContextMessage: statusContextMessage,
            titleFont: titleFont,
            showsMetadata: hasVisibleStatusMetadata,
            metadataItems: TaskDetailStatusMetadataPresentation.items(
                for: store.state,
                showSelectedDate: true,
                displayedActualDurationText: displayedActualDurationText,
                dueDateMetadataDisplayText: dueDateMetadataDisplayText
            ),
            pauseArchivePresentation: pauseArchivePresentation,
            completionButtonTitle: store.completionButtonTitle,
            completionButtonSystemImage: store.completionButtonSystemImage,
            isOneOffTask: store.task.isOneOffTask,
            isArchived: store.task.isArchived(),
            isCompletionButtonDisabled: store.isCompletionButtonDisabled,
            isStepRoutineOffToday: store.isStepRoutineOffToday,
            isChecklistCompletionRoutine: store.task.isChecklistCompletionRoutine,
            canUndoSelectedDate: store.canUndoSelectedDate,
            shouldShowBulkConfirmAssumedDays: false,
            bulkConfirmAssumedDaysTitle: "",
            hasBlockingRelationships: !store.blockingRelationships.isEmpty,
            blockerSummaryText: store.blockerSummaryText,
            useLargePrimaryControl: useLargePrimaryControl,
            contentPadding: contentPadding,
            cardBackground: cardBackground,
            cardStroke: cardStroke
        ) {
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
        TaskDetailStatusMetadataPresentation.statusContextMessage(
            for: store.state,
            showPersianDates: showPersianDates,
            style: .mobile
        )
    }

    private var dueDateMetadataDisplayText: String? {
        TaskDetailStatusMetadataPresentation.dueDateMetadataDisplayText(
            rawText: store.dueDateMetadataText,
            dueDate: store.resolvedDueDate,
            showPersianDates: showPersianDates
        )
    }

    private var hasVisibleStatusMetadata: Bool {
        TaskDetailStatusMetadataPresentation.hasVisibleMetadata(for: store.state)
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
                presentation: TaskDetailRoutineLogRowPresentation(log: log, showPersianDates: showPersianDates)
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
        editingTimeSpentMinutes = TaskDetailTimeSpentPresentation.defaultLogEditMinutes(
            log: log,
            task: store.task
        )
        editingTimeLog = log
    }

    private func beginEditingTaskTime() {
        editingTimeSpentMinutes = TaskDetailTimeSpentPresentation.defaultTaskEditMinutes(task: store.task)
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
            selectedRelationshipKind: presentationRouting.linkedTaskRelationshipKind,
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

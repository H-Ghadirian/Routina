import SwiftUI
import ComposableArchitecture
import SwiftData

struct TaskDetailTCAView: View {
    let store: StoreOf<TaskDetailFeature>
    let externalBlockingFocusTitle: String?
    @Dependency(\.appSettingsClient) private var appSettingsClient
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var focusSessions: [FocusSession]
    @State var displayedMonthStart = Calendar.current.startOfMonth(for: Date())
    @State var isShowingAllLogs = false
    @State private var isRoutineLogsExpanded = true
    @State private var isTaskChangesExpanded = true
    @State private var isCommentComposerVisible = false
    @State private var isTimeControlRevealed = false
    @State private var isTodoStateControlRevealed = false
    @State private var isPressureControlRevealed = false
    @State private var timeEditing = TaskDetailTimeEditingState()
    @State var isEditEmojiPickerPresented = false
    @State var syncedMacOverviewHeight: CGFloat = 0
    @State var attachmentTempURL: URL?
    @State var fileToSave: AttachmentItem?
    @State private var isCloudSharingPresented = false
    @State private var isRelationshipGraphPresented = false
    @State private var isMatrixExpanded = false
    @State private var referenceDate = Date()
    @State private var activeBlockingTask: RoutineTask?
    @State private var sprintBlockingFocusTitle: String?
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) private var showPersianDates = false
    let emojiOptions = EmojiCatalog.uniqueQuick
    let allEmojiOptions = EmojiCatalog.searchableAll

    init(
        store: StoreOf<TaskDetailFeature>,
        blockingFocusTitle: String? = nil
    ) {
        self.store = store
        self.externalBlockingFocusTitle = blockingFocusTitle

        let taskID = store.task.id
        _focusSessions = Query(
            filter: #Predicate<FocusSession> { session in
                session.taskID == taskID
                    || (session.completedAt == nil && session.abandonedAt == nil)
            },
            sort: \.startedAt,
            order: .reverse
        )
    }

    var body: some View {
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
.task {
    await refreshFocusBlockingContext()
}
.onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
    Task {
        await refreshFocusBlockingContext()
    }
}
.sheet(item: $timeEditing.editingLog) { log in
    TaskDetailTimeSpentSheet(
        title: "Time Spent",
        minutes: $timeEditing.editingMinutes,
        showsClearButton: log.actualDurationMinutes != nil,
        onClear: {
            store.send(.updateLogDuration(log.id, nil))
            timeEditing.dismissLog()
        },
        onCancel: {
            timeEditing.dismissLog()
        },
        onSave: {
            store.send(.updateLogDuration(log.id, timeEditing.editingMinutes))
            timeEditing.dismissLog()
        }
    )
}
.sheet(isPresented: $timeEditing.isEditingTaskTimeSpent) {
    TaskDetailTimeSpentSheet(
        title: "Time Spent",
        minutes: $timeEditing.editingMinutes,
        showsClearButton: store.task.actualDurationMinutes != nil,
        onClear: {
            store.send(.updateTaskDuration(nil))
            timeEditing.dismissTask()
        },
        onCancel: {
            timeEditing.dismissTask()
        },
        onSave: {
            store.send(.updateTaskDuration(timeEditing.editingMinutes))
            timeEditing.dismissTask()
        }
    )
}
.taskDetailDeleteConfirmationAlert(store: store)
.taskDetailUndoCompletionConfirmationAlert(store: store, mode: .adaptiveRemoval)
.onAppear {
    referenceDate = Date()
    displayedMonthStart = Calendar.current.startOfMonth(for: store.resolvedSelectedDate)
}
.onChange(of: store.task.id) { _, _ in
    referenceDate = Date()
    activeBlockingTask = nil
    isCommentComposerVisible = false
    resetRevealedOptionalControls()
    Task {
        await refreshFocusBlockingContext()
    }
}
.onChange(of: store.shouldDismissAfterDelete) { _, shouldDismiss in
    guard shouldDismiss else { return }
    dismiss()
    store.send(.deleteDismissHandled)
}
.onChange(of: store.resolvedSelectedDate) { _, newValue in
    displayedMonthStart = Calendar.current.startOfMonth(for: newValue)
}
.onChange(of: store.task.actualDurationMinutes) { _, _ in
    isTimeControlRevealed = false
}
.onChange(of: store.task.pressure) { oldValue, newValue in
    if oldValue != newValue {
        isPressureControlRevealed = false
    }
}
.onChange(of: store.task.todoStateRawValue) { _, newValue in
    if newValue != nil {
        isTodoStateControlRevealed = false
    }
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
            LazyVStack(alignment: .leading, spacing: 14) {
                todoHeaderSection
                notificationDisabledWarningSection
                calendarSection
                TaskDetailTodoPrimaryActionSection(
                    store: store,
                    showsTodoStateControl: shouldShowTodoStateControl,
                    showsPressureControl: shouldShowPressureControl
                )
                todoStateTimingSection
                if store.task.focusModeEnabled {
                    focusSessionSection
                }
                optionalActionsSection
                if shouldShowCommentsSection {
                    commentsSection
                }
                routineLogsSection
                taskChangesSection
                if store.task.hasChecklistItems {
                    checklistItemsSection
                }
                if shouldShowRelationshipsSection {
                    relationshipsSection
                }
                if hasTaskExtras {
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
            LazyVStack(alignment: .leading, spacing: 16) {
                routineHeaderSection
                notificationDisabledWarningSection
                TaskDetailRoutinePrimaryActionSection(
                    store: store,
                    pauseArchivePresentation: pauseArchivePresentation,
                    showsPressureControl: shouldShowPressureControl
                )
                calendarSection
                if store.task.focusModeEnabled {
                    focusSessionSection
                }
                optionalActionsSection
                if shouldShowCommentsSection {
                    commentsSection
                }
                routineLogsSection
                taskChangesSection
                if store.task.hasChecklistItems {
                    checklistItemsSection
                }
                if shouldShowRelationshipsSection {
                    relationshipsSection
                }
                if hasTaskExtras {
                    taskExtrasSection
                }
            }
            .padding(TaskDetailPlatformStyle.detailContentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var focusSessionSection: some View {
        TaskDetailFocusSessionSectionView(
            task: store.task,
            sessions: focusSessions,
            allTasks: focusSessionTaskCandidates,
            blockingFocusTitle: blockingFocusTitle
        )
    }

    private var commentsSection: some View {
        TaskDetailCommentsSectionView(
            comments: store.task.comments,
            newCommentDraft: store.detailCommentDraft,
            canAddComment: store.canAddDetailComment,
            editingCommentID: store.editingDetailCommentID,
            editingCommentDraft: store.editingDetailCommentDraft,
            canSaveEditedComment: store.canSaveEditingDetailComment,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            onNewCommentDraftChanged: { store.send(.detailCommentDraftChanged($0)) },
            onAddComment: { store.send(.detailCommentAddTapped) },
            onEditComment: { store.send(.detailCommentEditTapped($0)) },
            onEditCommentDraftChanged: { store.send(.detailCommentEditDraftChanged($0)) },
            onCancelEditComment: { store.send(.detailCommentEditCancelTapped) },
            onSaveEditComment: { store.send(.detailCommentEditSaveTapped($0)) },
            onDeleteComment: { store.send(.detailCommentDeleteTapped($0)) }
        )
    }

    @ViewBuilder
    private var optionalActionsSection: some View {
        if shouldShowOptionalActionsSection {
            TaskDetailOptionalActionsSectionView(
                actions: optionalDetailActions,
                background: routineLogsBackground,
                stroke: TaskDetailPlatformStyle.sectionCardStroke
            )
        }
    }

    private var shouldShowOptionalActionsSection: Bool {
        !optionalDetailActions.isEmpty
    }

    private var optionalDetailActions: [TaskDetailOptionalAction] {
        var actions: [TaskDetailOptionalAction] = []

        if !shouldShowCommentsSection {
            actions.append(TaskDetailOptionalAction(title: "Comment", systemImage: "text.bubble") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isCommentComposerVisible = true
                }
            })
        }

        if !shouldShowRelationshipsSection {
            actions.append(TaskDetailOptionalAction(title: "Linked Task", systemImage: "link.badge.plus") {
                store.send(.openAddLinkedTask)
            })
        }

        if shouldShowTimeAddAction {
            actions.append(TaskDetailOptionalAction(title: "Time", systemImage: "clock.badge") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isTimeControlRevealed = true
                }
            })
        }

        if shouldShowTodoStateAddAction {
            actions.append(TaskDetailOptionalAction(title: "State", systemImage: "circle.grid.2x1") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isTodoStateControlRevealed = true
                }
            })
        }

        if shouldShowPressureAddAction {
            actions.append(TaskDetailOptionalAction(title: "Pressure", systemImage: "gauge.with.dots.needle.50percent") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isPressureControlRevealed = true
                }
            })
        }

        if !store.task.hasChecklistItems {
            actions.append(TaskDetailOptionalAction(title: "Checklist", systemImage: "checklist") {
                store.send(.setEditSheet(true))
            })
        }

        if !hasTaskExtras {
            actions.append(TaskDetailOptionalAction(title: "Details", systemImage: "square.and.pencil") {
                store.send(.setEditSheet(true))
            })
        }

        return actions
    }

    private var shouldShowCommentsSection: Bool {
        isCommentComposerVisible
            || !store.task.comments.isEmpty
            || !store.detailCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || store.editingDetailCommentID != nil
    }

    private var shouldShowRelationshipsSection: Bool {
        !store.groupedResolvedRelationships.isEmpty
    }

    private var shouldShowTimeControl: Bool {
        canShowTimeControl
            && (
                isTimeControlRevealed
                    || TaskDetailOptionalControlVisibility.showsTimeSpent(for: store.task)
            )
    }

    private var shouldShowTodoStateControl: Bool {
        canShowTodoStateControl
            && (isTodoStateControlRevealed || TaskDetailOptionalControlVisibility.showsTodoState(for: store.task))
    }

    private var shouldShowPressureControl: Bool {
        isPressureControlRevealed || TaskDetailOptionalControlVisibility.showsPressure(for: store.task)
    }

    private var shouldShowTodoStateAddAction: Bool {
        canShowTodoStateControl && !shouldShowTodoStateControl
    }

    private var shouldShowPressureAddAction: Bool {
        !shouldShowPressureControl
    }

    private var shouldShowTimeAddAction: Bool {
        canShowTimeControl && !shouldShowTimeControl
    }

    private var canShowTimeControl: Bool {
        store.task.isOneOffTask
    }

    private var canShowTodoStateControl: Bool {
        store.task.isOneOffTask
            && !store.task.isCompletedOneOff
            && !store.task.isCanceledOneOff
    }

    private var hasTaskExtras: Bool {
        store.task.hasNotes
            || store.task.hasImage
            || store.task.hasVoiceNote
            || !store.taskAttachments.isEmpty
            || store.task.resolvedLinkURL != nil
    }

    private func resetRevealedOptionalControls() {
        isTimeControlRevealed = false
        isTodoStateControlRevealed = false
        isPressureControlRevealed = false
    }

    private var blockingFocusTitle: String? {
        externalBlockingFocusTitle ?? sprintBlockingFocusTitle
    }

    @MainActor
    private func refreshFocusBlockingContext() async {
        refreshActiveBlockingTask()
        refreshSprintFocusBlock()
    }

    private var focusSessionTaskCandidates: [RoutineTask] {
        guard let activeBlockingTask,
              activeBlockingTask.id != store.task.id else {
            return [store.task]
        }
        return [store.task, activeBlockingTask]
    }

    @MainActor
    private func refreshActiveBlockingTask() {
        guard let activeTaskID = focusSessions.first(where: { session in
            session.taskID != store.task.id
                && session.completedAt == nil
                && session.abandonedAt == nil
        })?.taskID else {
            activeBlockingTask = nil
            return
        }

        do {
            var descriptor = TaskDetailFetchDescriptors.task(for: activeTaskID)
            descriptor.fetchLimit = 1
            activeBlockingTask = try modelContext.fetch(descriptor).first
        } catch {
            activeBlockingTask = nil
        }
    }

    @MainActor
    private func refreshSprintFocusBlock() {
        do {
            var sessionDescriptor = FetchDescriptor<SprintFocusSessionRecord>(
                predicate: #Predicate { session in
                    session.stoppedAt == nil
                },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            sessionDescriptor.fetchLimit = 1

            guard let session = try modelContext.fetch(sessionDescriptor).first else {
                sprintBlockingFocusTitle = nil
                return
            }

            let sprintID = session.sprintID
            var sprintDescriptor = FetchDescriptor<BoardSprintRecord>(
                predicate: #Predicate { sprint in
                    sprint.id == sprintID
                }
            )
            sprintDescriptor.fetchLimit = 1
            sprintBlockingFocusTitle = try modelContext.fetch(sprintDescriptor).first?.title ?? "a sprint"
        } catch {
            sprintBlockingFocusTitle = nil
        }
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
        TaskDetailCalendarCardContent(
            displayedMonthStart: displayedMonthStart,
            onPreviousMonth: {
                displayedMonthStart = TaskDetailCalendarNavigation.previousMonth(from: displayedMonthStart)
            },
            onNextMonth: {
                displayedMonthStart = TaskDetailCalendarNavigation.nextMonth(from: displayedMonthStart)
            },
            logs: store.logs,
            task: store.task,
            dueDate: store.resolvedDueDate,
            softDueDate: store.resolvedSoftDueDate,
            isOrangeUrgencyToday: TaskDetailPresentation.isOrangeUrgency(store.task),
            selectedDate: store.resolvedSelectedDate,
            onSelectDate: { store.send(.selectedDateChanged($0)) }
        )
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
                if shouldShowTimeControl {
                    todoTimeSpentHeaderBox
                }
                headerGoalsBox
            }
        }
    }

    @ViewBuilder
    private var todoStateTimingSection: some View {
        if let summary = TodoStateTiming.summary(
            for: store.task,
            referenceDate: referenceDate,
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
            VStack(alignment: .leading, spacing: 8) {
                priorityDisclosureBox
                headerGoalsBox
            }
        }
    }

    @ViewBuilder
    private var headerGoalsBox: some View {
        if !store.taskGoalSummaries.isEmpty {
            TaskDetailGoalsHeaderBoxView(goals: store.taskGoalSummaries)
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
            voiceNote: store.task.voiceNote,
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
            .routinaGlassPill(tint: tint, tintOpacity: 0.12)
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
        timeEditing.beginEditingLog(log, task: store.task)
    }

    private func beginEditingTaskTime() {
        timeEditing.beginEditingTask(store.task)
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
        return store.availableRelationshipTasks.first(where: { $0.id == relatedTaskID })?.displayName ?? "task"
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
            newItemTitle: Binding(
                get: { store.editChecklistItemDraftTitle },
                set: { store.send(.editChecklistItemDraftTitleChanged($0)) }
            ),
            newItemIntervalDays: Binding(
                get: { store.editChecklistItemDraftInterval },
                set: { store.send(.editChecklistItemDraftIntervalChanged($0)) }
            ),
            isAddItemDisabled: RoutineChecklistItem.normalizedTitle(store.editChecklistItemDraftTitle) == nil,
            isMarkedDone: { store.state.isChecklistItemMarkedDone($0) },
            onAddItem: { store.send(.detailAddChecklistItemTapped) },
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
            task: store.task,
            hasUnresolvedMissedExactTimedOccurrence: store.missedExactTimedOccurrenceDate != nil
        )
    }

    private var routineLogsBackground: Color {
        TaskDetailPlatformStyle.routineLogsBackground
    }

    // MARK: - Attachment actions

    func saveAttachment(item: AttachmentItem) {
        attachmentActionRouter.saveAttachment(item)
    }

    func openAttachment(data: Data, fileName: String) {
        attachmentActionRouter.openAttachment(data: data, fileName: fileName)
    }

    private var attachmentActionRouter: TaskDetailAttachmentActionRouter {
        TaskDetailAttachmentActionRouter(
            task: store.task,
            saveFile: { fileToSave = $0 },
            openURL: { platformOpenAttachment(url: $0) }
        )
    }
}

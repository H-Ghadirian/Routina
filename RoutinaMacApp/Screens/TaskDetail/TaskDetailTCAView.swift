import SwiftUI
import ComposableArchitecture
import SwiftData

struct TaskDetailTCAView: View {
    let store: StoreOf<TaskDetailFeature>
    var showsPrincipalToolbarTitle = true
    let externalBlockingFocusTitle: String?
    @Dependency(\.appSettingsClient) private var appSettingsClient
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.addEditFormCoordinator) private var formCoordinator
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var focusSessions: [FocusSession]
    @Query(sort: \RoutineEvent.startedAt, order: .reverse) private var events: [RoutineEvent]
    @State var displayedMonthStart = Calendar.current.startOfMonth(for: Date())
    @State var isShowingAllLogs = false
    @State private var isRoutineLogsExpanded = false
    @State private var isCommentComposerVisible = false
    @State private var isTimeControlRevealed = false
    @State private var isTodoStateControlRevealed = false
    @State private var isPressureControlRevealed = false
    @State private var isTimeSectionExpanded = false
    @State private var timeEditing = TaskDetailTimeEditingState()
    @State private var taskTimeEntryHours = 0
    @State private var taskTimeEntryMinutes = 25
    @State private var taskTimeEntryResetToken = 0
    @State var isEditEmojiPickerPresented = false
    @State var syncedMacOverviewHeight: CGFloat = 0
    @State var attachmentTempURL: URL?
    @State var fileToSave: AttachmentItem?
    @State private var isRelationshipGraphPresented = false
    @State private var isMatrixExpanded = false
    @State private var isCalendarExpanded = false
    @State private var referenceDate = Date()
    @State private var activeBlockingTask: RoutineTask?
    @State private var sprintBlockingFocusTitle: String?
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) private var showPersianDates = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isGoalsTabEnabled = false
    let emojiOptions = EmojiCatalog.uniqueQuick
    let allEmojiOptions = EmojiCatalog.searchableAll

    init(
        store: StoreOf<TaskDetailFeature>,
        showsPrincipalToolbarTitle: Bool = true,
        blockingFocusTitle: String? = nil
    ) {
        self.store = store
        self.showsPrincipalToolbarTitle = showsPrincipalToolbarTitle
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
        showsPrincipalToolbarTitle: showsPrincipalToolbarTitle,
        isInlineEditPresented: isInlineEditPresented,
        canSaveCurrentEdit: canSaveCurrentEdit
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
.sheet(item: $timeEditing.editingLog) { log in
    TaskDetailLogTimeSpentSheet(
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
.task {
    await refreshFocusBlockingContext()
}
.onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
    Task {
        await refreshFocusBlockingContext()
    }
}
.taskDetailDeleteConfirmationAlert(store: store)
.taskDetailUndoCompletionConfirmationAlert(store: store, mode: .undoOnly)
.onAppear {
    referenceDate = Date()
    displayedMonthStart = Calendar.current.startOfMonth(for: store.resolvedSelectedDate)
    syncAvailableEvents()
    collapseDefaultSections()
}
.onChange(of: availableEventCandidates) { _, _ in
    syncAvailableEvents()
}
.onChange(of: store.task.id) { _, _ in
    referenceDate = Date()
    activeBlockingTask = nil
    isCommentComposerVisible = false
    resetRevealedOptionalControls()
    syncAvailableEvents()
    Task {
        await refreshFocusBlockingContext()
    }
    collapseDefaultSections()
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
                if shouldShowCommentsSection {
                    commentsSection
                }
                historySection
                if store.task.hasChecklistItems {
                    checklistItemsSection
                }
                if shouldShowLinkedEventsSection {
                    linkedEventsSection
                }
                if shouldShowRelationshipsSection {
                    relationshipsSection
                }
                if hasTaskExtras {
                    taskExtrasSection
                }
                optionalActionsSection
            }
            .padding(TaskDetailPlatformStyle.detailContentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var todoStateTimingSummary: TodoStateTimingSummary? {
        TodoStateTiming.summary(
            for: store.task,
            referenceDate: referenceDate,
            calendar: Calendar.current
        )
    }

    private var priorityDisclosureBox: some View {
        TaskDetailPriorityDisclosureBox(
            priority: store.task.priority,
            importance: store.task.importance,
            urgency: store.task.urgency,
            isExpanded: $isMatrixExpanded,
            summaryLayout: .horizontal,
            matrixMaxWidth: 420,
            onImportanceChanged: { store.send(.importanceChanged($0)) },
            onUrgencyChanged: { store.send(.urgencyChanged($0)) }
        )
    }

    private var headerSupplementaryContent: some View {
        TaskDetailMacHeaderSupplementaryContent(
            task: store.task,
            goals: store.taskGoalSummaries,
            selectedDate: store.resolvedSelectedDate,
            showPersianDates: showPersianDates,
            isCalendarExpanded: $isCalendarExpanded,
            sectionCardStroke: TaskDetailPlatformStyle.sectionCardStroke,
            tagTint: { tagTint(for: $0) }
        ) {
            calendarSection
        }
    }

    @ViewBuilder
    private var todoHeaderControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            priorityDisclosureBox
            if shouldShowEffortSection {
                todoTimeSpentHeaderBox
            }

            if shouldShowTodoHeaderStatusControls {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 8) {
                        if shouldShowTodoStateControl {
                            TaskDetailTodoStateSegmentedPicker(
                                store: store,
                                timingSummary: todoStateTimingSummary,
                                showPersianDates: showPersianDates
                            )
                                .frame(minWidth: 380)
                        }
                        if shouldShowPressureControl {
                            TaskDetailPressureSegmentedPicker(store: store)
                                .frame(minWidth: 300)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if shouldShowTodoStateControl {
                            TaskDetailTodoStateSegmentedPicker(
                                store: store,
                                timingSummary: todoStateTimingSummary,
                                showPersianDates: showPersianDates
                            )
                        }
                        if shouldShowPressureControl {
                            TaskDetailPressureSegmentedPicker(store: store)
                        }
                    }
                }
            }
        }
    }

    private var shouldShowTodoHeaderStatusControls: Bool {
        shouldShowTodoStateControl || shouldShowPressureControl
    }

    private var shouldShowTimeControl: Bool {
        canShowTimeControl
            && (
                isTimeControlRevealed
                    || TaskDetailOptionalControlVisibility.showsTimeSpent(
                        for: store.task,
                        hasActiveFocus: hasActiveFocusForTask,
                        showsFocusTimer: store.task.focusModeEnabled
                    )
            )
    }

    private var shouldShowEffortSection: Bool {
        shouldShowTimeControl
            || store.task.estimatedDurationMinutes != nil
            || store.task.storyPoints != nil
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
        canShowTimeControl && !shouldShowEffortSection
    }

    private var canShowTimeControl: Bool {
        store.task.isOneOffTask
    }

    private var canShowTodoStateControl: Bool {
        store.task.isOneOffTask
            && !store.task.isCompletedOneOff
            && !store.task.isCanceledOneOff
    }

    private var hasActiveFocusForTask: Bool {
        focusSessions.contains { session in
            session.taskID == store.task.id && session.state == .active
        }
    }

    private var todoTimeSpentHeaderBox: some View {
        TaskDetailTimeSpentHeaderBox(
            task: store.task,
            focusSessions: focusSessions,
            allTasks: focusSessionTaskCandidates,
            resetToken: taskTimeEntryResetToken,
            blockingFocusTitle: blockingFocusTitle,
            isExpanded: $isTimeSectionExpanded,
            entryHours: $taskTimeEntryHours,
            entryMinutes: $taskTimeEntryMinutes,
            onApplyMinutes: { store.send(.updateTaskDuration($0)) },
            onCompletedFocusDuration: addCompletedFocusToTimeSpent
        )
    }

    @ViewBuilder
    private var routineHeaderControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            priorityDisclosureBox
            if shouldShowPressureControl {
                TaskDetailPressureSegmentedPicker(store: store)
            }
        }
    }

    private var taskDetailContent: some View {
        let _ = store.taskRefreshID

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                routineHeaderSection
                notificationDisabledWarningSection
                if shouldShowFocusSessionSection {
                    focusSessionSection
                }
                if shouldShowCommentsSection {
                    commentsSection
                }
                historySection
                if store.task.hasChecklistItems {
                    checklistItemsSection
                }
                if shouldShowLinkedEventsSection {
                    linkedEventsSection
                }
                if shouldShowRelationshipsSection {
                    relationshipsSection
                }
                if hasTaskExtras {
                    taskExtrasSection
                }
                optionalActionsSection
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
            blockingFocusTitle: blockingFocusTitle,
            onCompletedDuration: addCompletedFocusToTimeSpent
        )
    }

    private var shouldShowFocusSessionSection: Bool {
        TaskDetailFocusSessionSectionVisibility.shouldShow(
            for: store.task,
            sessions: focusSessions
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
            isCommentComposerVisible: $isCommentComposerVisible,
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
        .id(store.task.id)
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

        if shouldShowTimeAddAction {
            actions.append(TaskDetailOptionalAction(title: "Time", systemImage: "clock.badge") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isTimeControlRevealed = true
                    isTimeSectionExpanded = true
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

        if shouldShowEstimationAddAction {
            actions.append(editSectionAction(title: "Estimate", section: .estimation))
        }

        if !store.task.hasChecklistItems {
            actions.append(editSectionAction(title: "Checklist", section: .checklist))
        }

        if store.task.tags.isEmpty {
            actions.append(editSectionAction(title: "Tags", section: .tags))
        }

        if shouldShowGoalSectionInAddMore && store.taskGoalSummaries.isEmpty {
            actions.append(editSectionAction(title: "Goals", section: .goals))
        }

        if store.taskEventCandidates.isEmpty {
            actions.append(editSectionAction(title: "Events", section: .events))
        }

        if !shouldShowRelationshipsSection {
            actions.append(TaskDetailOptionalAction(title: "Linked Task", systemImage: "link.badge.plus") {
                store.send(.openAddLinkedTask)
            })
        }

        actions.append(editSectionAction(title: "Places", section: .places))

        if !store.task.hasNotes {
            actions.append(editSectionAction(title: "Notes", section: .notes))
        }

        if store.task.resolvedLinkURLs.isEmpty {
            actions.append(editSectionAction(title: "Links", section: .linkURL))
        }

        if store.task.color == .none {
            actions.append(editSectionAction(title: "Color", section: .color))
        }

        if !store.task.hasImage {
            actions.append(editSectionAction(title: "Image", section: .image))
        }

        if !store.task.hasVoiceNote {
            actions.append(editSectionAction(title: "Voice Note", section: .voiceNote))
        }

        if store.taskAttachments.isEmpty {
            actions.append(editSectionAction(title: "File", section: .attachment))
        }

        return actions
    }

    private var shouldShowEstimationAddAction: Bool {
        store.task.estimatedDurationMinutes == nil
            && store.task.storyPoints == nil
            && !store.task.focusModeEnabled
    }

    private var shouldShowGoalSectionInAddMore: Bool {
        isGoalsTabEnabled
    }

    private func editSectionAction(title: String, section: FormSection) -> TaskDetailOptionalAction {
        TaskDetailOptionalAction(title: title, systemImage: section.icon) {
            openEditSection(section)
        }
    }

    private func openEditSection(_ section: FormSection) {
        withAnimation(.easeInOut(duration: 0.18)) {
            formCoordinator.revealTaskFormSection(section)
        }
        store.send(.setEditSheet(true))

        Task { @MainActor in
            await Task.yield()
            await Task.yield()
            withAnimation(.easeInOut(duration: 0.25)) {
                formCoordinator.scrollTarget = section
            }
        }
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

    private var shouldShowLinkedEventsSection: Bool {
        !store.taskEventCandidates.isEmpty
    }

    private var hasTaskExtras: Bool {
        store.task.hasNotes
            || store.task.hasImage
            || store.task.hasVoiceNote
            || !store.taskAttachments.isEmpty
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

    private var availableEventCandidates: [RoutineEventLinkCandidate] {
        RoutineEventLinkCandidate.candidates(from: events)
    }

    private func syncAvailableEvents() {
        store.send(.availableEventsLoaded(availableEventCandidates))
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
            onSelectDate: { store.send(.selectedDateChanged($0)) },
            onToday: {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                displayedMonthStart = calendar.startOfMonth(for: today)
                store.send(.selectedDateChanged(today))
            }
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

    private func collapseDefaultSections() {
        isMatrixExpanded = false
        isTimeSectionExpanded = false
        isCalendarExpanded = false
        isRoutineLogsExpanded = false
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
            tags: []
        ) { tag in
            statusTagChip(tag)
        } additionalContent: {
            VStack(alignment: .leading, spacing: 8) {
                todoHeaderControls
                headerSupplementaryContent
            }
        }
    }

    private var routineHeaderSection: some View {
        TaskDetailHeaderSectionView(
            title: store.task.name ?? "Routine",
            statusContextMessage: statusContextMessage,
            badgeRows: routineHeaderBadgeRows,
            tags: []
        ) { tag in
            statusTagChip(tag)
        } additionalContent: {
            VStack(alignment: .leading, spacing: 8) {
                routineHeaderControls
                headerSupplementaryContent
            }
        }
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
            layout: .desktop
        )
    }

    private var routineHeaderBadgeRows: [[TaskDetailHeaderBadgeItem]] {
        TaskDetailHeaderBadgePresentation.routineBadgeRows(
            state: store.state,
            summaryStatusColor: summaryStatusColor,
            dueDateMetadataDisplayText: dueDateMetadataDisplayText,
            layout: .desktop
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
            links: [],
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            onOpenImage: openTaskImage(data:),
            onSaveAttachment: saveAttachment(item:),
            onOpenAttachment: { openAttachment(data: $0.data, fileName: $0.fileName) }
        )
    }

    private var linkedEventsSection: some View {
        TaskDetailLinkedEventsSectionView(
            events: store.taskEventCandidates,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke
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
            shouldShowBulkConfirmAssumedDays: store.shouldShowBulkConfirmAssumedDays,
            bulkConfirmAssumedDaysTitle: store.bulkConfirmAssumedDaysTitle,
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
        let tint = tagTint(for: tag)

        return Text("#\(tag)")
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .routinaGlassPill(tint: tint, tintOpacity: 0.13)
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.25), lineWidth: 1)
            )
    }

    private func tagTint(for tag: String) -> Color {
        if let color = Color(routineTagHex: RoutineTagColors.colorHex(for: tag, in: appSettingsClient.tagColors())) {
            return color
        }
        return .secondary
    }

    private var statusContextMessage: String? {
        TaskDetailStatusMetadataPresentation.statusContextMessage(
            for: store.state,
            showPersianDates: showPersianDates,
            style: .desktop
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

    private var historySection: some View {
        TaskDetailHistorySectionView(
            logs: store.logs,
            changes: store.task.changeLogEntries,
            isExpanded: $isRoutineLogsExpanded,
            isShowingAllLogs: $isShowingAllLogs,
            createdAtBadgeValue: store.state.createdAtBadgeValue,
            showPersianDates: showPersianDates,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            relatedTaskName: relatedTaskName(for:)
        ) { _, log, _ in
            let presentation = TaskDetailRoutineLogRowPresentation(log: log, showPersianDates: showPersianDates)
            TaskDetailRoutineLogRowContent(
                presentation: presentation,
                timeSpentStyle: .full,
                onEditTime: { beginEditingTime(for: log) }
            )
            .contextMenu {
                Button(log.actualDurationMinutes == nil ? "Add Time Spent" : "Edit Time Spent") {
                    beginEditingTime(for: log)
                }
                if let timestamp = log.timestamp {
                    Button(presentation.actionTitle) {
                        store.send(.requestRemoveLogEntry(timestamp))
                    }
                }
            }
        }
    }

    private func beginEditingTime(for log: RoutineLog) {
        timeEditing.beginEditingLog(log, task: store.task)
    }

    private func beginEditingTaskTime() {
        isTimeSectionExpanded = true
        taskTimeEntryResetToken += 1
    }

    private func addCompletedFocusToTimeSpent(_ seconds: TimeInterval) {
        guard let update = TaskDetailTimeSpentPresentation.focusSessionUpdate(
            task: store.task,
            logs: store.logs,
            seconds: seconds
        ) else {
            return
        }

        switch update.target {
        case .task:
            store.send(.updateTaskDuration(update.minutes))

        case let .log(id):
            store.send(.updateLogDuration(id, update.minutes))
        }
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
            isSelectedDateDone: store.isSelectedDateDone,
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
            onToggleRunoutDone: { store.send(.toggleChecklistRunoutItemDone($0)) },
            onExtend: { store.send(.extendChecklistItemRunout($0)) },
            onUpdateItem: { itemID, title, intervalDays in
                store.send(.detailUpdateChecklistItem(itemID, title: title, intervalDays: intervalDays))
            }
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

    func openTaskImage(data: Data) {
        attachmentActionRouter.openTaskImage(data: data)
    }

    private var attachmentActionRouter: TaskDetailAttachmentActionRouter {
        TaskDetailAttachmentActionRouter(
            task: store.task,
            saveFile: { fileToSave = $0 },
            openURL: { platformOpenAttachment(url: $0) }
        )
    }

}

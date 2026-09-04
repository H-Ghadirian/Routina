import SwiftUI

extension TaskDetailTCAView {
    var historySection: some View {
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
            let presentation = TaskDetailRoutineLogRowPresentation(
                log: log,
                showPersianDates: showPersianDates,
                sourceTaskName: sourceTaskName(for: log)
            )
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

    var taskHeatmapSection: some View {
        TaskDetailMacHeatmapSectionView(
            task: store.task,
            logs: store.logs,
            referenceDate: referenceDate,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke
        )
    }

    func beginEditingTime(for log: RoutineLog) {
        timeEditing.beginEditingLog(log, task: store.task)
    }

    func beginEditingTaskTime() {
        timeEditing.beginEditingTask(store.task)
    }

    private func relatedTaskName(for change: RoutineTaskChangeLogEntry) -> String {
        guard let relatedTaskID = change.relatedTaskID else { return "task" }
        return store.availableRelationshipTasks.first(where: { $0.id == relatedTaskID })?.displayName ?? "task"
    }

    private func sourceTaskName(for log: RoutineLog) -> String? {
        guard let sourceTaskID = log.sourceTaskID else { return nil }
        return store.availableRelationshipTasks.first(where: { $0.id == sourceTaskID })?.displayName
    }

    var relationshipsSection: some View {
        TaskDetailRelationshipsSectionView(
            groups: store.groupedResolvedRelationships,
            showsVisualizeButton: isTaskRelationshipVisualizerEnabled,
            isVisualizeDisabled: store.resolvedRelationships.isEmpty,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            onVisualize: { isRelationshipGraphPresented = true },
            onOpenTask: { store.send(.openLinkedTask($0)) },
            onOpenAddLinkedTask: openCreateLinkedTask,
            onLinkExistingTask: openExistingTaskLinker
        )
    }

    @ViewBuilder
    func linkedEventDetailSheet(eventID: UUID) -> some View {
        let event =
            areMacEventEmotionActionsEnabled
            ? events.first(where: { $0.id == eventID })
            : nil
        if let event {
            NavigationStack {
                RoutineEventDetailView(event: event)
            }
        } else {
            Text("Event not found")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding()
        }
    }

    var checklistItemsSection: some View {
        TaskDetailChecklistSectionView(
            task: store.task,
            checklistItems: store.detailChecklistItems,
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
            isComposerInitiallyExpanded: isChecklistSectionRevealed && !store.hasStoredChecklistItems,
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

    var summaryStatusColor: Color {
        summaryStatusColor(daysUntilDueIfActive: store.daysUntilDueIfActive)
    }

    func summaryStatusColor(daysUntilDueIfActive: Int?) -> Color {
        let isChecklistCompletion = store.isChecklistCompletionFromStoredItems
        let isChecklistDriven = store.isChecklistDrivenFromStoredItems

        return TaskDetailPresentation.summaryTitleColor(
            pausedAt: store.task.pausedAt,
            pauseUntil: store.task.pauseUntil,
            isSnoozed: store.task.isSnoozed(),
            usesOngoingLifecycle: store.task.usesOngoingLifecycle,
            isOngoing: store.task.isOngoing,
            isOneOffTask: store.task.isOneOffTask,
            isInProgress: store.task.isInProgress,
            isCompletedOneOff: store.task.isCompletedOneOff,
            isCanceledOneOff: store.task.isCanceledOneOff,
            isChecklistCompletionRoutine: isChecklistCompletion,
            isChecklistInProgress: isChecklistCompletion && store.state.isChecklistInProgress(referenceDate: store.resolvedSelectedDate),
            isChecklistDriven: isChecklistDriven,
            isDoneToday: store.isDoneToday,
            isAssumedDoneToday: store.isAssumedDoneToday,
            overdueDays: store.overdueDays,
            daysUntilDueIfActive: daysUntilDueIfActive,
            hasUnresolvedMissedExactTimedOccurrence: store.missedExactTimedOccurrenceDate != nil,
            isOrangeUrgency: !isChecklistCompletion
                && !isChecklistDriven
                && TaskDetailPresentation.isOrangeUrgency(store.task)
        )
    }

    func summaryStatusTitle(daysUntilDueIfActive: Int?) -> String {
        store.state.summaryStatusTitle(daysUntilDueIfActive: daysUntilDueIfActive)
    }

    var calendarIsOrangeUrgencyToday: Bool {
        guard !store.isChecklistDrivenFromStoredItems else { return false }
        return TaskDetailPresentation.isOrangeUrgency(store.task)
    }

    func daysUntilDueIfActive(from dueDate: Date?) -> Int? {
        guard !store.task.isArchived(),
            !store.task.isSoftIntervalRoutine,
            let dueDate
        else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: dueDate)
        ).day
    }

    var routineLogsBackground: Color {
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

import SwiftUI

extension TaskDetailTCAView {
    var todoDetailContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                todoHeaderSection
                doneOccurrenceSection
                notificationDisabledWarningSection
                if shouldShowCommentsSection {
                    commentsSection
                }
                if store.task.showsTaskDetailHistory {
                    historySection
                }
                if shouldShowChecklistSection {
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
                inlineEditSectionsView
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

    var headerSupplementaryContent: some View {
        headerSupplementaryContent(dueDate: store.resolvedDueDate)
    }

    func headerSupplementaryContent(dueDate: Date?) -> some View {
        TaskDetailMacHeaderSupplementaryContent(
            task: store.task,
            goals: isGoalsTabEnabled ? store.taskGoalSummaries : [],
            selectedDate: store.resolvedSelectedDate,
            showPersianDates: showPersianDates,
            isCalendarExpanded: $isCalendarExpanded,
            sectionCardStroke: TaskDetailPlatformStyle.sectionCardStroke,
            tagTint: { tagTint(for: $0) },
            onTagFilterSelected: onTagFilterSelected,
            calendarContent: {
                calendarSection(dueDate: dueDate)
            }
        )
    }

    @ViewBuilder
    var todoHeaderControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if shouldShowTimeSpentHeaderBox {
                todoTimeSpentHeaderBox
            }

            taskDetailStatusControls
            taskDetailTaskLadderValuesSection
        }
    }

    @ViewBuilder
    private var taskDetailStatusControls: some View {
        if shouldShowTodoStateControl {
            TaskDetailTodoStateSegmentedPicker(
                store: store,
                timingSummary: todoStateTimingSummary,
                showPersianDates: showPersianDates
            )
        }
    }

    private var taskDetailTaskLadderValuesSection: some View {
        TaskDetailTaskLadderValuesBox {
            TaskDetailTaskLadderValuesControlsGrid(store: store)

            if store.task.temporalWeightRule != nil {
                Text(
                    "Importance, Urgency, and Pressure show their After done values. "
                        + "Now follows each due-date rule, while Thinking stays fixed. "
                        + "Use Edit Task to change these values or their Changes over time rule."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Divider()
                TaskTemporalWeightSummaryCard(
                    task: store.task,
                    referenceDate: referenceDate
                )
            }

            if RoutineTaskLadderEntryPresentation.detailSummary(for: store.task) != nil {
                Divider()
                TaskLadderEntryWindowSummary(task: store.task)
            }
        }
    }

    private var shouldShowTimeControl: Bool {
        canShowTimeControl
            && (isTimeControlRevealed
                || TaskDetailOptionalControlVisibility.showsTimeSpent(
                    for: store.task,
                    hasActiveFocus: hasActiveFocusForTask,
                    showsFocusTimer: store.task.focusModeEnabled || hasCompletedFocusHistory
                ))
    }

    private var shouldShowTimeSpentHeaderBox: Bool {
        TaskDetailMacTimeControlPresentation.showsHeaderBox(
            for: store.task.scheduleMode.taskType,
            isTimeControlVisible: shouldShowTimeControl,
            hasEffortMetadata: hasEffortMetadata
        )
    }

    private var shouldShowTodoStateControl: Bool {
        canShowTodoStateControl
            && (isTodoStateControlRevealed
                || store.hasActiveRelationshipBlocker
                || TaskDetailOptionalControlVisibility.showsTodoState(for: store.task))
    }

    var shouldShowChecklistSection: Bool {
        isChecklistSectionRevealed || store.hasStoredChecklistItems
    }

    var shouldShowTodoStateAddAction: Bool {
        canShowTodoStateControl && !shouldShowTodoStateControl
    }

    var shouldShowTimeAddAction: Bool {
        TaskDetailMacTimeControlPresentation.showsAddAction(
            for: store.task.scheduleMode.taskType,
            isTimeControlVisible: shouldShowTimeControl,
            hasEffortMetadata: hasEffortMetadata
        )
    }

    private var canShowTimeControl: Bool {
        TaskDetailMacTimeControlPresentation.canShowTimeControl(
            for: store.task.scheduleMode.taskType
        )
    }

    private var hasEffortMetadata: Bool {
        store.task.estimatedDurationMinutes != nil || store.task.storyPoints != nil
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

    private var hasCompletedFocusHistory: Bool {
        focusSessions.contains { session in
            session.taskID == store.task.id && session.state == .completed
        }
    }

    var focusSessionCountForTask: Int {
        focusSessions.count { session in
            session.taskID == store.task.id
                && (session.state == .active || session.state == .completed)
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
            onEditTotal: beginEditingTaskTime
        )
    }

    @ViewBuilder
    var routineHeaderControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if shouldShowTimeSpentHeaderBox {
                todoTimeSpentHeaderBox
            }
            taskDetailStatusControls
            taskDetailTaskLadderValuesSection
        }
    }

    var taskDetailContent: some View {
        _ = store.taskRefreshID

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                routineHeaderSection
                doneOccurrenceSection
                notificationDisabledWarningSection
                if store.task.hasDestination {
                    destinationSection
                }
                if shouldShowFocusSessionSection {
                    focusSessionSection
                }
                if shouldShowCommentsSection {
                    commentsSection
                }
                if shouldShowHeatmapSection {
                    taskHeatmapSection
                }
                if store.task.showsTaskDetailHistory {
                    historySection
                }
                if shouldShowChecklistSection {
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
                inlineEditSectionsView
            }
            .padding(TaskDetailPlatformStyle.detailContentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var taskDetailActionCluster: some View {
        TaskDetailActionClusterView(
            store: store,
            style: presentation == .companionPane ? .companionPane : .fullDetail,
            showsEditButton: presentation.showsEditingEntryPoints,
            onExpandCompanion: presentation == .companionPane ? onExpandCompanion : nil,
            onMinimizeFullscreen: presentation == .fullDetail ? onMinimizeFullscreen : nil,
            onClose: presentation == .companionPane ? onCloseCompanion : onCloseFullscreen,
            isTaskSharingEnabled: presentation == .fullDetail && isTaskSharingEnabled,
            optionalDetailActions: presentation.showsEditingEntryPoints ? optionalDetailActions : []
        )
    }

    @ViewBuilder
    private var doneOccurrenceSection: some View {
        if let doneOccurrenceContext {
            TaskDetailDoneOccurrenceSection(
                task: store.task,
                date: doneOccurrenceContext.date,
                occurrence: doneOccurrenceContext.occurrence
            )
            .id(doneOccurrenceContext.occurrence.completedAt)
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

    private var destinationSection: some View {
        TaskDetailDestinationSectionView(
            address: store.task.destinationAddress,
            coordinate: store.task.destinationCoordinate,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke
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
            newCommentDraft: Binding(
                get: { store.detailCommentDraft },
                set: { store.send(.detailCommentDraftChanged($0)) }
            ),
            canAddComment: store.canAddDetailComment,
            editingCommentID: store.editingDetailCommentID,
            editingCommentDraft: Binding(
                get: { store.editingDetailCommentDraft },
                set: { store.send(.detailCommentEditDraftChanged($0)) }
            ),
            canSaveEditedComment: store.canSaveEditingDetailComment,
            isCommentComposerVisible: $isCommentComposerVisible,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            onAddComment: { store.send(.detailCommentAddTapped) },
            onEditComment: { store.send(.detailCommentEditTapped($0)) },
            onCancelEditComment: { store.send(.detailCommentEditCancelTapped) },
            onSaveEditComment: { store.send(.detailCommentEditSaveTapped($0)) },
            onDeleteComment: { store.send(.detailCommentDeleteTapped($0)) }
        )
        .id(store.task.id)
    }

}

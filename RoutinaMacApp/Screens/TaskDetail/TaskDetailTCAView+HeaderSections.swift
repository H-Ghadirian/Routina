import SwiftUI

extension TaskDetailTCAView {
    @ViewBuilder
    func detailOverviewSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        platformDetailOverviewSection(pauseArchivePresentation: pauseArchivePresentation)
    }

    var calendarSection: some View {
        calendarSection(dueDate: store.resolvedDueDate)
    }

    func calendarSection(dueDate: Date?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
                dueDate: dueDate,
                softDueDate: store.resolvedSoftDueDate,
                isOrangeUrgencyToday: calendarIsOrangeUrgencyToday,
                selectedDate: store.resolvedSelectedDate,
                onSelectDate: { store.send(.selectedDateChanged($0)) },
                onToday: {
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    displayedMonthStart = calendar.startOfMonth(for: today)
                    store.send(.selectedDateChanged(today))
                }
            )

            if let occurrence = store.selectedCalendarOccurrence {
                if occurrence.canMarkMissed || occurrence.canCancel {
                    Divider()
                        .padding(.horizontal, 12)

                    TaskDetailSelectedCalendarDayActions(
                        occurrence: occurrence,
                        onMarkMissed: {
                            store.send(.markOccurrenceMissed(occurrence.occurrence))
                        },
                        onCancel: {
                            store.send(.markOccurrenceCanceled(occurrence.occurrence))
                        }
                    )
                    .padding(12)
                }
            }
        }
        .routinaPlatformCalendarCardStyle()
    }

    func collapseDefaultSections() {
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

    var todoHeaderSection: some View {
        TaskDetailHeaderSectionView(
            title: store.task.name ?? "Task",
            titleDragPayload: taskTitlePlannerDragPayload,
            statusContextMessage: statusContextMessage,
            badgeRows: todoHeaderBadgeRows,
            tags: [],
            headerAccessory: {
                taskDetailActionCluster
            },
            titleSupplementaryContent: {
                taskSidebarLocationButton
            },
            tagChip: { tag in
                statusTagChip(tag)
            },
            additionalContent: {
                VStack(alignment: .leading, spacing: 8) {
                    todoHeaderControls
                    headerSupplementaryContent
                }
            }
        )
    }

    var routineHeaderSection: some View {
        let dueDate = store.resolvedDueDate
        let daysUntilDueIfActive = daysUntilDueIfActive(from: dueDate)
        let dueDateMetadataDisplayText = dueDateMetadataDisplayText(for: dueDate)
        let summaryStatusColor = summaryStatusColor(
            daysUntilDueIfActive: daysUntilDueIfActive
        )
        let summaryStatusTitle = summaryStatusTitle(
            daysUntilDueIfActive: daysUntilDueIfActive
        )

        return TaskDetailHeaderSectionView(
            title: store.task.name ?? "Repeating task",
            titleDragPayload: taskTitlePlannerDragPayload,
            statusContextMessage: statusContextMessage,
            badgeRows: routineHeaderBadgeRows(
                summaryStatusTitle: summaryStatusTitle,
                summaryStatusColor: summaryStatusColor,
                dueDateMetadataDisplayText: dueDateMetadataDisplayText
            ),
            tags: [],
            headerAccessory: {
                taskDetailActionCluster
            },
            titleSupplementaryContent: {
                taskSidebarLocationButton
            },
            tagChip: { tag in
                statusTagChip(tag)
            },
            additionalContent: {
                VStack(alignment: .leading, spacing: 8) {
                    routineHeaderControls
                    headerSupplementaryContent(dueDate: dueDate)
                }
            }
        )
    }

    @ViewBuilder
    private var taskSidebarLocationButton: some View {
        if let sidebarLocation, let onLocateInSidebar {
            Button(action: onLocateInSidebar) {
                HStack(spacing: 6) {
                    Image(systemName: "sidebar.left")
                        .foregroundStyle(.secondary)

                    ForEach(Array(sidebarLocation.titles.enumerated()), id: \.offset) { index, title in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }

                        Text(title)
                            .lineLimit(1)
                    }

                    Image(systemName: "arrow.up.left")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(.secondary.opacity(0.10))
                )
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Show this task in the left sidebar")
            .accessibilityLabel("Show task in sidebar")
            .accessibilityValue(sidebarLocation.accessibilityValue)
        }
    }

    private var taskTitlePlannerDragPayload: String? {
        allowsTitlePlannerDrag ? store.task.id.uuidString : nil
    }

    @ViewBuilder
    var notificationDisabledWarningSection: some View {
        if let warningText = store.notificationDisabledWarningText {
            if let actionTitle = store.notificationDisabledWarningActionTitle {
                TaskDetailNotificationDisabledWarningView(
                    warningText: warningText,
                    actionTitle: actionTitle
                ) {
                    store.send(.notificationDisabledWarningTapped)
                }
            }
        }
    }

    private var todoHeaderBadgeRows: [[TaskDetailHeaderBadgeItem]] {
        TaskDetailHeaderBadgePresentation.todoBadgeRows(
            state: store.state,
            summaryStatusColor: summaryStatusColor,
            dueDateMetadataDisplayText: dueDateMetadataDisplayText,
            layout: .desktop,
            showsPlaces: isPlacesEnabled
        )
    }

    private var routineHeaderBadgeRows: [[TaskDetailHeaderBadgeItem]] {
        let dueDate = store.resolvedDueDate
        let daysUntilDueIfActive = daysUntilDueIfActive(from: dueDate)
        return routineHeaderBadgeRows(
            summaryStatusTitle: summaryStatusTitle(daysUntilDueIfActive: daysUntilDueIfActive),
            summaryStatusColor: summaryStatusColor(daysUntilDueIfActive: daysUntilDueIfActive),
            dueDateMetadataDisplayText: dueDateMetadataDisplayText(for: dueDate)
        )
    }

    private func routineHeaderBadgeRows(
        summaryStatusTitle: String,
        summaryStatusColor: Color,
        dueDateMetadataDisplayText: String?
    ) -> [[TaskDetailHeaderBadgeItem]] {
        TaskDetailHeaderBadgePresentation.routineBadgeRows(
            state: store.state,
            summaryStatusTitle: summaryStatusTitle,
            summaryStatusColor: summaryStatusColor,
            dueDateMetadataDisplayText: dueDateMetadataDisplayText,
            layout: .desktop,
            showsPlaces: isPlacesEnabled
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

    var taskExtrasSection: some View {
        TaskDetailExtrasSectionView(
            imageData: store.task.imageData,
            voiceNote: isNotesEnabled ? store.task.voiceNote : nil,
            attachments: store.taskAttachments,
            taskDescription: store.task.taskDescription,
            notes: isNotesEnabled ? CalendarTaskImportSupport.displayNotes(from: store.task.notes) : nil,
            links: store.task.resolvedLinkURLs,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            onOpenImage: openTaskImage(data:),
            onSaveAttachment: saveAttachment(item:),
            onOpenAttachment: { openAttachment(data: $0.data, fileName: $0.fileName) }
        )
    }

    var linkedEventsSection: some View {
        TaskDetailLinkedEventsSectionView(
            events: store.taskEventCandidates,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            onOpenEvent: openLinkedEvent
        )
    }

    func openLinkedEvent(_ eventID: UUID) {
        guard areMacEventEmotionActionsEnabled else { return }
        if let onOpenEventDetails {
            selectedLinkedEventPresentation = nil
            onOpenEventDetails(eventID)
        } else {
            selectedLinkedEventPresentation = TaskDetailLinkedEventPresentation(id: eventID)
        }
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
        let dueDate = store.resolvedDueDate
        let daysUntilDueIfActive = daysUntilDueIfActive(from: dueDate)
        let dueDateMetadataDisplayText = dueDateMetadataDisplayText(for: dueDate)
        let summaryStatusColor = summaryStatusColor(
            daysUntilDueIfActive: daysUntilDueIfActive
        )
        let summaryStatusTitle = summaryStatusTitle(
            daysUntilDueIfActive: daysUntilDueIfActive
        )

        return TaskDetailStatusSectionView(
            title: summaryStatusTitle,
            titleColor: summaryStatusColor,
            statusContextMessage: statusContextMessage,
            titleFont: titleFont,
            showsMetadata: hasVisibleStatusMetadata,
            metadataItems: TaskDetailStatusMetadataPresentation.items(
                for: store.state,
                showSelectedDate: true,
                displayedActualDurationText: displayedActualDurationText,
                dueDateMetadataDisplayText: dueDateMetadataDisplayText,
                showsNotes: isNotesEnabled
            ),
            pauseArchivePresentation: pauseArchivePresentation,
            completionButtonTitle: store.completionButtonTitle,
            completionButtonSystemImage: store.completionButtonSystemImage,
            isOneOffTask: store.task.isOneOffTask,
            isArchived: store.task.isArchived(),
            isCompletionButtonDisabled: store.isCompletionButtonDisabled,
            isStepRoutineOffToday: store.isStepRoutineOffToday,
            isChecklistCompletionRoutine: store.isChecklistCompletionFromStoredItems,
            canUndoSelectedDate: store.canUndoSelectedDate,
            isSelectedDateAssumedDone: store.isSelectedDateAssumedDone,
            shouldShowBulkConfirmAssumedDays: store.shouldShowBulkConfirmAssumedDays,
            bulkConfirmAssumedDaysTitle: store.bulkConfirmAssumedDaysTitle,
            hasBlockingRelationships: !store.blockingRelationships.isEmpty,
            blockerSummaryText: store.blockerSummaryText,
            useLargePrimaryControl: useLargePrimaryControl,
            contentPadding: contentPadding,
            cardBackground: cardBackground,
            cardStroke: cardStroke,
            missedOccurrenceReview: store.missedOccurrenceReviewPresentation
        ) {
            timeSpentActionButton
        } onComplete: {
            store.send(store.completionButtonAction)
        } onResolveMissedAsDone: {
            store.send(.markOccurrenceDone($0))
        } onResolveMissedAsMissed: {
            store.send(.markOccurrenceMissed($0))
        } onResolveMissedAsCanceled: {
            store.send(.markOccurrenceCanceled($0))
        } onPauseResume: {
            store.send(store.task.isArchived() ? .resumeTapped : .pauseTapped)
        } onNotToday: {
            store.send(.notTodayTapped)
        } onConfirmAssumedPastDays: {
            store.send(.confirmAssumedPastDays)
        }
    }

    private func statusTagChip(_ tag: String) -> some View {
        TaskDetailMacFilterableTagChip(
            tag: tag,
            tint: tagTint(for: tag),
            onSelect: onTagFilterSelected
        )
    }

    func tagTint(for tag: String) -> Color {
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
        dueDateMetadataDisplayText(for: store.resolvedDueDate)
    }

    private func dueDateMetadataDisplayText(for dueDate: Date?) -> String? {
        let rawText = TaskDetailDateMetadataPresentation.dueDateMetadataText(
            dueDate: dueDate,
            isOneOffTask: store.task.isOneOffTask,
            usesExplicitTimeOfDay: store.task.recurrenceRule.usesTimeConstraint
        )
        return TaskDetailStatusMetadataPresentation.dueDateMetadataDisplayText(
            rawText: rawText,
            dueDate: dueDate,
            showPersianDates: showPersianDates
        )
    }

    private var hasVisibleStatusMetadata: Bool {
        TaskDetailStatusMetadataPresentation.hasVisibleMetadata(
            for: store.state,
            showsPlaces: isPlacesEnabled,
            showsNotes: isNotesEnabled
        )
    }

}

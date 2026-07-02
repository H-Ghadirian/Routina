import ComposableArchitecture
import Foundation
import SwiftData
import UserNotifications

struct TaskDetailFeature: Reducer {
    private enum CancelID {
        case loadContext
    }

    typealias EditFrequency = TaskFormFrequencyUnit

    @ObservableState
    struct State: Equatable {
        var task: RoutineTask
        var taskRefreshID: UInt64 = 0
        var logs: [RoutineLog] = []
        var pendingLocalCompletionDates: [Date] = []
        var pendingLocalRemovalDates: [Date] = []
        var selectedDate: Date?
        var daysSinceLastRoutine: Int = 0
        var overdueDays: Int = 0
        var isDoneToday: Bool = false
        var isAssumedDoneToday: Bool = false
        var isEditSheetPresented: Bool = false
        var editRoutineName: String = ""
        var editRoutineEmoji: String = "✨"
        var editRoutineNotes: String = ""
        var detailCommentDraft: String = ""
        var editingDetailCommentID: UUID?
        var editingDetailCommentDraft: String = ""
        var editRoutineLink: String = ""
        var editDeadline: Date?
        var editIsAllDay: Bool = false
        var editRoutineDurationMode: RoutineDurationMode = .oneDay
        var editAvailabilityStartDate: Date?
        var editAvailabilityEndDate: Date?
        var editPlannedDate: Date?
        var editReminderAt: Date?
        var editPriority: RoutineTaskPriority = .none
        var editImportance: RoutineTaskImportance = .level2
        var editUrgency: RoutineTaskUrgency = .level2
        var editPressure: RoutineTaskPressure = .none
        var editImageData: Data?
        var editVoiceNote: RoutineVoiceNote?
        var taskAttachments: [AttachmentItem] = []
        var editAttachments: [AttachmentItem] = []
        var editRoutineTags: [String] = []
        var editRoutineGoals: [RoutineGoalSummary] = []
        var editEventIDs: [UUID] = []
        var editRelationships: [RoutineTaskRelationship] = []
        var editTagDraft: String = ""
        var editGoalDraft: String = ""
        var editScheduleMode: RoutineScheduleMode = .fixedInterval
        var editRoutineSteps: [RoutineStep] = []
        var editStepDraft: String = ""
        var editRoutineChecklistItems: [RoutineChecklistItem] = []
        var editChecklistItemDraftTitle: String = ""
        var editChecklistItemDraftInterval: Int = 3
        var editChecklistValidationMessage: String?
        var availablePlaces: [RoutinePlaceSummary] = []
        var availableTags: [String] = []
        var availableGoals: [RoutineGoalSummary] = []
        var availableEvents: [RoutineEventLinkCandidate] = []
        var relatedTagRules: [RoutineRelatedTagRule] = []
        var availableRelationshipTasks: [RoutineTaskRelationshipCandidate] = []
        var editSelectedPlaceID: UUID?
        var editSelectedPlaceIDs: [UUID] = []
        var editFrequency: EditFrequency = .day
        var editFrequencyValue: Int = 1
        var editRecurrenceKind: RoutineRecurrenceRule.Kind = .intervalDays
        var editRecurrenceHasExplicitTime: Bool = false
        var editRecurrenceHasTimeRange: Bool = false
        var editRecurrenceTimeOfDay: RoutineTimeOfDay = .defaultValue
        var editRecurrenceTimeRangeStart: RoutineTimeOfDay = RoutineTimeRange.defaultValue.start
        var editRecurrenceTimeRangeEnd: RoutineTimeOfDay = RoutineTimeRange.defaultValue.end
        var editRecurrenceWeekday: Int = Calendar.current.component(.weekday, from: Date())
        var editRecurrenceWeekdays: [Int] = []
        var editRecurrenceDayOfMonth: Int = Calendar.current.component(.day, from: Date())
        var editAutoAssumeDailyDone: Bool = false
        var editAutoAssumeDoneTimeOfDay: RoutineTimeOfDay = RoutineAssumedCompletion.defaultDoneTimeOfDay
        var editEstimatedDurationMinutes: Int?
        var editActualDurationMinutes: Int?
        var editStoryPoints: Int?
        var editFocusModeEnabled: Bool = false
        var isDeleteConfirmationPresented: Bool = false
        var isUndoCompletionConfirmationPresented: Bool = false
        var pendingLogRemovalTimestamp: Date?
        var shouldDismissAfterDelete: Bool = false
        var addLinkedTaskRelationshipKind: RoutineTaskRelationshipKind = .related
        var editColor: RoutineTaskColor = .none
        var isBlockedStateConfirmationPresented: Bool = false
        var hasLoadedNotificationStatus: Bool = false
        var appNotificationsEnabled: Bool = true
        var systemNotificationsAuthorized: Bool = true

        var candidateRecurrenceRule: RoutineRecurrenceRule {
            let fallbackInterval = editScheduleMode == .oneOff
                ? 1
                : TaskFormRecurrenceConstraints.effectiveIntervalDays(
                    value: editFrequencyValue,
                    unit: editFrequency,
                    scheduleMode: editScheduleMode,
                    routineDurationMode: editRoutineDurationMode,
                    recurrenceKind: editRecurrenceKind
                )
            let usesAvailabilityTiming = !editIsAllDay
            let timeRange = usesAvailabilityTiming ? editRecurrenceTimeRange : nil

            guard editScheduleMode != .oneOff else {
                return .interval(
                    days: 1,
                    at: usesAvailabilityTiming && editRecurrenceHasExplicitTime ? editRecurrenceTimeOfDay : nil,
                    timeRange: timeRange
                )
            }

            guard !editScheduleMode.isChecklistDrivenMode else {
                return .interval(days: max(fallbackInterval, 1))
            }

            switch editRecurrenceKind {
            case .intervalDays:
                return .interval(
                    days: max(fallbackInterval, 1),
                    at: usesAvailabilityTiming && editRecurrenceHasExplicitTime ? editRecurrenceTimeOfDay : nil,
                    timeRange: timeRange
                )
            case .dailyTime:
                if let timeRange {
                    return .daily(in: timeRange)
                }
                return RoutineRecurrenceRule(
                    kind: .dailyTime,
                    timeOfDay: usesAvailabilityTiming && editRecurrenceHasExplicitTime ? editRecurrenceTimeOfDay : nil
                )
            case .weekly:
                return .weekly(
                    on: effectiveEditRecurrenceWeekdays,
                    at: usesAvailabilityTiming && editRecurrenceHasExplicitTime ? editRecurrenceTimeOfDay : nil,
                    timeRange: timeRange
                )
            case .monthlyDay:
                return .monthly(
                    on: editRecurrenceDayOfMonth,
                    at: usesAvailabilityTiming && editRecurrenceHasExplicitTime ? editRecurrenceTimeOfDay : nil,
                    timeRange: timeRange
                )
            }
        }

        var effectiveEditRecurrenceWeekdays: [Int] {
            let selectedWeekdays = Array(Set(editRecurrenceWeekdays.map { min(max($0, 1), 7) })).sorted()
            return selectedWeekdays.isEmpty ? [min(max(editRecurrenceWeekday, 1), 7)] : selectedWeekdays
        }

        var editRecurrenceTimeRange: RoutineTimeRange? {
            guard editRecurrenceHasTimeRange else { return nil }
            return RoutineTimeRange(
                start: editRecurrenceTimeRangeStart,
                end: editRecurrenceTimeRangeEnd
            )
        }

        var canAutoAssumeDailyDone: Bool {
            RoutineAssumedCompletion.isEligible(
                scheduleMode: editScheduleMode,
                recurrenceRule: candidateRecurrenceRule,
                hasSequentialSteps: !editRoutineSteps.isEmpty,
                hasChecklistItems: !editRoutineChecklistItems.isEmpty
            )
        }

        var canAddDetailComment: Bool {
            RoutineTaskComment.sanitizedBody(detailCommentDraft) != nil
        }

        var canSaveEditingDetailComment: Bool {
            guard let editingDetailCommentID,
                  let comment = task.comments.first(where: { $0.id == editingDetailCommentID }),
                  let body = RoutineTaskComment.sanitizedBody(editingDetailCommentDraft) else {
                return false
            }
            return body != comment.body
        }

        var taskGoalSummaries: [RoutineGoalSummary] {
            let resolvedGoals = RoutineGoalSummary.summaries(
                for: task.goalIDs,
                in: availableGoals
            )
            if !resolvedGoals.isEmpty || task.goalIDs.isEmpty {
                return resolvedGoals
            }
            return RoutineGoalSummary.summaries(
                for: task.goalIDs,
                in: editRoutineGoals
            )
        }

        var taskEventCandidates: [RoutineEventLinkCandidate] {
            RoutineEventLinkCandidate.selectedCandidates(
                for: task.eventIDs,
                in: availableEvents
            )
        }
    }

    enum Action: Equatable {
        case markAsDone
        case cancelTodo
        case toggleChecklistRunoutItemDone(UUID)
        case extendChecklistItemRunout(UUID)
        case toggleChecklistItemCompletion(UUID)
        case markChecklistItemCompleted(UUID)
        case detailAddChecklistItemTapped
        case detailUpdateChecklistItem(UUID, title: String, intervalDays: Int)
        case requestUndoSelectedDateCompletion
        case undoSelectedDateCompletion
        case requestRemoveLogEntry(Date)
        case removeLogEntry(Date)
        case updateTaskDuration(Int?)
        case updateLogDuration(UUID, Int?)
        case pauseTapped
        case notTodayTapped
        case resumeTapped
        case startOngoingTapped
        case finishOngoingTapped
        case selectedDateChanged(Date)
        case setEditSheet(Bool)
        case editRoutineNameChanged(String)
        case editRoutineEmojiChanged(String)
        case editRoutineNotesChanged(String)
        case detailCommentDraftChanged(String)
        case detailCommentAddTapped
        case detailCommentEditTapped(UUID)
        case detailCommentEditDraftChanged(String)
        case detailCommentEditCancelTapped
        case detailCommentEditSaveTapped(UUID)
        case detailCommentDeleteTapped(UUID)
        case editRoutineLinkChanged(String)
        case editDeadlineEnabledChanged(Bool)
        case editDeadlineDateChanged(Date)
        case editAllDayChanged(Bool)
        case editRoutineDurationModeChanged(RoutineDurationMode)
        case editAvailabilityStartDateChanged(Date?)
        case editAvailabilityEndDateChanged(Date?)
        case editPlannedDateChanged(Date?)
        case editReminderEnabledChanged(Bool)
        case editReminderDateChanged(Date)
        case editReminderLeadMinutesChanged(Int?)
        case editPriorityChanged(RoutineTaskPriority)
        case editImportanceChanged(RoutineTaskImportance)
        case editUrgencyChanged(RoutineTaskUrgency)
        case editPressureChanged(RoutineTaskPressure)
        case editImagePicked(Data?)
        case editRemoveImageTapped
        case editVoiceNoteChanged(RoutineVoiceNote?)
        case editAttachmentPicked(Data, String)
        case editRemoveAttachment(UUID)
        case attachmentsLoaded([AttachmentItem])
        case editTagDraftChanged(String)
        case editGoalDraftChanged(String)
        case editAddTagTapped
        case editAddGoalTapped
        case editRemoveTag(String)
        case editRemoveGoal(UUID)
        case editAddRelationship(UUID, RoutineTaskRelationshipKind)
        case editRemoveRelationship(UUID)
        case editTagRenamed(oldName: String, newName: String)
        case editTagDeleted(String)
        case editScheduleModeChanged(RoutineScheduleMode)
        case editStepDraftChanged(String)
        case editAddStepTapped
        case editRemoveStep(UUID)
        case editMoveStepUp(UUID)
        case editMoveStepDown(UUID)
        case editChecklistItemDraftTitleChanged(String)
        case editChecklistItemDraftIntervalChanged(Int)
        case editAddChecklistItemTapped
        case editRemoveChecklistItem(UUID)
        case availablePlacesLoaded([RoutinePlaceSummary])
        case availableTagsLoaded([String])
        case availableGoalsLoaded([RoutineGoalSummary])
        case availableEventsLoaded([RoutineEventLinkCandidate])
        case relatedTagRulesLoaded([RoutineRelatedTagRule])
        case availableRelationshipTasksLoaded([RoutineTaskRelationshipCandidate])
        case editSelectedPlaceChanged(UUID?)
        case editSelectedPlaceIDsChanged([UUID])
        case editToggleTagSelection(String)
        case editToggleGoalSelection(RoutineGoalSummary)
        case editToggleEventSelection(UUID)
        case editEstimatedDurationChanged(Int?)
        case editActualDurationChanged(Int?)
        case editStoryPointsChanged(Int?)
        case editFocusModeEnabledChanged(Bool)
        case editFrequencyChanged(EditFrequency)
        case editFrequencyValueChanged(Int)
        case editRecurrenceKindChanged(RoutineRecurrenceRule.Kind)
        case editRecurrenceHasExplicitTimeChanged(Bool)
        case editRecurrenceHasTimeRangeChanged(Bool)
        case editRecurrenceTimeOfDayChanged(RoutineTimeOfDay)
        case editRecurrenceTimeRangeStartChanged(RoutineTimeOfDay)
        case editRecurrenceTimeRangeEndChanged(RoutineTimeOfDay)
        case editRecurrenceWeekdayChanged(Int)
        case editRecurrenceWeekdaysChanged([Int])
        case editRecurrenceDayOfMonthChanged(Int)
        case editAutoAssumeDailyDoneChanged(Bool)
        case editAutoAssumeDoneTimeOfDayChanged(RoutineTimeOfDay)
        case editSaveTapped
        case confirmAssumedPastDays
        case setDeleteConfirmation(Bool)
        case setUndoCompletionConfirmation(Bool)
        case confirmUndoCompletion
        case deleteRoutineConfirmed
        case routineDeleted
        case deleteDismissHandled
        case logsLoaded([RoutineLog])
        case openLinkedTask(UUID)
        case addLinkedTaskRelationshipKindChanged(RoutineTaskRelationshipKind)
        case openAddLinkedTask
        case editColorChanged(RoutineTaskColor)
        case todoStateChanged(TodoState)
        case pressureChanged(RoutineTaskPressure)
        case importanceChanged(RoutineTaskImportance)
        case urgencyChanged(RoutineTaskUrgency)
        case setBlockedStateConfirmation(Bool)
        case confirmBlockedStateCompletion
        case notificationDisabledWarningTapped
        case notificationStatusLoaded(appEnabled: Bool, systemAuthorized: Bool)
        case onAppear
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.modelContext) var modelContext
    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.urlOpenerClient) var urlOpenerClient

    private func statusMutationHandler() -> TaskDetailStatusMutationHandler {
        TaskDetailStatusMutationHandler(
            now: { now },
            matrixPriority: { importance, urgency in
                matrixPriority(importance: importance, urgency: urgency)
            },
            appendLocalTodoStateChange: { task, previousStateTitle, newStateTitle in
                appendLocalTodoStateChange(
                    to: task,
                    previousStateTitle: previousStateTitle,
                    newStateTitle: newStateTitle
                )
            },
            refreshTaskView: { state in
                refreshTaskView(&state)
            },
            updateDerivedState: { state in
                updateDerivedState(&state)
            }
        )
    }

    private func statusActionHandler() -> TaskDetailStatusActionHandler {
        TaskDetailStatusActionHandler(
            mutationHandler: statusMutationHandler(),
            markAsDone: { state in
                reduce(into: &state, action: .markAsDone)
            },
            persistTodoStateChange: { request in
                handleTodoStateChanged(
                    taskID: request.taskID,
                    rawValue: request.rawValue,
                    pausedAt: request.pausedAt,
                    clearSnoozed: request.clearSnoozed,
                    previousStateTitle: request.previousStateTitle,
                    newStateTitle: request.newStateTitle
                )
            },
            persistPressureChange: { mutation in
                handlePressureChanged(taskID: mutation.taskID, pressure: mutation.pressure)
            },
            persistMatrixPositionChange: { mutation in
                handleMatrixPositionChanged(
                    taskID: mutation.taskID,
                    importance: mutation.importance,
                    urgency: mutation.urgency,
                    priority: mutation.priority
                )
            }
        )
    }

    private func editDraftMutationHandler() -> TaskDetailEditDraftMutationHandler {
        TaskDetailEditDraftMutationHandler(
            matrixPriority: { importance, urgency in
                matrixPriority(importance: importance, urgency: urgency)
            },
            refreshTaskView: { state in
                refreshTaskView(&state)
            }
        )
    }

    private func basicEditActionHandler() -> TaskDetailBasicEditActionHandler {
        TaskDetailBasicEditActionHandler(
            draftMutationHandler: editDraftMutationHandler()
        )
    }

    private func tagGoalRelationshipEditActionHandler() -> TaskDetailTagGoalRelationshipEditActionHandler {
        TaskDetailTagGoalRelationshipEditActionHandler(
            draftMutationHandler: editDraftMutationHandler()
        )
    }

    private func recurrenceEditActionHandler() -> TaskDetailRecurrenceEditActionHandler {
        TaskDetailRecurrenceEditActionHandler(
            now: { now },
            calendar: calendar
        )
    }

    private func stepChecklistEditActionHandler() -> TaskDetailStepChecklistEditActionHandler {
        TaskDetailStepChecklistEditActionHandler(now: { now })
    }

    private func editContextActionHandler() -> TaskDetailEditContextActionHandler {
        TaskDetailEditContextActionHandler()
    }

    private func dialogLifecycleActionHandler() -> TaskDetailDialogLifecycleActionHandler {
        TaskDetailDialogLifecycleActionHandler(
            calendar: calendar,
            syncEditFormFromTask: { state in
                syncEditFormFromTask(&state)
            },
            loadEditContext: { taskID in
                loadEditContext(excluding: taskID)
            }
        )
    }

    private func routineLifecycleActionHandler() -> TaskDetailRoutineLifecycleActionHandler {
        TaskDetailRoutineLifecycleActionHandler(
            now: { now },
            calendar: calendar,
            refreshTaskView: { state in
                refreshTaskView(&state)
            },
            updateDerivedState: { state in
                updateDerivedState(&state)
            },
            upsertLocalLog: { date, state in
                upsertLocalLog(at: date, in: &state)
            },
            persistPause: { taskID, pausedAt in
                handlePauseRoutine(taskID: taskID, pausedAt: pausedAt)
            },
            persistNotToday: { taskID, snoozedUntil in
                handleNotTodayRoutine(taskID: taskID, snoozedUntil: snoozedUntil)
            },
            persistResume: { taskID, resumedAt in
                handleResumeRoutine(taskID: taskID, resumedAt: resumedAt)
            },
            persistStartOngoing: { taskID, startedAt in
                handleStartOngoing(taskID: taskID, startedAt: startedAt)
            },
            persistFinishOngoing: { taskID, finishedAt in
                handleFinishOngoing(taskID: taskID, finishedAt: finishedAt)
            }
        )
    }

    private func completionLogActionHandler() -> TaskDetailCompletionLogActionHandler {
        TaskDetailCompletionLogActionHandler(
            now: { now },
            calendar: calendar,
            resolvedSelectedDay: { selectedDate in
                resolvedSelectedDay(for: selectedDate)
            },
            removePendingLocalCompletion: { day, state in
                removePendingLocalCompletion(on: day, from: &state)
            },
            trackPendingLocalRemoval: { day, state in
                trackPendingLocalRemoval(on: day, in: &state)
            },
            removeCompletion: { day, state in
                removeCompletion(on: day, from: &state)
            },
            removeLogEntryLocally: { timestamp, state in
                removeLogEntry(at: timestamp, from: &state)
            },
            logsPreservingPendingLocalCompletions: { logs, state in
                logsPreservingPendingLocalCompletions(logs, in: &state)
            },
            upsertLocalLog: { date, state in
                upsertLocalLog(at: date, in: &state)
            },
            refreshTaskView: { state in
                refreshTaskView(&state)
            },
            updateDerivedState: { state in
                updateDerivedState(&state)
            },
            persistUndoCompletion: { taskID, completedDay in
                handleUndoCompletion(taskID: taskID, completedDay: completedDay)
            },
            persistRemoveLogEntry: { taskID, timestamp in
                handleRemoveLogEntry(taskID: taskID, timestamp: timestamp)
            },
            persistLogDuration: { taskID, logID, previousDuration, duration in
                handleUpdateLogDuration(
                    taskID: taskID,
                    logID: logID,
                    previousDurationMinutes: previousDuration,
                    durationMinutes: duration
                )
            },
            persistTaskDuration: { taskID, previousDuration, duration in
                handleUpdateTaskDuration(
                    taskID: taskID,
                    previousDurationMinutes: previousDuration,
                    durationMinutes: duration
                )
            },
            persistConfirmAssumedPastDays: { taskID, days in
                handleConfirmAssumedPastDays(taskID: taskID, days: days)
            }
        )
    }

    private func editSaveRequestBuilder() -> TaskDetailEditSaveRequestBuilder {
        TaskDetailEditSaveRequestBuilder(
            now: { now },
            calendar: calendar,
            matrixPriority: { importance, urgency in
                matrixPriority(importance: importance, urgency: urgency)
            }
        )
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .markAsDone:
            guard !state.task.isArchived(referenceDate: now, calendar: calendar) else { return .none }
            guard !state.task.isCompletedOneOff else { return .none }
            guard !state.task.isCanceledOneOff else { return .none }
            if state.task.isChecklistDriven {
                guard let completionDate = resolvedRunoutActionDate(for: state.selectedDate) else { return .none }
                guard RoutineDateMath.canMarkDone(
                    for: state.task,
                    referenceDate: completionDate,
                    calendar: calendar
                ) else {
                    return .none
                }
                let dueItemIDs = Set(
                    state.task
                        .dueChecklistItems(referenceDate: completionDate, calendar: calendar)
                        .map(\.id)
                )
                let update = state.task.markChecklistItemsDone(
                    dueItemIDs,
                    doneAt: completionDate,
                    calendar: calendar
                )
                guard update.updatedItemCount > 0 else { return .none }
                refreshTaskView(&state)
                if update.didCompleteRoutine {
                    upsertLocalLog(at: completionDate, in: &state)
                }
                updateDerivedState(&state)
                return handleChecklistItemsDone(
                    taskID: state.task.id,
                    itemIDs: dueItemIDs,
                    doneAt: completionDate
                )
            }
            if state.task.isChecklistCompletionRoutine && !state.isSelectedDateAssumedDone {
                return .none
            }
            guard !state.task.blocksManualCompletionForIncompleteChecklist else {
                return .none
            }
            guard let completionDate = resolvedMarkAsDoneDate(
                for: state.selectedDate,
                task: state.task
            ) else {
                return .none
            }
            guard !state.task.hasSequentialSteps || calendar.isDate(completionDate, inSameDayAs: now) else {
                return .none
            }
            let isHistoricalCompletion = completionDate < now && !calendar.isDate(completionDate, inSameDayAs: now)
            let previousTodoStateTitle = state.task.isOneOffTask ? state.task.todoState?.displayTitle : nil
            if RoutineDateMath.usesExactTimedOccurrenceTracking(for: state.task) {
                guard RoutineDateMath.canMarkSelectedExactTimedOccurrenceDone(
                    for: state.task,
                    completionDate: completionDate,
                    referenceDate: now,
                    logs: state.logs,
                    calendar: calendar
                ) else {
                    return .none
                }
            } else {
                guard RoutineDateMath.canMarkDone(
                    for: state.task,
                    referenceDate: completionDate,
                    calendar: calendar,
                    ignoreArchiveAtReferenceDate: isHistoricalCompletion
                ) else {
                    return .none
                }
            }
            state.task.preserveCurrentScheduleAnchorForBackfill(
                completedAt: completionDate,
                referenceDate: now
            )
            let advanceResult = state.task.advance(completedAt: completionDate, calendar: calendar)
            if case .completedRoutine = advanceResult {
                _ = BatteryRoutineService.dismissCompletedLowBatteryPrompt(
                    for: state.task,
                    at: completionDate
                )
                upsertLocalLog(at: completionDate, in: &state)
                trackPendingLocalCompletion(at: completionDate, in: &state)
                appendLocalTodoStateChange(
                    to: state.task,
                    previousStateTitle: previousTodoStateTitle,
                    newStateTitle: TodoState.done.displayTitle
                )
            }
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handleMarkAsDone(
                taskID: state.task.id,
                completedAt: completionDate,
                referenceDate: now,
                previousStateTitle: previousTodoStateTitle
            )

        case .cancelTodo:
            guard state.task.isOneOffTask else { return .none }
            guard !state.task.isArchived(referenceDate: now, calendar: calendar) else { return .none }
            guard !state.task.isCompletedOneOff else { return .none }
            guard !state.task.isCanceledOneOff else { return .none }
            let canceledAt = resolvedCompletionDate(
                for: state.selectedDate,
                task: state.task
            )
            guard state.task.cancelOneOff(at: canceledAt) else { return .none }
            refreshTaskView(&state)
            upsertLocalLog(at: canceledAt, kind: .canceled, in: &state)
            updateDerivedState(&state)
            return handleCancelTodo(taskID: state.task.id, canceledAt: canceledAt)

        case let .toggleChecklistRunoutItemDone(itemID):
            guard !state.task.isArchived(referenceDate: now, calendar: calendar) else { return .none }
            guard let actionDate = resolvedRunoutActionDate(for: state.selectedDate) else { return .none }
            if let item = state.task.checklistItems.first(where: { $0.id == itemID }),
               TaskDetailChecklistPresentation.isRunoutItemMarkedDone(
                item,
                referenceDate: actionDate,
                calendar: calendar
               ) {
                let undoUpdate = state.task.undoChecklistItemRunoutDone(
                    itemID,
                    referenceDate: actionDate,
                    calendar: calendar
                )
                guard undoUpdate.restoredItemCount > 0 else { return .none }
                if let removedCompletionAt = undoUpdate.removedCompletionAt {
                    state.logs.removeAll { log in
                        log.kind == .completed && log.timestamp == removedCompletionAt
                    }
                }
                refreshTaskView(&state)
                updateDerivedState(&state)
                return handleChecklistItemRunoutDoneUndone(
                    taskID: state.task.id,
                    itemID: itemID,
                    undoneAt: actionDate
                )
            }

            let doneAt = actionDate
            let update = state.task.markChecklistItemsDone(
                [itemID],
                doneAt: doneAt,
                calendar: calendar
            )
            guard update.updatedItemCount > 0 else { return .none }
            refreshTaskView(&state)
            if update.didCompleteRoutine {
                upsertLocalLog(at: doneAt, in: &state)
            }
            updateDerivedState(&state)
            return handleChecklistItemsDone(
                taskID: state.task.id,
                itemIDs: [itemID],
                doneAt: doneAt
            )

        case let .extendChecklistItemRunout(itemID):
            guard !state.task.isArchived(referenceDate: now, calendar: calendar) else { return .none }
            guard let actionDate = resolvedRunoutActionDate(for: state.selectedDate) else { return .none }
            let extendedCount = state.task.extendChecklistItemsRunout(
                [itemID],
                referenceDate: actionDate,
                calendar: calendar
            )
            guard extendedCount > 0 else { return .none }
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handleChecklistItemRunoutExtended(
                taskID: state.task.id,
                itemID: itemID,
                extendedAt: actionDate
            )

        case let .toggleChecklistItemCompletion(itemID):
            guard !state.task.isArchived(referenceDate: now, calendar: calendar) else { return .none }
            guard calendar.isDate(state.selectedDate ?? now, inSameDayAs: now) else {
                return .none
            }
            if state.task.supportsOptionalChecklistProgress {
                let referenceDate = now
                if state.task.isChecklistItemCompleted(itemID) {
                    guard state.task.unmarkChecklistItemCompleted(itemID) else { return .none }
                    refreshTaskView(&state)
                    updateDerivedState(&state)
                    return handleOptionalChecklistItemUnmarked(
                        taskID: state.task.id,
                        itemID: itemID
                    )
                }

                guard state.task.markOptionalChecklistItemCompleted(itemID) else { return .none }
                refreshTaskView(&state)
                updateDerivedState(&state)
                return handleOptionalChecklistItemCompleted(
                    taskID: state.task.id,
                    itemID: itemID,
                    completedAt: referenceDate
                )
            }
            let referenceDate = now
            if state.task.isChecklistCompletionRoutine,
               state.isDoneToday,
               state.task.checklistItems.contains(where: { $0.id == itemID }) {
                return .none
            }
            if state.task.isChecklistItemCompleted(itemID, referenceDate: referenceDate, calendar: calendar) {
                guard state.task.isChecklistInProgress(referenceDate: referenceDate, calendar: calendar) else { return .none }
                guard state.task.unmarkChecklistItemCompleted(itemID) else { return .none }
                refreshTaskView(&state)
                updateDerivedState(&state)
                return handleChecklistItemUnmarked(
                    taskID: state.task.id,
                    itemID: itemID,
                    referenceDate: referenceDate
                )
            }

            let result = state.task.markChecklistItemCompleted(
                itemID,
                completedAt: referenceDate,
                calendar: calendar
            )
            switch result {
            case .ignoredPaused, .ignoredAlreadyCompletedToday:
                return .none

            case .advancedChecklist:
                refreshTaskView(&state)
                updateDerivedState(&state)
                return handleChecklistItemCompleted(
                    taskID: state.task.id,
                    itemID: itemID,
                    completedAt: referenceDate
                )

            case .completedRoutine:
                refreshTaskView(&state)
                upsertLocalLog(at: referenceDate, in: &state)
                updateDerivedState(&state)
                return handleChecklistItemCompleted(
                    taskID: state.task.id,
                    itemID: itemID,
                    completedAt: referenceDate
                )

            case .advancedStep:
                return .none
            }

        case let .markChecklistItemCompleted(itemID):
            guard !state.task.isArchived(referenceDate: now, calendar: calendar) else { return .none }
            guard calendar.isDate(state.selectedDate ?? now, inSameDayAs: now) else {
                return .none
            }
            let completionDate = now
            if state.task.supportsOptionalChecklistProgress {
                guard state.task.markOptionalChecklistItemCompleted(itemID) else { return .none }
                refreshTaskView(&state)
                updateDerivedState(&state)
                return handleOptionalChecklistItemCompleted(
                    taskID: state.task.id,
                    itemID: itemID,
                    completedAt: completionDate
                )
            }
            let result = state.task.markChecklistItemCompleted(
                itemID,
                completedAt: completionDate,
                calendar: calendar
            )
            switch result {
            case .ignoredPaused, .ignoredAlreadyCompletedToday:
                return .none

            case .advancedChecklist:
                refreshTaskView(&state)
                updateDerivedState(&state)
                return handleChecklistItemCompleted(
                    taskID: state.task.id,
                    itemID: itemID,
                    completedAt: completionDate
                )

            case .completedRoutine:
                refreshTaskView(&state)
                upsertLocalLog(at: completionDate, in: &state)
                updateDerivedState(&state)
                return handleChecklistItemCompleted(
                    taskID: state.task.id,
                    itemID: itemID,
                    completedAt: completionDate
                )

            case .advancedStep:
                return .none
            }

        case .detailAddChecklistItemTapped:
            guard let title = RoutineChecklistItem.normalizedTitle(state.editChecklistItemDraftTitle) else {
                return .none
            }
            let existingChecklistItems = state.task.checklistItems
            let candidateItem = RoutineChecklistItem(
                title: title,
                intervalDays: state.editChecklistItemDraftInterval,
                createdAt: now
            )
            let candidateItems = RoutineChecklistItem.sanitized(existingChecklistItems + [candidateItem])
            let updatedScheduleMode = TaskDetailRoutineChecklistModeNormalizer.effectiveScheduleMode(
                currentMode: state.task.scheduleMode,
                existingChecklistItems: existingChecklistItems,
                candidateChecklistItems: candidateItems,
                candidateSteps: state.task.steps
            )
            let updatedItems = RoutineChecklistItem.sanitized(candidateItems, for: updatedScheduleMode)
            state.task.scheduleMode = updatedScheduleMode
            state.task.replaceChecklistItems(updatedItems)
            state.editRoutineChecklistItems = updatedItems
            state.editScheduleMode = updatedScheduleMode
            state.editChecklistItemDraftTitle = ""
            state.editChecklistItemDraftInterval = updatedScheduleMode.storesChecklistItemIntervals ? 3 : 1
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handleDetailChecklistItemsChanged(
                taskID: state.task.id,
                checklistItems: updatedItems,
                scheduleMode: updatedScheduleMode
            )

        case let .detailUpdateChecklistItem(itemID, draftTitle, intervalDays):
            guard let title = RoutineChecklistItem.normalizedTitle(draftTitle),
                  state.task.checklistItems.contains(where: { $0.id == itemID }) else {
                return .none
            }
            let updatedItems = RoutineChecklistItem.sanitized(
                state.task.checklistItems.map { item in
                    guard item.id == itemID else { return item }
                    return RoutineChecklistItem(
                        id: item.id,
                        title: title,
                        intervalDays: state.task.scheduleMode.normalizedChecklistItemIntervalDays(intervalDays),
                        lastPurchasedAt: item.lastPurchasedAt,
                        undoLastPurchasedAt: item.undoLastPurchasedAt,
                        undoTaskLastDone: item.undoTaskLastDone,
                        undoTaskScheduleAnchor: item.undoTaskScheduleAnchor,
                        createdAt: item.createdAt
                    )
                }
            )
            state.task.replaceChecklistItems(updatedItems)
            state.editRoutineChecklistItems = updatedItems
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handleDetailChecklistItemsChanged(
                taskID: state.task.id,
                checklistItems: updatedItems
            )

        case .undoSelectedDateCompletion:
            return completionLogActionHandler().undoSelectedDateCompletion(state: &state)

        case .requestUndoSelectedDateCompletion:
            return dialogLifecycleActionHandler().requestUndoSelectedDateCompletion(state: &state)

        case let .removeLogEntry(timestamp):
            return completionLogActionHandler().removeLogEntry(timestamp, state: &state)

        case let .updateLogDuration(logID, durationMinutes):
            return completionLogActionHandler().updateLogDuration(
                logID: logID,
                durationMinutes: durationMinutes,
                state: &state
            )

        case let .updateTaskDuration(durationMinutes):
            return completionLogActionHandler().updateTaskDuration(durationMinutes, state: &state)

        case let .requestRemoveLogEntry(timestamp):
            return dialogLifecycleActionHandler().requestRemoveLogEntry(timestamp, state: &state)

        case .pauseTapped:
            return routineLifecycleActionHandler().pauseTapped(state: &state)

        case .notTodayTapped:
            return routineLifecycleActionHandler().notTodayTapped(state: &state)

        case .resumeTapped:
            return routineLifecycleActionHandler().resumeTapped(state: &state)

        case .startOngoingTapped:
            return routineLifecycleActionHandler().startOngoingTapped(state: &state)

        case .finishOngoingTapped:
            return routineLifecycleActionHandler().finishOngoingTapped(state: &state)

        case let .selectedDateChanged(date):
            return dialogLifecycleActionHandler().selectedDateChanged(date, state: &state)

        case let .setEditSheet(isPresented):
            return dialogLifecycleActionHandler().setEditSheet(isPresented, state: &state)

        case let .editRoutineNameChanged(name):
            return basicEditActionHandler().editRoutineNameChanged(name, state: &state)

        case let .editRoutineEmojiChanged(emoji):
            return basicEditActionHandler().editRoutineEmojiChanged(emoji, state: &state)

        case let .editRoutineNotesChanged(notes):
            return basicEditActionHandler().editRoutineNotesChanged(notes, state: &state)

        case let .detailCommentDraftChanged(comment):
            state.detailCommentDraft = comment
            return .none

        case .detailCommentAddTapped:
            guard let body = RoutineTaskComment.sanitizedBody(state.detailCommentDraft) else { return .none }
            let comment = RoutineTaskComment(body: body, createdAt: now)
            var comments = state.task.comments
            comments.append(comment)
            state.task.comments = comments
            state.detailCommentDraft = ""
            refreshTaskView(&state)
            return handleDetailCommentsChanged(taskID: state.task.id, comments: state.task.comments)

        case let .detailCommentEditTapped(commentID):
            guard let comment = state.task.comments.first(where: { $0.id == commentID }) else { return .none }
            state.editingDetailCommentID = commentID
            state.editingDetailCommentDraft = comment.body
            return .none

        case let .detailCommentEditDraftChanged(comment):
            state.editingDetailCommentDraft = comment
            return .none

        case .detailCommentEditCancelTapped:
            state.editingDetailCommentID = nil
            state.editingDetailCommentDraft = ""
            return .none

        case let .detailCommentEditSaveTapped(commentID):
            guard state.editingDetailCommentID == commentID,
                  let body = RoutineTaskComment.sanitizedBody(state.editingDetailCommentDraft),
                  let index = state.task.comments.firstIndex(where: { $0.id == commentID }) else {
                return .none
            }
            guard state.task.comments[index].body != body else {
                state.editingDetailCommentID = nil
                state.editingDetailCommentDraft = ""
                return .none
            }
            var comments = state.task.comments
            comments[index].body = body
            comments[index].updatedAt = now
            state.task.comments = comments
            state.editingDetailCommentID = nil
            state.editingDetailCommentDraft = ""
            refreshTaskView(&state)
            return handleDetailCommentsChanged(taskID: state.task.id, comments: state.task.comments)

        case let .detailCommentDeleteTapped(commentID):
            let currentComments = state.task.comments
            let comments = currentComments.filter { $0.id != commentID }
            guard comments.count != currentComments.count else { return .none }
            state.task.comments = comments
            if state.editingDetailCommentID == commentID {
                state.editingDetailCommentID = nil
                state.editingDetailCommentDraft = ""
            }
            refreshTaskView(&state)
            return handleDetailCommentsChanged(taskID: state.task.id, comments: comments)

        case let .editRoutineLinkChanged(link):
            return basicEditActionHandler().editRoutineLinkChanged(link, state: &state)

        case let .editDeadlineEnabledChanged(isEnabled):
            return recurrenceEditActionHandler().editDeadlineEnabledChanged(isEnabled, state: &state)

        case let .editDeadlineDateChanged(deadline):
            return recurrenceEditActionHandler().editDeadlineDateChanged(deadline, state: &state)

        case let .editAllDayChanged(isAllDay):
            return recurrenceEditActionHandler().editAllDayChanged(isAllDay, state: &state)

        case let .editRoutineDurationModeChanged(durationMode):
            return recurrenceEditActionHandler().editRoutineDurationModeChanged(durationMode, state: &state)

        case let .editAvailabilityStartDateChanged(availabilityStartDate):
            return recurrenceEditActionHandler().editAvailabilityStartDateChanged(
                availabilityStartDate,
                state: &state
            )

        case let .editAvailabilityEndDateChanged(availabilityEndDate):
            return recurrenceEditActionHandler().editAvailabilityEndDateChanged(
                availabilityEndDate,
                state: &state
            )

        case let .editPlannedDateChanged(plannedDate):
            return recurrenceEditActionHandler().editPlannedDateChanged(plannedDate, state: &state)

        case let .editReminderEnabledChanged(isEnabled):
            return recurrenceEditActionHandler().editReminderEnabledChanged(isEnabled, state: &state)

        case let .editReminderDateChanged(reminderDate):
            return recurrenceEditActionHandler().editReminderDateChanged(reminderDate, state: &state)

        case let .editReminderLeadMinutesChanged(leadMinutes):
            return recurrenceEditActionHandler().editReminderLeadMinutesChanged(
                leadMinutes,
                state: &state
            )

        case let .editPriorityChanged(priority):
            return basicEditActionHandler().editPriorityChanged(priority, state: &state)

        case let .editImportanceChanged(importance):
            return basicEditActionHandler().editImportanceChanged(importance, state: &state)

        case let .editUrgencyChanged(urgency):
            return basicEditActionHandler().editUrgencyChanged(urgency, state: &state)

        case let .editPressureChanged(pressure):
            return basicEditActionHandler().editPressureChanged(pressure, state: &state)

        case let .editImagePicked(data):
            return basicEditActionHandler().editImagePicked(data, state: &state)

        case .editRemoveImageTapped:
            return basicEditActionHandler().editRemoveImageTapped(state: &state)

        case let .editVoiceNoteChanged(voiceNote):
            return basicEditActionHandler().editVoiceNoteChanged(voiceNote, state: &state)

        case let .editAttachmentPicked(data, fileName):
            return basicEditActionHandler().editAttachmentPicked(
                data: data,
                fileName: fileName,
                state: &state
            )

        case let .editRemoveAttachment(id):
            return basicEditActionHandler().editRemoveAttachment(id, state: &state)

        case let .attachmentsLoaded(items):
            return basicEditActionHandler().attachmentsLoaded(items, state: &state)

        case let .editTagDraftChanged(value):
            return tagGoalRelationshipEditActionHandler().editTagDraftChanged(value, state: &state)

        case let .editGoalDraftChanged(value):
            return tagGoalRelationshipEditActionHandler().editGoalDraftChanged(value, state: &state)

        case .editAddTagTapped:
            return tagGoalRelationshipEditActionHandler().editAddTagTapped(state: &state)

        case .editAddGoalTapped:
            return tagGoalRelationshipEditActionHandler().editAddGoalTapped(state: &state)

        case let .editRemoveTag(tag):
            return tagGoalRelationshipEditActionHandler().editRemoveTag(tag, state: &state)

        case let .editRemoveGoal(goalID):
            return tagGoalRelationshipEditActionHandler().editRemoveGoal(goalID, state: &state)

        case let .editAddRelationship(taskID, kind):
            return tagGoalRelationshipEditActionHandler().editAddRelationship(
                taskID: taskID,
                kind: kind,
                state: &state
            )

        case let .editRemoveRelationship(taskID):
            return tagGoalRelationshipEditActionHandler().editRemoveRelationship(taskID, state: &state)

        case let .editTagRenamed(oldName, newName):
            return tagGoalRelationshipEditActionHandler().editTagRenamed(
                oldName: oldName,
                newName: newName,
                state: &state
            )

        case let .editTagDeleted(tag):
            return tagGoalRelationshipEditActionHandler().editTagDeleted(tag, state: &state)

        case let .editScheduleModeChanged(mode):
            return recurrenceEditActionHandler().editScheduleModeChanged(mode, state: &state)

        case let .editStepDraftChanged(value):
            return stepChecklistEditActionHandler().editStepDraftChanged(value, state: &state)

        case .editAddStepTapped:
            return stepChecklistEditActionHandler().editAddStepTapped(state: &state)

        case let .editRemoveStep(stepID):
            return stepChecklistEditActionHandler().editRemoveStep(stepID, state: &state)

        case let .editMoveStepUp(stepID):
            return stepChecklistEditActionHandler().editMoveStepUp(stepID, state: &state)

        case let .editMoveStepDown(stepID):
            return stepChecklistEditActionHandler().editMoveStepDown(stepID, state: &state)

        case let .editChecklistItemDraftTitleChanged(value):
            return stepChecklistEditActionHandler().editChecklistItemDraftTitleChanged(
                value,
                state: &state
            )

        case let .editChecklistItemDraftIntervalChanged(value):
            return stepChecklistEditActionHandler().editChecklistItemDraftIntervalChanged(
                value,
                state: &state
            )

        case .editAddChecklistItemTapped:
            return stepChecklistEditActionHandler().editAddChecklistItemTapped(state: &state)

        case let .editRemoveChecklistItem(itemID):
            return stepChecklistEditActionHandler().editRemoveChecklistItem(itemID, state: &state)

        case let .availablePlacesLoaded(places):
            return editContextActionHandler().availablePlacesLoaded(places, state: &state)

        case let .availableTagsLoaded(tags):
            return editContextActionHandler().availableTagsLoaded(tags, state: &state)

        case let .availableGoalsLoaded(goals):
            return editContextActionHandler().availableGoalsLoaded(goals, state: &state)

        case let .availableEventsLoaded(events):
            return editContextActionHandler().availableEventsLoaded(events, state: &state)

        case let .relatedTagRulesLoaded(rules):
            return editContextActionHandler().relatedTagRulesLoaded(rules, state: &state)

        case let .availableRelationshipTasksLoaded(tasks):
            return editContextActionHandler().availableRelationshipTasksLoaded(tasks, state: &state)

        case let .editSelectedPlaceChanged(placeID):
            return tagGoalRelationshipEditActionHandler().editSelectedPlaceChanged(
                placeID,
                state: &state
            )

        case let .editSelectedPlaceIDsChanged(placeIDs):
            return tagGoalRelationshipEditActionHandler().editSelectedPlaceIDsChanged(
                placeIDs,
                state: &state
            )

        case let .editToggleTagSelection(tag):
            return tagGoalRelationshipEditActionHandler().editToggleTagSelection(
                tag,
                state: &state
            )

        case let .editToggleGoalSelection(goal):
            return tagGoalRelationshipEditActionHandler().editToggleGoalSelection(
                goal,
                state: &state
            )

        case let .editToggleEventSelection(eventID):
            return tagGoalRelationshipEditActionHandler().editToggleEventSelection(
                eventID,
                state: &state
            )

        case let .editEstimatedDurationChanged(estimatedDurationMinutes):
            return basicEditActionHandler().editEstimatedDurationChanged(
                estimatedDurationMinutes,
                state: &state
            )

        case let .editActualDurationChanged(actualDurationMinutes):
            return basicEditActionHandler().editActualDurationChanged(
                actualDurationMinutes,
                state: &state
            )

        case let .editStoryPointsChanged(storyPoints):
            return basicEditActionHandler().editStoryPointsChanged(storyPoints, state: &state)

        case let .editFocusModeEnabledChanged(isEnabled):
            return basicEditActionHandler().editFocusModeEnabledChanged(isEnabled, state: &state)

        case let .editFrequencyChanged(frequency):
            return recurrenceEditActionHandler().editFrequencyChanged(frequency, state: &state)

        case let .editFrequencyValueChanged(value):
            return recurrenceEditActionHandler().editFrequencyValueChanged(value, state: &state)

        case let .editRecurrenceKindChanged(kind):
            return recurrenceEditActionHandler().editRecurrenceKindChanged(kind, state: &state)

        case let .editRecurrenceHasExplicitTimeChanged(hasExplicitTime):
            return recurrenceEditActionHandler().editRecurrenceHasExplicitTimeChanged(
                hasExplicitTime,
                state: &state
            )

        case let .editRecurrenceHasTimeRangeChanged(hasTimeRange):
            return recurrenceEditActionHandler().editRecurrenceHasTimeRangeChanged(
                hasTimeRange,
                state: &state
            )

        case let .editRecurrenceTimeOfDayChanged(timeOfDay):
            return recurrenceEditActionHandler().editRecurrenceTimeOfDayChanged(
                timeOfDay,
                state: &state
            )

        case let .editRecurrenceTimeRangeStartChanged(timeOfDay):
            return recurrenceEditActionHandler().editRecurrenceTimeRangeStartChanged(
                timeOfDay,
                state: &state
            )

        case let .editRecurrenceTimeRangeEndChanged(timeOfDay):
            return recurrenceEditActionHandler().editRecurrenceTimeRangeEndChanged(
                timeOfDay,
                state: &state
            )

        case let .editRecurrenceWeekdayChanged(weekday):
            return recurrenceEditActionHandler().editRecurrenceWeekdayChanged(
                weekday,
                state: &state
            )

        case let .editRecurrenceWeekdaysChanged(weekdays):
            return recurrenceEditActionHandler().editRecurrenceWeekdaysChanged(
                weekdays,
                state: &state
            )

        case let .editRecurrenceDayOfMonthChanged(dayOfMonth):
            return recurrenceEditActionHandler().editRecurrenceDayOfMonthChanged(
                dayOfMonth,
                state: &state
            )

        case let .editAutoAssumeDailyDoneChanged(isEnabled):
            return recurrenceEditActionHandler().editAutoAssumeDailyDoneChanged(
                isEnabled,
                state: &state
            )

        case let .editAutoAssumeDoneTimeOfDayChanged(timeOfDay):
            return recurrenceEditActionHandler().editAutoAssumeDoneTimeOfDayChanged(
                timeOfDay,
                state: &state
            )

        case .editSaveTapped:
            guard let request = editSaveRequestBuilder().build(state: &state) else { return .none }
            return handleEditSave(request)

        case .confirmAssumedPastDays:
            return completionLogActionHandler().confirmAssumedPastDays(state: &state)

        case let .setDeleteConfirmation(isPresented):
            return dialogLifecycleActionHandler().setDeleteConfirmation(isPresented, state: &state)

        case let .setUndoCompletionConfirmation(isPresented):
            return dialogLifecycleActionHandler().setUndoCompletionConfirmation(
                isPresented,
                state: &state
            )

        case .confirmUndoCompletion:
            return completionLogActionHandler().confirmUndoCompletion(state: &state)

        case .deleteRoutineConfirmed:
            state.isDeleteConfirmationPresented = false
            return handleDeleteRoutine(taskID: state.task.id)

        case .routineDeleted:
            return dialogLifecycleActionHandler().routineDeleted(state: &state)

        case .deleteDismissHandled:
            return dialogLifecycleActionHandler().deleteDismissHandled(state: &state)

        case let .logsLoaded(logs):
            return completionLogActionHandler().logsLoaded(logs, state: &state)

        case .openLinkedTask:
            return .none

        case let .addLinkedTaskRelationshipKindChanged(kind):
            return tagGoalRelationshipEditActionHandler().addLinkedTaskRelationshipKindChanged(
                kind,
                state: &state
            )

        case .openAddLinkedTask:
            return .none

        case let .editColorChanged(color):
            return basicEditActionHandler().editColorChanged(color, state: &state)

        case let .todoStateChanged(newState):
            return statusActionHandler().todoStateChanged(newState, state: &state)

        case let .pressureChanged(pressure):
            return statusActionHandler().pressureChanged(pressure, state: &state)

        case let .importanceChanged(importance):
            return statusActionHandler().importanceChanged(importance, state: &state)

        case let .urgencyChanged(urgency):
            return statusActionHandler().urgencyChanged(urgency, state: &state)

        case let .setBlockedStateConfirmation(isPresented):
            return statusActionHandler().setBlockedStateConfirmation(isPresented, state: &state)

        case .confirmBlockedStateCompletion:
            return statusActionHandler().confirmBlockedStateCompletion(state: &state)

        case .notificationDisabledWarningTapped:
            return TaskDetailNotificationActionHandler.notificationDisabledWarningTapped(
                state: &state,
                now: { now },
                calendar: { calendar },
                notificationClient: { self.notificationClient },
                appSettingsClient: { self.appSettingsClient },
                urlOpenerClient: { self.urlOpenerClient }
            )

        case let .notificationStatusLoaded(appEnabled, systemAuthorized):
            return TaskDetailNotificationActionHandler.notificationStatusLoaded(
                appEnabled: appEnabled,
                systemAuthorized: systemAuthorized,
                state: &state
            )

        case .onAppear:
            if state.selectedDate == nil {
                state.selectedDate = calendar.startOfDay(for: now)
            }
            updateDerivedState(&state)
            return .concatenate(
                loadEditContext(excluding: state.task.id),
                handleOnAppear(taskID: state.task.id)
            )
            .cancellable(id: CancelID.loadContext, cancelInFlight: true)
        }
    }

}

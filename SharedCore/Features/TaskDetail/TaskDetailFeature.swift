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
        var selectedDate: Date?
        var daysSinceLastRoutine: Int = 0
        var overdueDays: Int = 0
        var isDoneToday: Bool = false
        var isAssumedDoneToday: Bool = false
        var isEditSheetPresented: Bool = false
        var editRoutineName: String = ""
        var editRoutineEmoji: String = "✨"
        var editRoutineNotes: String = ""
        var editRoutineLink: String = ""
        var editDeadline: Date?
        var editReminderAt: Date?
        var editPriority: RoutineTaskPriority = .none
        var editImportance: RoutineTaskImportance = .level2
        var editUrgency: RoutineTaskUrgency = .level2
        var editPressure: RoutineTaskPressure = .none
        var editImageData: Data?
        var taskAttachments: [AttachmentItem] = []
        var editAttachments: [AttachmentItem] = []
        var editRoutineTags: [String] = []
        var editRoutineGoals: [RoutineGoalSummary] = []
        var editRelationships: [RoutineTaskRelationship] = []
        var editTagDraft: String = ""
        var editGoalDraft: String = ""
        var editScheduleMode: RoutineScheduleMode = .fixedInterval
        var editRoutineSteps: [RoutineStep] = []
        var editStepDraft: String = ""
        var editRoutineChecklistItems: [RoutineChecklistItem] = []
        var editChecklistItemDraftTitle: String = ""
        var editChecklistItemDraftInterval: Int = 3
        var availablePlaces: [RoutinePlaceSummary] = []
        var availableTags: [String] = []
        var availableGoals: [RoutineGoalSummary] = []
        var relatedTagRules: [RoutineRelatedTagRule] = []
        var availableRelationshipTasks: [RoutineTaskRelationshipCandidate] = []
        var editSelectedPlaceID: UUID?
        var editFrequency: EditFrequency = .day
        var editFrequencyValue: Int = 1
        var editRecurrenceKind: RoutineRecurrenceRule.Kind = .intervalDays
        var editRecurrenceHasExplicitTime: Bool = false
        var editRecurrenceTimeOfDay: RoutineTimeOfDay = .defaultValue
        var editRecurrenceWeekday: Int = Calendar.current.component(.weekday, from: Date())
        var editRecurrenceDayOfMonth: Int = Calendar.current.component(.day, from: Date())
        var editAutoAssumeDailyDone: Bool = false
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
                : editFrequencyValue * editFrequency.daysMultiplier

            guard editScheduleMode != .oneOff else {
                return .interval(days: 1)
            }

            guard editScheduleMode != .softInterval else {
                return .interval(days: max(fallbackInterval, 1))
            }

            guard editScheduleMode != .derivedFromChecklist else {
                return .interval(days: max(fallbackInterval, 1))
            }

            switch editRecurrenceKind {
            case .intervalDays:
                return .interval(days: max(fallbackInterval, 1))
            case .dailyTime:
                return .daily(at: editRecurrenceTimeOfDay)
            case .weekly:
                return .weekly(
                    on: editRecurrenceWeekday,
                    at: editRecurrenceHasExplicitTime ? editRecurrenceTimeOfDay : nil
                )
            case .monthlyDay:
                return .monthly(
                    on: editRecurrenceDayOfMonth,
                    at: editRecurrenceHasExplicitTime ? editRecurrenceTimeOfDay : nil
                )
            }
        }

        var canAutoAssumeDailyDone: Bool {
            RoutineAssumedCompletion.isEligible(
                scheduleMode: editScheduleMode,
                recurrenceRule: candidateRecurrenceRule,
                hasSequentialSteps: !editRoutineSteps.isEmpty,
                hasChecklistItems: !editRoutineChecklistItems.isEmpty
            )
        }
    }

    enum Action: Equatable {
        case markAsDone
        case cancelTodo
        case markChecklistItemPurchased(UUID)
        case toggleChecklistItemCompletion(UUID)
        case markChecklistItemCompleted(UUID)
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
        case editRoutineLinkChanged(String)
        case editDeadlineEnabledChanged(Bool)
        case editDeadlineDateChanged(Date)
        case editReminderEnabledChanged(Bool)
        case editReminderDateChanged(Date)
        case editReminderLeadMinutesChanged(Int?)
        case editPriorityChanged(RoutineTaskPriority)
        case editImportanceChanged(RoutineTaskImportance)
        case editUrgencyChanged(RoutineTaskUrgency)
        case editPressureChanged(RoutineTaskPressure)
        case editImagePicked(Data?)
        case editRemoveImageTapped
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
        case relatedTagRulesLoaded([RoutineRelatedTagRule])
        case availableRelationshipTasksLoaded([RoutineTaskRelationshipCandidate])
        case editSelectedPlaceChanged(UUID?)
        case editToggleTagSelection(String)
        case editToggleGoalSelection(RoutineGoalSummary)
        case editEstimatedDurationChanged(Int?)
        case editActualDurationChanged(Int?)
        case editStoryPointsChanged(Int?)
        case editFocusModeEnabledChanged(Bool)
        case editFrequencyChanged(EditFrequency)
        case editFrequencyValueChanged(Int)
        case editRecurrenceKindChanged(RoutineRecurrenceRule.Kind)
        case editRecurrenceHasExplicitTimeChanged(Bool)
        case editRecurrenceTimeOfDayChanged(RoutineTimeOfDay)
        case editRecurrenceWeekdayChanged(Int)
        case editRecurrenceDayOfMonthChanged(Int)
        case editAutoAssumeDailyDoneChanged(Bool)
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

    private func editSaveRequestBuilder() -> TaskDetailEditSaveRequestBuilder {
        TaskDetailEditSaveRequestBuilder(
            now: { now },
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
                guard calendar.isDate(state.selectedDate ?? now, inSameDayAs: now) else {
                    return .none
                }
                let completionDate = now
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
                let updatedItemCount = state.task.markChecklistItemsPurchased(
                    dueItemIDs,
                    purchasedAt: completionDate
                )
                guard updatedItemCount > 0 else { return .none }
                refreshTaskView(&state)
                upsertLocalLog(at: completionDate, in: &state)
                updateDerivedState(&state)
                return handleChecklistItemsPurchased(
                    taskID: state.task.id,
                    itemIDs: dueItemIDs,
                    purchasedAt: completionDate
                )
            }
            if state.task.isChecklistCompletionRoutine {
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
            guard RoutineDateMath.canMarkDone(
                for: state.task,
                referenceDate: completionDate,
                calendar: calendar,
                ignoreArchiveAtReferenceDate: isHistoricalCompletion
            ) else {
                return .none
            }
            state.task.preserveCurrentScheduleAnchorForBackfill(
                completedAt: completionDate,
                referenceDate: now
            )
            let advanceResult = state.task.advance(completedAt: completionDate, calendar: calendar)
            refreshTaskView(&state)
            if case .completedRoutine = advanceResult {
                upsertLocalLog(at: completionDate, in: &state)
                trackPendingLocalCompletion(at: completionDate, in: &state)
                appendLocalTodoStateChange(
                    to: state.task,
                    previousStateTitle: previousTodoStateTitle,
                    newStateTitle: TodoState.done.displayTitle
                )
            }
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

        case let .markChecklistItemPurchased(itemID):
            guard !state.task.isArchived(referenceDate: now, calendar: calendar) else { return .none }
            let completionDate = now
            let updatedItemCount = state.task.markChecklistItemsPurchased([itemID], purchasedAt: completionDate)
            guard updatedItemCount > 0 else { return .none }
            refreshTaskView(&state)
            upsertLocalLog(at: completionDate, in: &state)
            updateDerivedState(&state)
            return handleChecklistItemsPurchased(
                taskID: state.task.id,
                itemIDs: [itemID],
                purchasedAt: completionDate
            )

        case let .toggleChecklistItemCompletion(itemID):
            guard !state.task.isArchived(referenceDate: now, calendar: calendar) else { return .none }
            guard calendar.isDate(state.selectedDate ?? now, inSameDayAs: now) else {
                return .none
            }
            guard RoutineDateMath.canMarkDone(
                for: state.task,
                referenceDate: now,
                calendar: calendar
            ) else {
                return .none
            }

            let referenceDate = now
            if state.task.isChecklistItemCompleted(itemID) {
                guard state.task.isChecklistInProgress else { return .none }
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
            guard RoutineDateMath.canMarkDone(
                for: state.task,
                referenceDate: completionDate,
                calendar: calendar
            ) else {
                return .none
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

        case .undoSelectedDateCompletion:
            if state.task.isChecklistDriven {
                return .none
            }
            let selectedDay = resolvedSelectedDay(for: state.selectedDate)
            removePendingLocalCompletion(on: selectedDay, from: &state)
            removeCompletion(on: selectedDay, from: &state)
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handleUndoCompletion(taskID: state.task.id, completedDay: selectedDay)

        case .requestUndoSelectedDateCompletion:
            state.pendingLogRemovalTimestamp = nil
            state.isUndoCompletionConfirmationPresented = true
            return .none

        case let .removeLogEntry(timestamp):
            removePendingLocalCompletion(on: timestamp, from: &state)
            removeLogEntry(at: timestamp, from: &state)
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handleRemoveLogEntry(taskID: state.task.id, timestamp: timestamp)

        case let .updateLogDuration(logID, durationMinutes):
            let sanitizedDuration = RoutineLog.sanitizedActualDurationMinutes(durationMinutes)
            let previousDuration = state.logs.first(where: { $0.id == logID })?.actualDurationMinutes
            if let index = state.logs.firstIndex(where: { $0.id == logID }) {
                state.logs[index].actualDurationMinutes = sanitizedDuration
            }
            return handleUpdateLogDuration(
                taskID: state.task.id,
                logID: logID,
                previousDurationMinutes: previousDuration,
                durationMinutes: sanitizedDuration
            )

        case let .updateTaskDuration(durationMinutes):
            let sanitizedDuration = RoutineTask.sanitizedActualDurationMinutes(durationMinutes)
            let previousDuration = state.task.actualDurationMinutes
            state.task.actualDurationMinutes = sanitizedDuration
            return handleUpdateTaskDuration(
                taskID: state.task.id,
                previousDurationMinutes: previousDuration,
                durationMinutes: sanitizedDuration
            )

        case let .requestRemoveLogEntry(timestamp):
            state.pendingLogRemovalTimestamp = timestamp
            state.isUndoCompletionConfirmationPresented = true
            return .none

        case .pauseTapped:
            guard !state.task.isOneOffTask else { return .none }
            guard !state.task.isArchived(referenceDate: now, calendar: calendar) else { return .none }
            let pauseDate = now
            if state.task.scheduleAnchor == nil {
                state.task.scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(for: state.task, referenceDate: pauseDate)
            }
            state.task.pausedAt = pauseDate
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handlePauseRoutine(taskID: state.task.id, pausedAt: pauseDate)

        case .notTodayTapped:
            guard !state.task.isOneOffTask else { return .none }
            guard !state.task.isArchived(referenceDate: now, calendar: calendar) else { return .none }
            let tomorrowStart = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: now)
            ) ?? now
            state.task.snoozedUntil = tomorrowStart
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handleNotTodayRoutine(taskID: state.task.id, snoozedUntil: tomorrowStart)

        case .resumeTapped:
            guard !state.task.isOneOffTask else { return .none }
            guard state.task.isArchived(referenceDate: now, calendar: calendar) else { return .none }
            let resumeDate = now
            if let pausedAt = state.task.pausedAt, state.task.isChecklistDriven {
                state.task.shiftChecklistItems(by: max(resumeDate.timeIntervalSince(pausedAt), 0))
            }
            state.task.scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(for: state.task, resumedAt: resumeDate)
            state.task.pausedAt = nil
            state.task.snoozedUntil = nil
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handleResumeRoutine(taskID: state.task.id, resumedAt: resumeDate)

        case .startOngoingTapped:
            guard state.task.isSoftIntervalRoutine else { return .none }
            guard !state.task.isArchived(referenceDate: now, calendar: calendar) else { return .none }
            guard !state.task.isOngoing else { return .none }
            state.task.startOngoing(at: now)
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handleStartOngoing(taskID: state.task.id, startedAt: now)

        case .finishOngoingTapped:
            guard state.task.isSoftIntervalRoutine else { return .none }
            guard state.task.isOngoing else { return .none }
            state.task.finishOngoing(at: now)
            refreshTaskView(&state)
            upsertLocalLog(at: now, in: &state)
            updateDerivedState(&state)
            return handleFinishOngoing(taskID: state.task.id, finishedAt: now)

        case let .selectedDateChanged(date):
            state.selectedDate = calendar.startOfDay(for: date)
            return .none

        case let .setEditSheet(isPresented):
            state.isEditSheetPresented = isPresented
            if isPresented {
                syncEditFormFromTask(&state)
                return loadEditContext(excluding: state.task.id)
            }
            return .none

        case let .editRoutineNameChanged(name):
            return basicEditActionHandler().editRoutineNameChanged(name, state: &state)

        case let .editRoutineEmojiChanged(emoji):
            return basicEditActionHandler().editRoutineEmojiChanged(emoji, state: &state)

        case let .editRoutineNotesChanged(notes):
            return basicEditActionHandler().editRoutineNotesChanged(notes, state: &state)

        case let .editRoutineLinkChanged(link):
            return basicEditActionHandler().editRoutineLinkChanged(link, state: &state)

        case let .editDeadlineEnabledChanged(isEnabled):
            state.editDeadline = isEnabled ? (state.editDeadline ?? now) : nil
            return .none

        case let .editDeadlineDateChanged(deadline):
            rebaseEditReminderIfUsingLeadTime(&state) { state in
                state.editDeadline = deadline
            }
            return .none

        case let .editReminderEnabledChanged(isEnabled):
            state.editReminderAt = isEnabled
                ? (state.editReminderAt ?? editReminderEventDate(for: state) ?? now)
                : nil
            return .none

        case let .editReminderDateChanged(reminderDate):
            state.editReminderAt = reminderDate
            return .none

        case let .editReminderLeadMinutesChanged(leadMinutes):
            guard let leadMinutes,
                  let eventDate = editReminderEventDate(for: state) else {
                return .none
            }
            state.editReminderAt = TaskFormReminderLeadTime.reminderDate(
                eventDate: eventDate,
                leadMinutes: leadMinutes
            )
            return .none

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
            editDraftMutationHandler().setTagDraft(value, state: &state)
            return .none

        case let .editGoalDraftChanged(value):
            editDraftMutationHandler().setGoalDraft(value, state: &state)
            return .none

        case .editAddTagTapped:
            editDraftMutationHandler().addTag(state: &state)
            return .none

        case .editAddGoalTapped:
            editDraftMutationHandler().addGoal(state: &state)
            return .none

        case let .editRemoveTag(tag):
            editDraftMutationHandler().removeTag(tag, state: &state)
            return .none

        case let .editRemoveGoal(goalID):
            editDraftMutationHandler().removeGoal(goalID, state: &state)
            return .none

        case let .editAddRelationship(taskID, kind):
            editDraftMutationHandler().addRelationship(taskID: taskID, kind: kind, state: &state)
            return .none

        case let .editRemoveRelationship(taskID):
            editDraftMutationHandler().removeRelationship(taskID, state: &state)
            return .none

        case let .editTagRenamed(oldName, newName):
            editDraftMutationHandler().renameTag(oldName: oldName, newName: newName, state: &state)
            return .none

        case let .editTagDeleted(tag):
            editDraftMutationHandler().deleteTag(tag, state: &state)
            return .none

        case let .editScheduleModeChanged(mode):
            rebaseEditReminderIfUsingLeadTime(&state) { state in
                state.editScheduleMode = mode
                if mode != .oneOff {
                    state.editDeadline = nil
                }
                if mode == .softInterval {
                    state.editRecurrenceKind = .intervalDays
                    state.editRecurrenceHasExplicitTime = false
                }
            }
            if !canAutoAssumeDailyDone(for: state) {
                state.editAutoAssumeDailyDone = false
            }
            return .none

        case let .editStepDraftChanged(value):
            state.editStepDraft = value
            return .none

        case .editAddStepTapped:
            state.editRoutineSteps = appendStep(from: state.editStepDraft, to: state.editRoutineSteps)
            state.editStepDraft = ""
            if !canAutoAssumeDailyDone(for: state) {
                state.editAutoAssumeDailyDone = false
            }
            return .none

        case let .editRemoveStep(stepID):
            state.editRoutineSteps.removeAll { $0.id == stepID }
            if !canAutoAssumeDailyDone(for: state) {
                state.editAutoAssumeDailyDone = false
            }
            return .none

        case let .editMoveStepUp(stepID):
            moveStep(stepID, by: -1, state: &state)
            return .none

        case let .editMoveStepDown(stepID):
            moveStep(stepID, by: 1, state: &state)
            return .none

        case let .editChecklistItemDraftTitleChanged(value):
            state.editChecklistItemDraftTitle = value
            return .none

        case let .editChecklistItemDraftIntervalChanged(value):
            state.editChecklistItemDraftInterval = RoutineChecklistItem.clampedIntervalDays(value)
            return .none

        case .editAddChecklistItemTapped:
            state.editRoutineChecklistItems = appendChecklistItem(
                from: state.editChecklistItemDraftTitle,
                intervalDays: state.editChecklistItemDraftInterval,
                createdAt: now,
                to: state.editRoutineChecklistItems
            )
            state.editChecklistItemDraftTitle = ""
            state.editChecklistItemDraftInterval = 3
            if !canAutoAssumeDailyDone(for: state) {
                state.editAutoAssumeDailyDone = false
            }
            return .none

        case let .editRemoveChecklistItem(itemID):
            state.editRoutineChecklistItems.removeAll { $0.id == itemID }
            if !canAutoAssumeDailyDone(for: state) {
                state.editAutoAssumeDailyDone = false
            }
            return .none

        case let .availablePlacesLoaded(places):
            state.availablePlaces = places
            if let selectedPlaceID = state.editSelectedPlaceID,
               !places.contains(where: { $0.id == selectedPlaceID }) {
                state.editSelectedPlaceID = nil
            }
            return .none

        case let .availableTagsLoaded(tags):
            state.availableTags = RoutineTag.allTags(from: [tags])
            return .none

        case let .availableGoalsLoaded(goals):
            state.availableGoals = RoutineGoalSummary.sanitized(goals).sorted {
                $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
            }
            state.editRoutineGoals = RoutineGoalSummary.summaries(
                for: state.task.goalIDs,
                in: state.availableGoals
            )
            return .none

        case let .relatedTagRulesLoaded(rules):
            state.relatedTagRules = RoutineTagRelations.sanitized(rules)
            return .none

        case let .availableRelationshipTasksLoaded(tasks):
            state.availableRelationshipTasks = tasks
            state.editRelationships = RoutineTaskRelationship.sanitized(
                state.editRelationships.filter { relationship in
                    tasks.contains(where: { $0.id == relationship.targetTaskID })
                },
                ownerID: state.task.id
            )
            return .none

        case let .editSelectedPlaceChanged(placeID):
            editDraftMutationHandler().setSelectedPlace(placeID, state: &state)
            return .none

        case let .editToggleTagSelection(tag):
            editDraftMutationHandler().toggleTagSelection(tag, state: &state)
            return .none

        case let .editToggleGoalSelection(goal):
            editDraftMutationHandler().toggleGoalSelection(goal, state: &state)
            return .none

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
            rebaseEditReminderIfUsingLeadTime(&state) { state in
                state.editFrequency = frequency
            }
            if !canAutoAssumeDailyDone(for: state) {
                state.editAutoAssumeDailyDone = false
            }
            return .none

        case let .editFrequencyValueChanged(value):
            rebaseEditReminderIfUsingLeadTime(&state) { state in
                state.editFrequencyValue = value
            }
            if !canAutoAssumeDailyDone(for: state) {
                state.editAutoAssumeDailyDone = false
            }
            return .none

        case let .editRecurrenceKindChanged(kind):
            rebaseEditReminderIfUsingLeadTime(&state) { state in
                let previousHasExplicitTime = state.editRecurrenceHasExplicitTime
                state.editRecurrenceKind = kind
                switch kind {
                case .intervalDays:
                    state.editRecurrenceHasExplicitTime = false
                case .dailyTime:
                    state.editRecurrenceHasExplicitTime = true
                case .weekly, .monthlyDay:
                    state.editRecurrenceHasExplicitTime = previousHasExplicitTime
                }
            }
            if !canAutoAssumeDailyDone(for: state) {
                state.editAutoAssumeDailyDone = false
            }
            return .none

        case let .editRecurrenceHasExplicitTimeChanged(hasExplicitTime):
            rebaseEditReminderIfUsingLeadTime(&state) { state in
                state.editRecurrenceHasExplicitTime = hasExplicitTime
            }
            return .none

        case let .editRecurrenceTimeOfDayChanged(timeOfDay):
            rebaseEditReminderIfUsingLeadTime(&state) { state in
                state.editRecurrenceTimeOfDay = timeOfDay
            }
            if !canAutoAssumeDailyDone(for: state) {
                state.editAutoAssumeDailyDone = false
            }
            return .none

        case let .editRecurrenceWeekdayChanged(weekday):
            rebaseEditReminderIfUsingLeadTime(&state) { state in
                state.editRecurrenceWeekday = min(max(weekday, 1), 7)
            }
            return .none

        case let .editRecurrenceDayOfMonthChanged(dayOfMonth):
            rebaseEditReminderIfUsingLeadTime(&state) { state in
                state.editRecurrenceDayOfMonth = min(max(dayOfMonth, 1), 31)
            }
            return .none

        case let .editAutoAssumeDailyDoneChanged(isEnabled):
            state.editAutoAssumeDailyDone = isEnabled && canAutoAssumeDailyDone(for: state)
            return .none

        case .editSaveTapped:
            guard let request = editSaveRequestBuilder().build(state: &state) else { return .none }
            return handleEditSave(request)

        case .confirmAssumedPastDays:
            let assumedDays = RoutineAssumedCompletion.assumedDates(
                for: state.task,
                through: now,
                logs: state.logs,
                includeToday: true,
                calendar: calendar
            )
            guard !assumedDays.isEmpty else { return .none }

            for day in assumedDays {
                let completionDate = RoutineAssumedCompletion.completionTimestamp(
                    for: day,
                    referenceDate: now,
                    calendar: calendar
                )
                _ = state.task.advance(completedAt: completionDate, calendar: calendar)
                upsertLocalLog(at: completionDate, in: &state)
            }
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handleConfirmAssumedPastDays(taskID: state.task.id, days: assumedDays)

        case let .setDeleteConfirmation(isPresented):
            state.isDeleteConfirmationPresented = isPresented
            return .none

        case let .setUndoCompletionConfirmation(isPresented):
            state.isUndoCompletionConfirmationPresented = isPresented
            if !isPresented {
                state.pendingLogRemovalTimestamp = nil
            }
            return .none

        case .confirmUndoCompletion:
            state.isUndoCompletionConfirmationPresented = false
            if let timestamp = state.pendingLogRemovalTimestamp {
                state.pendingLogRemovalTimestamp = nil
                return reduce(into: &state, action: .removeLogEntry(timestamp))
            }
            return reduce(into: &state, action: .undoSelectedDateCompletion)

        case .deleteRoutineConfirmed:
            state.isDeleteConfirmationPresented = false
            return handleDeleteRoutine(taskID: state.task.id)

        case .routineDeleted:
            state.isEditSheetPresented = false
            state.shouldDismissAfterDelete = true
            return .none

        case .deleteDismissHandled:
            state.shouldDismissAfterDelete = false
            return .none

        case let .logsLoaded(logs):
            state.logs = logsPreservingPendingLocalCompletions(logs, in: &state)
            updateDerivedState(&state)
            return .none

        case .openLinkedTask:
            return .none

        case let .addLinkedTaskRelationshipKindChanged(kind):
            state.addLinkedTaskRelationshipKind = kind
            return .none

        case .openAddLinkedTask:
            return .none

        case let .editColorChanged(color):
            return basicEditActionHandler().editColorChanged(color, state: &state)

        case let .todoStateChanged(newState):
            switch statusMutationHandler().applyTodoStateChange(newState, state: &state) {
            case .none:
                return .none

            case .markAsDone:
                return reduce(into: &state, action: .markAsDone)

            case let .persist(request):
                return handleTodoStateChanged(
                    taskID: request.taskID,
                    rawValue: request.rawValue,
                    pausedAt: request.pausedAt,
                    clearSnoozed: request.clearSnoozed,
                    previousStateTitle: request.previousStateTitle,
                    newStateTitle: request.newStateTitle
                )
            }

        case let .pressureChanged(pressure):
            guard let mutation = statusMutationHandler().applyPressureChange(pressure, state: &state) else {
                return .none
            }
            return handlePressureChanged(taskID: mutation.taskID, pressure: mutation.pressure)

        case let .importanceChanged(importance):
            guard let mutation = statusMutationHandler().applyImportanceChange(importance, state: &state) else {
                return .none
            }
            return handleMatrixPositionChanged(
                taskID: mutation.taskID,
                importance: mutation.importance,
                urgency: mutation.urgency,
                priority: mutation.priority
            )

        case let .urgencyChanged(urgency):
            guard let mutation = statusMutationHandler().applyUrgencyChange(urgency, state: &state) else {
                return .none
            }
            return handleMatrixPositionChanged(
                taskID: mutation.taskID,
                importance: mutation.importance,
                urgency: mutation.urgency,
                priority: mutation.priority
            )

        case let .setBlockedStateConfirmation(isPresented):
            state.isBlockedStateConfirmationPresented = isPresented
            return .none

        case .confirmBlockedStateCompletion:
            state.isBlockedStateConfirmationPresented = false
            return reduce(into: &state, action: .markAsDone)

        case .notificationDisabledWarningTapped:
            if !state.appNotificationsEnabled {
                let notificationPayload = NotificationCoordinator.shouldScheduleNotification(
                    for: state.task,
                    referenceDate: now,
                    calendar: calendar
                )
                    ? NotificationCoordinator.notificationPayload(
                        for: state.task,
                        referenceDate: now,
                        calendar: calendar
                    )
                    : nil
                return .run { @MainActor send in
                    let granted = await notificationClient.requestAuthorizationIfNeeded()
                    appSettingsClient.setNotificationsEnabled(granted)
                    if granted, let notificationPayload {
                        await notificationClient.schedule(notificationPayload)
                    } else if let url = urlOpenerClient.notificationSettingsURL() {
                        urlOpenerClient.open(url)
                    }
                    await send(.notificationStatusLoaded(appEnabled: granted, systemAuthorized: granted))
                }
            }
            guard !state.systemNotificationsAuthorized else { return .none }
            return .run { @MainActor _ in
                guard let url = urlOpenerClient.notificationSettingsURL() else { return }
                urlOpenerClient.open(url)
            }

        case let .notificationStatusLoaded(appEnabled, systemAuthorized):
            state.hasLoadedNotificationStatus = true
            state.appNotificationsEnabled = appEnabled
            state.systemNotificationsAuthorized = systemAuthorized
            return .none

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

import ComposableArchitecture
import Foundation
import SwiftData
import UserNotifications

struct TaskDetailFeature: Reducer {
    private enum CancelID {
        case loadContext
    }

    enum EditFrequency: String, CaseIterable, Equatable {
        case day = "Day"
        case week = "Week"
        case month = "Month"

        var daysMultiplier: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            }
        }

        var singularLabel: String {
            switch self {
            case .day: return "day"
            case .week: return "week"
            case .month: return "month"
            }
        }
    }

    @ObservableState
    struct State: Equatable {
        var task: RoutineTask
        var taskRefreshID: UInt64 = 0
        var logs: [RoutineLog] = []
        var selectedDate: Date?
        var daysSinceLastRoutine: Int = 0
        var overdueDays: Int = 0
        var isDoneToday: Bool = false
        var isEditSheetPresented: Bool = false
        var editRoutineName: String = ""
        var editRoutineEmoji: String = "✨"
        var editRoutineNotes: String = ""
        var editRoutineLink: String = ""
        var editDeadline: Date?
        var editPriority: RoutineTaskPriority = .none
        var editImportance: RoutineTaskImportance = .level2
        var editUrgency: RoutineTaskUrgency = .level2
        var editImageData: Data?
        var taskAttachments: [AttachmentItem] = []
        var editAttachments: [AttachmentItem] = []
        var editRoutineTags: [String] = []
        var editRelationships: [RoutineTaskRelationship] = []
        var editTagDraft: String = ""
        var editScheduleMode: RoutineScheduleMode = .fixedInterval
        var editRoutineSteps: [RoutineStep] = []
        var editStepDraft: String = ""
        var editRoutineChecklistItems: [RoutineChecklistItem] = []
        var editChecklistItemDraftTitle: String = ""
        var editChecklistItemDraftInterval: Int = 3
        var availablePlaces: [RoutinePlaceSummary] = []
        var availableTags: [String] = []
        var availableRelationshipTasks: [RoutineTaskRelationshipCandidate] = []
        var editSelectedPlaceID: UUID?
        var editFrequency: EditFrequency = .day
        var editFrequencyValue: Int = 1
        var editRecurrenceKind: RoutineRecurrenceRule.Kind = .intervalDays
        var editRecurrenceTimeOfDay: RoutineTimeOfDay = .defaultValue
        var editRecurrenceWeekday: Int = Calendar.current.component(.weekday, from: Date())
        var editRecurrenceDayOfMonth: Int = Calendar.current.component(.day, from: Date())
        var isDeleteConfirmationPresented: Bool = false
        var shouldDismissAfterDelete: Bool = false
        var addLinkedTaskRelationshipKind: RoutineTaskRelationshipKind = .related
    }

    enum Action: Equatable {
        case markAsDone
        case cancelTodo
        case markChecklistItemPurchased(UUID)
        case toggleChecklistItemCompletion(UUID)
        case markChecklistItemCompleted(UUID)
        case undoSelectedDateCompletion
        case pauseTapped
        case resumeTapped
        case selectedDateChanged(Date)
        case setEditSheet(Bool)
        case editRoutineNameChanged(String)
        case editRoutineEmojiChanged(String)
        case editRoutineNotesChanged(String)
        case editRoutineLinkChanged(String)
        case editDeadlineEnabledChanged(Bool)
        case editDeadlineDateChanged(Date)
        case editPriorityChanged(RoutineTaskPriority)
        case editImportanceChanged(RoutineTaskImportance)
        case editUrgencyChanged(RoutineTaskUrgency)
        case editImagePicked(Data?)
        case editRemoveImageTapped
        case editAttachmentPicked(Data, String)
        case editRemoveAttachment(UUID)
        case attachmentsLoaded([AttachmentItem])
        case editTagDraftChanged(String)
        case editAddTagTapped
        case editRemoveTag(String)
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
        case availableRelationshipTasksLoaded([RoutineTaskRelationshipCandidate])
        case editSelectedPlaceChanged(UUID?)
        case editToggleTagSelection(String)
        case editFrequencyChanged(EditFrequency)
        case editFrequencyValueChanged(Int)
        case editRecurrenceKindChanged(RoutineRecurrenceRule.Kind)
        case editRecurrenceTimeOfDayChanged(RoutineTimeOfDay)
        case editRecurrenceWeekdayChanged(Int)
        case editRecurrenceDayOfMonthChanged(Int)
        case editSaveTapped
        case setDeleteConfirmation(Bool)
        case deleteRoutineConfirmed
        case routineDeleted
        case deleteDismissHandled
        case logsLoaded([RoutineLog])
        case openLinkedTask(UUID)
        case addLinkedTaskRelationshipKindChanged(RoutineTaskRelationshipKind)
        case openAddLinkedTask
        case onAppear
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.modelContext) var modelContext
    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .markAsDone:
            guard !state.task.isPaused else { return .none }
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
            let completionDate = resolvedCompletionDate(for: state.selectedDate)
            guard !state.task.hasSequentialSteps || calendar.isDate(completionDate, inSameDayAs: now) else {
                return .none
            }
            guard RoutineDateMath.canMarkDone(
                for: state.task,
                referenceDate: completionDate,
                calendar: calendar
            ) else {
                return .none
            }
            _ = state.task.advance(completedAt: completionDate, calendar: calendar)
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handleMarkAsDone(taskID: state.task.id, completedAt: completionDate)

        case .cancelTodo:
            guard state.task.isOneOffTask else { return .none }
            guard !state.task.isPaused else { return .none }
            guard !state.task.isCompletedOneOff else { return .none }
            guard !state.task.isCanceledOneOff else { return .none }
            let canceledAt = resolvedCompletionDate(for: state.selectedDate)
            guard state.task.cancelOneOff(at: canceledAt) else { return .none }
            refreshTaskView(&state)
            upsertLocalLog(at: canceledAt, kind: .canceled, in: &state)
            updateDerivedState(&state)
            return handleCancelTodo(taskID: state.task.id, canceledAt: canceledAt)

        case let .markChecklistItemPurchased(itemID):
            guard !state.task.isPaused else { return .none }
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
            guard !state.task.isPaused else { return .none }
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
            guard !state.task.isPaused else { return .none }
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
            removeCompletion(on: selectedDay, from: &state)
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handleUndoCompletion(taskID: state.task.id, completedDay: selectedDay)

        case .pauseTapped:
            guard !state.task.isOneOffTask else { return .none }
            guard !state.task.isPaused else { return .none }
            let pauseDate = now
            if state.task.scheduleAnchor == nil {
                state.task.scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(for: state.task, referenceDate: pauseDate)
            }
            state.task.pausedAt = pauseDate
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handlePauseRoutine(taskID: state.task.id, pausedAt: pauseDate)

        case .resumeTapped:
            guard !state.task.isOneOffTask else { return .none }
            guard state.task.isPaused else { return .none }
            let resumeDate = now
            if let pausedAt = state.task.pausedAt, state.task.isChecklistDriven {
                state.task.shiftChecklistItems(by: max(resumeDate.timeIntervalSince(pausedAt), 0))
            }
            state.task.scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(for: state.task, resumedAt: resumeDate)
            state.task.pausedAt = nil
            refreshTaskView(&state)
            updateDerivedState(&state)
            return handleResumeRoutine(taskID: state.task.id, resumedAt: resumeDate)

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
            state.editRoutineName = name
            return .none

        case let .editRoutineEmojiChanged(emoji):
            state.editRoutineEmoji = RoutineTask.sanitizedEmoji(emoji, fallback: state.editRoutineEmoji)
            return .none

        case let .editRoutineNotesChanged(notes):
            state.editRoutineNotes = notes
            return .none

        case let .editRoutineLinkChanged(link):
            state.editRoutineLink = link
            return .none

        case let .editDeadlineEnabledChanged(isEnabled):
            state.editDeadline = isEnabled ? (state.editDeadline ?? now) : nil
            return .none

        case let .editDeadlineDateChanged(deadline):
            state.editDeadline = deadline
            return .none

        case let .editPriorityChanged(priority):
            state.editPriority = priority
            return .none

        case let .editImportanceChanged(importance):
            state.editImportance = importance
            state.editPriority = matrixPriority(
                importance: importance,
                urgency: state.editUrgency
            )
            return .none

        case let .editUrgencyChanged(urgency):
            state.editUrgency = urgency
            state.editPriority = matrixPriority(
                importance: state.editImportance,
                urgency: urgency
            )
            return .none

        case let .editImagePicked(data):
            state.editImageData = data.flatMap(TaskImageProcessor.compressedImageData(from:))
            return .none

        case .editRemoveImageTapped:
            state.editImageData = nil
            return .none

        case let .editAttachmentPicked(data, fileName):
            state.editAttachments.append(AttachmentItem(fileName: fileName, data: data))
            return .none

        case let .editRemoveAttachment(id):
            state.editAttachments.removeAll { $0.id == id }
            return .none

        case let .attachmentsLoaded(items):
            state.taskAttachments = items
            return .none

        case let .editTagDraftChanged(value):
            state.editTagDraft = value
            return .none

        case .editAddTagTapped:
            state.editRoutineTags = RoutineTag.appending(state.editTagDraft, to: state.editRoutineTags)
            state.editTagDraft = ""
            return .none

        case let .editRemoveTag(tag):
            state.editRoutineTags = RoutineTag.removing(tag, from: state.editRoutineTags)
            return .none

        case let .editAddRelationship(taskID, kind):
            state.editRelationships = RoutineTaskRelationship.sanitized(
                state.editRelationships + [RoutineTaskRelationship(targetTaskID: taskID, kind: kind)],
                ownerID: state.task.id
            )
            return .none

        case let .editRemoveRelationship(taskID):
            state.editRelationships.removeAll { $0.targetTaskID == taskID }
            return .none

        case let .editTagRenamed(oldName, newName):
            state.availableTags = RoutineTag.replacing(oldName, with: newName, in: state.availableTags)
            if RoutineTag.contains(oldName, in: state.editRoutineTags) {
                state.editRoutineTags = RoutineTag.replacing(oldName, with: newName, in: state.editRoutineTags)
            }
            if RoutineTag.contains(oldName, in: state.task.tags) {
                state.task.tags = RoutineTag.replacing(oldName, with: newName, in: state.task.tags)
                refreshTaskView(&state)
            }
            return .none

        case let .editTagDeleted(tag):
            state.availableTags = RoutineTag.removing(tag, from: state.availableTags)
            state.editRoutineTags = RoutineTag.removing(tag, from: state.editRoutineTags)
            if RoutineTag.contains(tag, in: state.task.tags) {
                state.task.tags = RoutineTag.removing(tag, from: state.task.tags)
                refreshTaskView(&state)
            }
            return .none

        case let .editScheduleModeChanged(mode):
            state.editScheduleMode = mode
            if mode != .oneOff {
                state.editDeadline = nil
            }
            return .none

        case let .editStepDraftChanged(value):
            state.editStepDraft = value
            return .none

        case .editAddStepTapped:
            state.editRoutineSteps = appendStep(from: state.editStepDraft, to: state.editRoutineSteps)
            state.editStepDraft = ""
            return .none

        case let .editRemoveStep(stepID):
            state.editRoutineSteps.removeAll { $0.id == stepID }
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
            return .none

        case let .editRemoveChecklistItem(itemID):
            state.editRoutineChecklistItems.removeAll { $0.id == itemID }
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
            state.editSelectedPlaceID = placeID
            return .none

        case let .editToggleTagSelection(tag):
            if RoutineTag.contains(tag, in: state.editRoutineTags) {
                state.editRoutineTags = RoutineTag.removing(tag, from: state.editRoutineTags)
            } else {
                state.editRoutineTags = RoutineTag.appending(tag, to: state.editRoutineTags)
            }
            return .none

        case let .editFrequencyChanged(frequency):
            state.editFrequency = frequency
            return .none

        case let .editFrequencyValueChanged(value):
            state.editFrequencyValue = value
            return .none

        case let .editRecurrenceKindChanged(kind):
            state.editRecurrenceKind = kind
            return .none

        case let .editRecurrenceTimeOfDayChanged(timeOfDay):
            state.editRecurrenceTimeOfDay = timeOfDay
            return .none

        case let .editRecurrenceWeekdayChanged(weekday):
            state.editRecurrenceWeekday = min(max(weekday, 1), 7)
            return .none

        case let .editRecurrenceDayOfMonthChanged(dayOfMonth):
            state.editRecurrenceDayOfMonth = min(max(dayOfMonth, 1), 31)
            return .none

        case .editSaveTapped:
            state.editRoutineTags = RoutineTag.appending(state.editTagDraft, to: state.editRoutineTags)
            state.editTagDraft = ""
            state.editRoutineSteps = appendStep(from: state.editStepDraft, to: state.editRoutineSteps)
            state.editStepDraft = ""
            state.editRoutineChecklistItems = appendChecklistItem(
                from: state.editChecklistItemDraftTitle,
                intervalDays: state.editChecklistItemDraftInterval,
                createdAt: now,
                to: state.editRoutineChecklistItems
            )
            state.editChecklistItemDraftTitle = ""
            state.editChecklistItemDraftInterval = 3
            let trimmedName = state.editRoutineName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return .none }
            guard !scheduleModeRequiresChecklistItems(state.editScheduleMode) || !state.editRoutineChecklistItems.isEmpty else {
                return .none
            }
            state.isEditSheetPresented = false
            let frequencyInterval = state.editScheduleMode == .oneOff
                ? 1
                : state.editFrequencyValue * state.editFrequency.daysMultiplier
            let recurrenceRule = selectedRecurrenceRule(
                for: state,
                fallbackInterval: frequencyInterval
            )
            return handleEditSave(
                taskID: state.task.id,
                name: trimmedName,
                emoji: state.editRoutineEmoji,
                notes: RoutineTask.sanitizedNotes(state.editRoutineNotes),
                link: RoutineTask.sanitizedLink(state.editRoutineLink),
                deadline: state.editScheduleMode == .oneOff ? state.editDeadline : nil,
                priority: matrixPriority(
                    importance: state.editImportance,
                    urgency: state.editUrgency
                ),
                importance: state.editImportance,
                urgency: state.editUrgency,
                imageData: state.editImageData,
                attachments: state.editAttachments,
                placeID: state.editSelectedPlaceID,
                tags: state.editRoutineTags,
                relationships: state.editRelationships,
                steps: (state.editScheduleMode == .fixedInterval || state.editScheduleMode == .oneOff)
                    ? state.editRoutineSteps
                    : [],
                checklistItems: (state.editScheduleMode == .fixedInterval || state.editScheduleMode == .oneOff)
                    ? []
                    : state.editRoutineChecklistItems,
                scheduleMode: state.editScheduleMode,
                recurrenceRule: recurrenceRule
            )

        case let .setDeleteConfirmation(isPresented):
            state.isDeleteConfirmationPresented = isPresented
            return .none

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
            state.logs = logs.map { $0.detachedCopy() }
            updateDerivedState(&state)
            return .none

        case .openLinkedTask:
            return .none

        case let .addLinkedTaskRelationshipKindChanged(kind):
            state.addLinkedTaskRelationshipKind = kind
            return .none

        case .openAddLinkedTask:
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

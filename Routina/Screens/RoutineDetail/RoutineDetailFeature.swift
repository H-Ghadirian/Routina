import ComposableArchitecture
import Foundation
import SwiftData
import UserNotifications

struct RoutineDetailFeature: Reducer {
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
        var logs: [RoutineLog] = []
        var selectedDate: Date?
        var daysSinceLastRoutine: Int = 0
        var overdueDays: Int = 0
        var isDoneToday: Bool = false
        var isEditSheetPresented: Bool = false
        var editRoutineName: String = ""
        var editRoutineEmoji: String = "✨"
        var editRoutineTags: [String] = []
        var editTagDraft: String = ""
        var editRoutineSteps: [RoutineStep] = []
        var editStepDraft: String = ""
        var availablePlaces: [RoutinePlaceSummary] = []
        var editSelectedPlaceID: UUID?
        var editFrequency: EditFrequency = .day
        var editFrequencyValue: Int = 1
        var isDeleteConfirmationPresented: Bool = false
        var shouldDismissAfterDelete: Bool = false
    }

    enum Action: Equatable {
        case markAsDone
        case undoSelectedDateCompletion
        case pauseTapped
        case resumeTapped
        case selectedDateChanged(Date)
        case setEditSheet(Bool)
        case editRoutineNameChanged(String)
        case editRoutineEmojiChanged(String)
        case editTagDraftChanged(String)
        case editAddTagTapped
        case editRemoveTag(String)
        case editStepDraftChanged(String)
        case editAddStepTapped
        case editRemoveStep(UUID)
        case editMoveStepUp(UUID)
        case editMoveStepDown(UUID)
        case availablePlacesLoaded([RoutinePlaceSummary])
        case editSelectedPlaceChanged(UUID?)
        case editFrequencyChanged(EditFrequency)
        case editFrequencyValueChanged(Int)
        case editSaveTapped
        case setDeleteConfirmation(Bool)
        case deleteRoutineConfirmed
        case routineDeleted
        case deleteDismissHandled
        case logsLoaded([RoutineLog])
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
            let completionDate = resolvedCompletionDate(for: state.selectedDate)
            guard !state.task.hasSequentialSteps || calendar.isDate(completionDate, inSameDayAs: now) else {
                return .none
            }
            _ = state.task.advance(completedAt: completionDate, calendar: calendar)
            updateDerivedState(&state)
            return handleMarkAsDone(taskID: state.task.id, completedAt: completionDate)

        case .undoSelectedDateCompletion:
            let selectedDay = resolvedSelectedDay(for: state.selectedDate)
            removeCompletion(on: selectedDay, from: &state)
            updateDerivedState(&state)
            return handleUndoCompletion(taskID: state.task.id, completedDay: selectedDay)

        case .pauseTapped:
            guard !state.task.isPaused else { return .none }
            let pauseDate = now
            if state.task.scheduleAnchor == nil {
                state.task.scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(for: state.task, referenceDate: pauseDate)
            }
            state.task.pausedAt = pauseDate
            updateDerivedState(&state)
            return handlePauseRoutine(taskID: state.task.id, pausedAt: pauseDate)

        case .resumeTapped:
            guard state.task.isPaused else { return .none }
            let resumeDate = now
            state.task.scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(for: state.task, resumedAt: resumeDate)
            state.task.pausedAt = nil
            updateDerivedState(&state)
            return handleResumeRoutine(taskID: state.task.id, resumedAt: resumeDate)

        case let .selectedDateChanged(date):
            state.selectedDate = calendar.startOfDay(for: date)
            return .none

        case let .setEditSheet(isPresented):
            state.isEditSheetPresented = isPresented
            if isPresented {
                syncEditFormFromTask(&state)
                return loadAvailablePlaces()
            }
            return .none

        case let .editRoutineNameChanged(name):
            state.editRoutineName = name
            return .none

        case let .editRoutineEmojiChanged(emoji):
            state.editRoutineEmoji = RoutineTask.sanitizedEmoji(emoji, fallback: state.editRoutineEmoji)
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

        case let .availablePlacesLoaded(places):
            state.availablePlaces = places
            if let selectedPlaceID = state.editSelectedPlaceID,
               !places.contains(where: { $0.id == selectedPlaceID }) {
                state.editSelectedPlaceID = nil
            }
            return .none

        case let .editSelectedPlaceChanged(placeID):
            state.editSelectedPlaceID = placeID
            return .none

        case let .editFrequencyChanged(frequency):
            state.editFrequency = frequency
            return .none

        case let .editFrequencyValueChanged(value):
            state.editFrequencyValue = value
            return .none

        case .editSaveTapped:
            state.editRoutineTags = RoutineTag.appending(state.editTagDraft, to: state.editRoutineTags)
            state.editTagDraft = ""
            state.editRoutineSteps = appendStep(from: state.editStepDraft, to: state.editRoutineSteps)
            state.editStepDraft = ""
            let trimmedName = state.editRoutineName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return .none }
            state.isEditSheetPresented = false
            return handleEditSave(
                taskID: state.task.id,
                name: trimmedName,
                emoji: state.editRoutineEmoji,
                placeID: state.editSelectedPlaceID,
                tags: state.editRoutineTags,
                steps: state.editRoutineSteps,
                interval: Int16(state.editFrequencyValue * state.editFrequency.daysMultiplier)
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
            state.logs = logs
            updateDerivedState(&state)
            return .none

        case .onAppear:
            if state.selectedDate == nil {
                state.selectedDate = calendar.startOfDay(for: now)
            }
            updateDerivedState(&state)
            return .concatenate(
                loadAvailablePlaces(),
                handleOnAppear(taskID: state.task.id)
            )
            .cancellable(id: CancelID.loadContext, cancelInFlight: true)
        }
    }

    private func syncEditFormFromTask(_ state: inout State) {
        state.editRoutineName = state.task.name ?? ""
        state.editRoutineEmoji = state.task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨"
        state.editRoutineTags = state.task.tags
        state.editTagDraft = ""
        state.editRoutineSteps = state.task.steps
        state.editStepDraft = ""
        state.editSelectedPlaceID = state.task.placeID

        let interval = max(Int(state.task.interval), 1)
        if interval % 30 == 0 {
            state.editFrequency = .month
            state.editFrequencyValue = max(interval / 30, 1)
        } else if interval % 7 == 0 {
            state.editFrequency = .week
            state.editFrequencyValue = max(interval / 7, 1)
        } else {
            state.editFrequency = .day
            state.editFrequencyValue = interval
        }
    }

    private func updateDerivedState(_ state: inout State) {
        let nowStart = calendar.startOfDay(for: now)

        if let lastDone = state.task.lastDone {
            let lastDoneStart = calendar.startOfDay(for: lastDone)
            state.daysSinceLastRoutine = calendar.dateComponents([.day], from: lastDoneStart, to: nowStart).day ?? 0
        } else {
            state.daysSinceLastRoutine = 0
        }

        let doneTodayFromLastDone = state.task.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        let doneTodayFromLogs = state.logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            return calendar.isDate(timestamp, inSameDayAs: now)
        }
        state.isDoneToday = doneTodayFromLastDone || doneTodayFromLogs

        if state.task.isPaused {
            state.overdueDays = 0
        } else {
            state.overdueDays = RoutineDateMath.overdueDays(for: state.task, referenceDate: now, calendar: calendar)
        }
    }

    private func resolvedCompletionDate(for selectedDate: Date?) -> Date {
        let baseDate = selectedDate ?? now
        if calendar.isDate(baseDate, inSameDayAs: now) {
            return now
        }

        let startOfDay = calendar.startOfDay(for: baseDate)
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay) ?? startOfDay
    }

    private func resolvedSelectedDay(for selectedDate: Date?) -> Date {
        calendar.startOfDay(for: selectedDate ?? now)
    }

    private func removeCompletion(on completedDay: Date, from state: inout State) {
        let removedLatestCompletion = state.task.lastDone.map {
            calendar.isDate($0, inSameDayAs: completedDay)
        } ?? false

        state.logs.removeAll { log in
            guard let timestamp = log.timestamp else { return false }
            return calendar.isDate(timestamp, inSameDayAs: completedDay)
        }

        let remainingLatestCompletion = state.logs.compactMap(\.timestamp).max()

        if removedLatestCompletion {
            state.task.lastDone = remainingLatestCompletion
        }

        if state.task.isPaused {
            if let remainingLatestCompletion {
                state.task.scheduleAnchor = remainingLatestCompletion
            } else if removedLatestCompletion {
                state.task.scheduleAnchor = state.task.pausedAt
            }
        } else if removedLatestCompletion {
            state.task.scheduleAnchor = remainingLatestCompletion
        }

        state.task.resetStepProgress()
    }

    private func handleOnAppear(taskID: UUID) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                _ = try RoutineLogHistory.backfillMissingLastDoneLog(for: taskID, in: context)
                let logs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(logs))
            } catch {
                print("Error loading logs: \(error)")
            }
        }
    }

    private func sortedLogsDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
        FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
    }

    private func taskDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineTask> {
        FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
    }

    private func handleMarkAsDone(taskID: UUID, completedAt: Date) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = ModelContext(modelContext().container)
                guard let advancedTask = try RoutineLogHistory.advanceTask(
                    taskID: taskID,
                    completedAt: completedAt,
                    context: context,
                    calendar: calendar
                ) else {
                    return
                }
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                if advancedTask.result != .ignoredAlreadyCompletedToday {
                    await notificationClient.schedule(
                        NotificationCoordinator.notificationPayload(
                            for: advancedTask.task,
                            referenceDate: completedAt,
                            calendar: calendar
                        )
                    )
                }
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }

    private func handleUndoCompletion(taskID: UUID, completedDay: Date) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = ModelContext(modelContext().container)
                guard let updatedTask = try RoutineLogHistory.removeCompletion(
                    taskID: taskID,
                    on: completedDay,
                    context: context,
                    calendar: calendar
                ) else {
                    return
                }
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                await notificationClient.schedule(
                    NotificationCoordinator.notificationPayload(
                        for: updatedTask,
                        referenceDate: now,
                        calendar: calendar
                    )
                )
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Error undoing routine completion: \(error)")
            }
        }
    }

    private func handleEditSave(
        taskID: UUID,
        name: String,
        emoji: String,
        placeID: UUID?,
        tags: [String],
        steps: [RoutineStep],
        interval: Int16
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
                if try hasDuplicateRoutineName(name, in: context, excludingID: taskID) {
                    return
                }
                task.name = name
                task.emoji = emoji
                task.placeID = placeID
                task.tags = tags
                task.replaceSteps(steps)
                task.interval = interval
                if task.scheduleAnchor == nil {
                    task.scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(for: task, referenceDate: now)
                }
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                if task.isPaused {
                    await notificationClient.cancel(task.id.uuidString)
                } else {
                    let payload = NotificationCoordinator.notificationPayload(
                        for: task,
                        referenceDate: now,
                        calendar: calendar
                    )
                    await notificationClient.schedule(payload)
                }
                send(.onAppear)
            } catch {
                print("Error saving routine edits: \(error)")
            }
        }
    }

    private func loadAvailablePlaces() -> Effect<Action> {
        .run { @MainActor send in
            let context = modelContext()
            let places = (try? context.fetch(FetchDescriptor<RoutinePlace>())) ?? []
            let tasks = (try? context.fetch(FetchDescriptor<RoutineTask>())) ?? []
            send(.availablePlacesLoaded(RoutinePlace.summaries(from: places, linkedTo: tasks)))
        }
    }

    private func handleDeleteRoutine(taskID: UUID) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else {
                    send(.routineDeleted)
                    return
                }

                let identifier = task.id.uuidString
                context.delete(task)
                let logs = try context.fetch(allLogsDescriptor(for: task.id))
                for log in logs {
                    context.delete(log)
                }
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                await notificationClient.cancel(identifier)
                send(.routineDeleted)
            } catch {
                print("Error deleting routine: \(error)")
            }
        }
    }

    private func handlePauseRoutine(taskID: UUID, pausedAt: Date) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
                if task.scheduleAnchor == nil {
                    task.scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(for: task, referenceDate: pausedAt)
                }
                task.pausedAt = pausedAt
                try context.save()
                await notificationClient.cancel(taskID.uuidString)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Error pausing routine: \(error)")
            }
        }
    }

    private func handleResumeRoutine(taskID: UUID, resumedAt: Date) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
                task.scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(for: task, resumedAt: resumedAt)
                task.pausedAt = nil
                try context.save()
                let payload = NotificationCoordinator.notificationPayload(
                    for: task,
                    referenceDate: resumedAt,
                    calendar: calendar
                )
                await notificationClient.schedule(payload)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Error resuming routine: \(error)")
            }
        }
    }

    private func allLogsDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
        FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            }
        )
    }

    private func hasDuplicateRoutineName(
        _ name: String,
        in context: ModelContext,
        excludingID: UUID
    ) throws -> Bool {
        guard let normalized = RoutineTask.normalizedName(name) else { return false }
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return tasks.contains { task in
            task.id != excludingID && RoutineTask.normalizedName(task.name) == normalized
        }
    }

    private func appendStep(from draft: String, to currentSteps: [RoutineStep]) -> [RoutineStep] {
        guard let title = RoutineStep.normalizedTitle(draft) else { return currentSteps }
        return currentSteps + [RoutineStep(title: title)]
    }

    private func moveStep(_ stepID: UUID, by offset: Int, state: inout State) {
        guard let index = state.editRoutineSteps.firstIndex(where: { $0.id == stepID }) else { return }
        let targetIndex = index + offset
        guard state.editRoutineSteps.indices.contains(targetIndex) else { return }
        let step = state.editRoutineSteps.remove(at: index)
        state.editRoutineSteps.insert(step, at: targetIndex)
    }
}

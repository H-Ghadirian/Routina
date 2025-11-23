import ComposableArchitecture
import Foundation
import SwiftData
import UserNotifications

struct RoutineDetailFeature: Reducer {
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
        var daysSinceLastRoutine: Int = 0
        var overdueDays: Int = 0
        var isDoneToday: Bool = false
        var isEditSheetPresented: Bool = false
        var editRoutineName: String = ""
        var editRoutineEmoji: String = "✨"
        var editFrequency: EditFrequency = .day
        var editFrequencyValue: Int = 1
        var isDeleteConfirmationPresented: Bool = false
        var shouldDismissAfterDelete: Bool = false
    }

    enum Action: Equatable {
        case markAsDone
        case setEditSheet(Bool)
        case editRoutineNameChanged(String)
        case editRoutineEmojiChanged(String)
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
            let completionDate = now
            state.task.lastDone = completionDate
            state.isDoneToday = true
            state.daysSinceLastRoutine = 0
            state.overdueDays = 0
            return handleMarkAsDone(
                taskID: state.task.id,
                completedAt: completionDate,
                fallbackName: state.task.name,
                fallbackInterval: max(Int(state.task.interval), 1)
            )

        case let .setEditSheet(isPresented):
            state.isEditSheetPresented = isPresented
            if isPresented {
                syncEditFormFromTask(&state)
            }
            return .none

        case let .editRoutineNameChanged(name):
            state.editRoutineName = name
            return .none

        case let .editRoutineEmojiChanged(emoji):
            state.editRoutineEmoji = sanitizedEmoji(from: emoji, fallback: state.editRoutineEmoji)
            return .none

        case let .editFrequencyChanged(frequency):
            state.editFrequency = frequency
            return .none

        case let .editFrequencyValueChanged(value):
            state.editFrequencyValue = value
            return .none

        case .editSaveTapped:
            let trimmedName = state.editRoutineName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return .none }

            state.task.name = trimmedName
            state.task.emoji = state.editRoutineEmoji
            state.task.interval = Int16(state.editFrequencyValue * state.editFrequency.daysMultiplier)
            state.isEditSheetPresented = false
            updateDerivedState(&state)

            return handleEditSave(taskID: state.task.id)

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
            updateDerivedState(&state)
            return handleOnAppear(taskID: state.task.id)
        }
    }

    private func syncEditFormFromTask(_ state: inout State) {
        state.editRoutineName = state.task.name ?? ""
        state.editRoutineEmoji = state.task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨"

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
        let referenceDate = state.task.lastDone ?? now
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

        let dueDate = calendar.date(byAdding: .day, value: Int(state.task.interval), to: referenceDate) ?? now
        let dueStart = calendar.startOfDay(for: dueDate)
        state.overdueDays = max(calendar.dateComponents([.day], from: dueStart, to: nowStart).day ?? 0, 0)
    }

    private func handleOnAppear(taskID: UUID) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                let logs = try context.fetch(sortedLogsDescriptor(for: taskID))
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

    private func handleMarkAsDone(
        taskID: UUID,
        completedAt: Date,
        fallbackName: String?,
        fallbackInterval: Int
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                let task = try context.fetch(taskDescriptor(for: taskID)).first
                task?.lastDone = completedAt

                let log = RoutineLog(timestamp: completedAt, taskID: taskID)
                context.insert(log)
                try context.save()

                let updatedLogs = try context.fetch(sortedLogsDescriptor(for: taskID))
                send(.logsLoaded(updatedLogs))

                let payload = NotificationPayload(
                    identifier: taskID.uuidString,
                    name: task?.name ?? fallbackName,
                    interval: max(task.map { Int($0.interval) } ?? fallbackInterval, 1),
                    lastDone: completedAt
                )
                await notificationClient.schedule(payload)
                NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }

    private func handleEditSave(taskID: UUID) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
                try context.save()
                NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
                let payload = NotificationPayload(
                    identifier: task.id.uuidString,
                    name: task.name,
                    interval: max(Int(task.interval), 1),
                    lastDone: task.lastDone
                )
                await notificationClient.schedule(payload)
                send(.onAppear)
            } catch {
                print("Error saving routine edits: \(error)")
            }
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
                NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
                await notificationClient.cancel(identifier)
                send(.routineDeleted)
            } catch {
                print("Error deleting routine: \(error)")
            }
        }
    }

    private func sanitizedEmoji(from input: String, fallback: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return fallback }
        return String(first)
    }

    private func allLogsDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
        FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            }
        )
    }
}

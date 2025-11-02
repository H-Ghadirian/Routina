import ComposableArchitecture
import CoreData
import UserNotifications
import Foundation

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
    }

    enum Action: Equatable {
        case markAsDone
        case setEditSheet(Bool)
        case editRoutineNameChanged(String)
        case editRoutineEmojiChanged(String)
        case editFrequencyChanged(EditFrequency)
        case editFrequencyValueChanged(Int)
        case editSaveTapped
        case logsLoaded([RoutineLog])
        case onAppear
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .markAsDone:
            state.task.lastDone = now
            state.isDoneToday = true
            state.daysSinceLastRoutine = 0
            state.overdueDays = 0
            return handleMarkAsDone(task: state.task)

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
            state.task.setValue(state.editRoutineEmoji, forKey: "emoji")
            state.task.interval = Int16(state.editFrequencyValue * state.editFrequency.daysMultiplier)
            state.isEditSheetPresented = false
            updateDerivedState(&state)

            return handleEditSave(task: state.task)

        case let .logsLoaded(logs):
            state.logs = logs
            updateDerivedState(&state)
            return .none
        case .onAppear:
            updateDerivedState(&state)
            return handleOnAppear(state.task)
        }
    }

    private func syncEditFormFromTask(_ state: inout State) {
        state.editRoutineName = state.task.name ?? ""
        state.editRoutineEmoji = (state.task.value(forKey: "emoji") as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "✨"

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

        if let lastDone = state.task.lastDone {
            state.daysSinceLastRoutine = calendar.dateComponents([.day], from: lastDone, to: now).day ?? 0
        } else {
            state.daysSinceLastRoutine = 0
        }

        state.isDoneToday = state.logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            return calendar.isDate(timestamp, inSameDayAs: now)
        }

        let dueDate = calendar.date(byAdding: .day, value: Int(state.task.interval), to: referenceDate) ?? now
        state.overdueDays = max(calendar.dateComponents([.day], from: dueDate, to: now).day ?? 0, 0)
    }

    private func handleOnAppear(_ task: RoutineTask) -> Effect<Action> {
        let context = task.managedObjectContext!
        return .run { send in
            do {
                let logs = try await MainActor.run {
                    try context.fetch(sortedDonesFetchRequest(for: task))
                }
                await send(.logsLoaded(logs))
            } catch {
                print("Error loading logs: \(error)")
            }
        }
    }

    private func sortedDonesFetchRequest(
        for task: RoutineTask
    ) -> NSFetchRequest<RoutineLog> {
        let fetchRequest: NSFetchRequest<RoutineLog> = RoutineLog.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "task == %@", task)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return fetchRequest
    }

    private func handleMarkAsDone(task: RoutineTask) -> Effect<Action> {
        let context = task.managedObjectContext!
        return .run { send in
            do {
                let updatedLogs = try await MainActor.run { () -> [RoutineLog] in
                    let log = RoutineLog(context: context)
                    log.timestamp = task.lastDone
                    log.task = task

                    try context.save()
                    return try context.fetch(sortedDonesFetchRequest(for: task))
                }
                await send(.logsLoaded(updatedLogs))
                await notificationClient.schedule(task)
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }

    private func handleEditSave(task: RoutineTask) -> Effect<Action> {
        guard let context = task.managedObjectContext else { return .none }
        return .run { send in
            do {
                try await MainActor.run {
                    try context.save()
                }
                await notificationClient.schedule(task)
                await send(.onAppear)
            } catch {
                print("Error saving routine edits: \(error)")
            }
        }
    }

    private func sanitizedEmoji(from input: String, fallback: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return fallback }
        return String(first)
    }
}

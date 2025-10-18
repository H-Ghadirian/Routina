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
    @Dependency(\.managedObjectContext) var viewContext
    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .markAsDone:
            state.task.lastDone = now
            state.isDoneToday = true
            state.daysSinceLastRoutine = 0
            state.overdueDays = 0
            return handleMarkAsDone(taskID: state.task.objectID)

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

            return handleEditSave(taskID: state.task.objectID)

        case let .setDeleteConfirmation(isPresented):
            state.isDeleteConfirmationPresented = isPresented
            return .none

        case .deleteRoutineConfirmed:
            state.isDeleteConfirmationPresented = false
            return handleDeleteRoutine(taskID: state.task.objectID)

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
            return handleOnAppear(taskID: state.task.objectID)
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

    private func handleOnAppear(taskID: NSManagedObjectID) -> Effect<Action> {
        return .run { @MainActor [viewContext] send in
            do {
                let logs = try viewContext.fetch(sortedDonesFetchRequest(for: taskID, in: viewContext))
                send(.logsLoaded(logs))
            } catch {
                print("Error loading logs: \(error)")
            }
        }
    }

    private func sortedDonesFetchRequest(
        for taskID: NSManagedObjectID,
        in context: NSManagedObjectContext
    ) -> NSFetchRequest<RoutineLog> {
        let fetchRequest: NSFetchRequest<RoutineLog> = RoutineLog.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "task == %@", context.object(with: taskID))
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return fetchRequest
    }

    private func handleMarkAsDone(taskID: NSManagedObjectID) -> Effect<Action> {
        return .run { @MainActor [viewContext] send in
            do {
                guard let task = try viewContext.existingObject(with: taskID) as? RoutineTask else { return }
                if task.objectID.isTemporaryID {
                    try viewContext.obtainPermanentIDs(for: [task])
                }
                let log = RoutineLog(context: viewContext)
                log.timestamp = task.lastDone
                log.task = task

                try viewContext.save()
                let persistedTaskID = task.objectID
                let updatedLogs = try viewContext.fetch(
                    sortedDonesFetchRequest(for: persistedTaskID, in: viewContext)
                )
                send(.logsLoaded(updatedLogs))
                let payload = NotificationPayload(
                    identifier: persistedTaskID.uriRepresentation().absoluteString,
                    name: task.name,
                    interval: max(Int(task.interval), 1),
                    lastDone: task.lastDone
                )
                await notificationClient.schedule(payload)
                NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }

    private func handleEditSave(taskID: NSManagedObjectID) -> Effect<Action> {
        return .run { @MainActor [viewContext] send in
            do {
                guard let task = try viewContext.existingObject(with: taskID) as? RoutineTask else { return }
                try viewContext.save()
                NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
                let payload = NotificationPayload(
                    identifier: task.objectID.uriRepresentation().absoluteString,
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

    private func handleDeleteRoutine(taskID: NSManagedObjectID) -> Effect<Action> {
        return .run { @MainActor [viewContext, notificationClient] send in
            do {
                guard let task = try viewContext.existingObject(with: taskID) as? RoutineTask else {
                    send(.routineDeleted)
                    return
                }

                let identifier = task.objectID.uriRepresentation().absoluteString
                viewContext.delete(task)
                try viewContext.save()
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

}

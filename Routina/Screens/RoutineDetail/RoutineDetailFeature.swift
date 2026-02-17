import ComposableArchitecture
import CoreData
import UserNotifications
import Foundation

struct RoutineDetailFeature: Reducer {
    struct State: Equatable {
        var task: RoutineTask
        var logs: [RoutineLog] = []
        var daysSinceLastRoutine: Int = 0
        var overdueDays: Int = 0
        var isDoneToday: Bool = false
    }

    enum Action: Equatable {
        case markAsDone
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

        case let .logsLoaded(logs):
            state.logs = logs
            updateDerivedState(&state)
            return .none
        case .onAppear:
            updateDerivedState(&state)
            return handleOnAppear(state.task)
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
}

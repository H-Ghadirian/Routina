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
    }

    enum Action: Equatable {
        case markAsDone
        case logsLoaded([RoutineLog])
        case onAppear
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .markAsDone:
            state.task.lastDone = Date()
            return handleMarkAsDone(task: state.task)

        case let .logsLoaded(logs):
            state.logs = logs
            return .none
        case .onAppear:
            return handleOnAppear(state.task)
        }
    }

    private func handleOnAppear(_ task: RoutineTask) -> Effect<Action> {
        let context = task.managedObjectContext!
        return .run { send in
            do {
                let logs = try context.fetch(sortedDonesFetchRequest(for: task))
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
        let log = RoutineLog(context: context)
        log.timestamp = task.lastDone
        log.task = task

        return .run { send in
            do {
                try context.save()
                let updatedLogs = try context.fetch(sortedDonesFetchRequest(for: task))
                await send(.logsLoaded(updatedLogs))
                await notificationClient.schedule(task)
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
}

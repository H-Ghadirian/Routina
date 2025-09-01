import ComposableArchitecture
import CoreData
import Foundation

@Reducer
struct RoutineDetailFeature {

    struct State: Equatable {
        var task: RoutineTask
        var logs: [RoutineLog] = []
        var daysSinceLastRoutine: Int = 0
        var overdueDays: Int = 0
    }

    enum Action: Equatable {
        case onAppear
        case markAsDone
        case logsLoaded([RoutineLog])
        case delegate(DelegateAction)

        enum DelegateAction: Equatable {
            case routineUpdated
        }
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.date.now) var now
    @Dependency(\.managedObjectContext) var viewContext

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let task = state.task
                return .run { send in
                    let logs = try fetchLogs(for: task)
                    await send(.logsLoaded(logs))
                }
                
            case .markAsDone:
                state.task.lastDone = now
                state.daysSinceLastRoutine = 0
                state.overdueDays = 0
                
                let task = state.task
                return .run { send in
                    let log = RoutineLog(context: self.viewContext)
                    log.timestamp = task.lastDone
                    log.task = task
                    
                    try self.viewContext.save()
                    let updatedLogs = try fetchLogs(for: task)
                    await send(.logsLoaded(updatedLogs))
                    
                    await self.notificationClient.schedule(task)
                    await send(.delegate(.routineUpdated))
                    
                } catch: { error, _ in
                    print("Error marking as done: \(error)")
                }

            case let .logsLoaded(logs):
                state.logs = logs
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
    
    private func fetchLogs(for task: RoutineTask) throws -> [RoutineLog] {
        let fetchRequest: NSFetchRequest<RoutineLog> = RoutineLog.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "task == %@", task)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return try viewContext.fetch(fetchRequest)
    }
}

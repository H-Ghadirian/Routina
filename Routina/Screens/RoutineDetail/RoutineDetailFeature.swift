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

    @Dependency(\.uuid) var uuid
    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .markAsDone:
            let context = state.task.managedObjectContext!
            let now = Date()

            state.task.lastDone = now
            let log = RoutineLog(context: context)
            log.timestamp = now
            log.task = state.task

            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }

            let task = state.task
            return .run { _ in
#if os(iOS)
                await scheduleNotification(for: task)
#endif
            }

        case let .logsLoaded(logs):
            state.logs = logs
            return .none
            
        case .onAppear:
            let task = state.task
            let context = task.managedObjectContext!
            return .run { send in
                let fetchRequest: NSFetchRequest<RoutineLog> = RoutineLog.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "task == %@", task)
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
                
                do {
                    let logs = try context.fetch(fetchRequest)
                    await send(.logsLoaded(logs))
                } catch {
                    print("Error loading logs: \(error)")
                }
            }
        }
    }

#if os(iOS)
    private func scheduleNotification(for task: RoutineTask) async {
        let content = UNMutableNotificationContent()
        content.title = "Time to complete \(task.name ?? "your routine")!"
        content.body = "Your routine is due today."
        content.sound = .default

        let dueDate = Calendar.current.date(byAdding: .day, value: Int(task.interval), to: task.lastDone ?? Date()) ?? Date()
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: task.objectID.uriRepresentation().absoluteString, content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }
#endif
}

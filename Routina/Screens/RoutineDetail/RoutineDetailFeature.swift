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

        do {
            try context.save()
            let updatedLogs = try context.fetch(sortedDonesFetchRequest(for: task))
            return .send(.logsLoaded(updatedLogs))
        } catch {
            print("Error saving context: \(error)")
            return .none
        }
    }

#if os(iOS)
    private func scheduleNotification(for task: RoutineTask) async {
        let content = UNMutableNotificationContent()
        content.title = "Time to complete \(task.name ?? "your routine")!"
        content.body = "Your routine is due today."
        content.sound = .default

        let dueDate = Calendar.current.date(
            byAdding: .day,
            value: Int(task.interval),
            to: task.lastDone ?? Date()
        ) ?? Date()
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerDate,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: task.objectID.uriRepresentation().absoluteString,
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
#endif
}

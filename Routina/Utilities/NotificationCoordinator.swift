import Foundation
import SwiftData
import UserNotifications

enum NotificationCoordinator {
    static let categoryIdentifier = "ROUTINE_REMINDER"
    static let doneActionIdentifier = "ROUTINE_DONE"
    static let snoozeActionIdentifier = "ROUTINE_SNOOZE"

    static func configureCurrentCenter(delegate: UNUserNotificationCenterDelegate) {
        let doneAction = UNNotificationAction(
            identifier: doneActionIdentifier,
            title: "Done"
        )
        let snoozeAction = UNNotificationAction(
            identifier: snoozeActionIdentifier,
            title: "Snooze"
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [doneAction, snoozeAction],
            intentIdentifiers: []
        )

        let center = UNUserNotificationCenter.current()
        center.delegate = delegate
        center.setNotificationCategories([category])
    }

    static func notificationPayload(
        for task: RoutineTask,
        triggerDate: Date? = nil,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> NotificationPayload {
        let dueDate = RoutineDateMath.dueDate(for: task, referenceDate: referenceDate, calendar: calendar)
        return NotificationPayload(
            identifier: task.id.uuidString,
            name: task.name,
            emoji: task.emoji,
            interval: max(Int(task.interval), 1),
            lastDone: task.lastDone,
            triggerDate: triggerDate ?? NotificationPreferences.reminderDate(on: dueDate, calendar: calendar),
            isPaused: task.isPaused
        )
    }

    @MainActor
    static func handleResponse(
        actionIdentifier: String,
        requestIdentifier: String
    ) async {
        guard let taskID = UUID(uuidString: requestIdentifier) else { return }

        switch actionIdentifier {
        case doneActionIdentifier:
            await markTaskDone(taskID: taskID)
        case snoozeActionIdentifier:
            await snoozeTask(taskID: taskID)
        default:
            NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
        }
    }

    @MainActor
    private static func markTaskDone(taskID: UUID) async {
        let context = PersistenceController.shared.container.mainContext

        do {
            guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
            guard !task.isPaused else { return }
            let now = Date()

            if let lastDone = task.lastDone,
               Calendar.current.isDate(lastDone, inSameDayAs: now) {
                await NotificationClient.live.schedule(notificationPayload(for: task, referenceDate: now))
                return
            }

            task.lastDone = now
            task.scheduleAnchor = now
            context.insert(RoutineLog(timestamp: now, taskID: taskID))
            try context.save()
            await NotificationClient.live.schedule(notificationPayload(for: task, referenceDate: now))
            NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
        } catch {
            context.rollback()
            NSLog("Notification action failed to mark routine done: \(error.localizedDescription)")
        }
    }

    @MainActor
    private static func snoozeTask(taskID: UUID) async {
        let context = PersistenceController.shared.container.mainContext

        do {
            guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
            guard !task.isPaused else { return }
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let payload = notificationPayload(
                for: task,
                triggerDate: NotificationPreferences.reminderDate(on: tomorrow),
                referenceDate: Date()
            )
            await NotificationClient.live.schedule(payload)
        } catch {
            NSLog("Notification action failed to snooze routine: \(error.localizedDescription)")
        }
    }

    private static func taskDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineTask> {
        FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
    }
}

import Foundation
import SwiftData
import UserNotifications

extension Notification.Name {
    static let routineDidUpdate = Notification.Name("routineDidUpdate")
}

extension NotificationCenter {
    func postRoutineDidUpdate() {
        post(name: .routineDidUpdate, object: nil)
    }
}

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
            isPaused: task.isPaused,
            isChecklistDriven: task.isChecklistDriven,
            isChecklistCompletionRoutine: task.isChecklistCompletionRoutine,
            nextDueChecklistItemTitle: task.nextDueChecklistItem(referenceDate: referenceDate, calendar: calendar)?.title
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
            NotificationCenter.default.postRoutineDidUpdate()
        }
    }

    @MainActor
    private static func markTaskDone(taskID: UUID) async {
        let context = PersistenceController.shared.container.mainContext

        do {
            let now = Date()
            let descriptor = taskDescriptor(for: taskID)
            guard let task = try context.fetch(descriptor).first else { return }

            if task.isChecklistCompletionRoutine {
                NotificationCenter.default.postRoutineDidUpdate()
                return
            }

            if task.isChecklistDriven {
                guard let updatedTask = try RoutineLogHistory.markDueChecklistItemsPurchased(
                    taskID: taskID,
                    purchasedAt: now,
                    context: context,
                    calendar: .current
                ) else {
                    return
                }
                await NotificationClient.live.schedule(notificationPayload(for: updatedTask.task, referenceDate: now))
                NotificationCenter.default.postRoutineDidUpdate()
                return
            }

            guard let advancedTask = try RoutineLogHistory.advanceTask(
                taskID: taskID,
                completedAt: now,
                context: context,
                calendar: .current
            ) else {
                return
            }
            await NotificationClient.live.schedule(notificationPayload(for: advancedTask.task, referenceDate: now))
            NotificationCenter.default.postRoutineDidUpdate()
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

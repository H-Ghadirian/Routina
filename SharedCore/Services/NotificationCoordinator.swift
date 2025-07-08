import Foundation
import SwiftData
import UserNotifications
#if canImport(WidgetKit)
import WidgetKit
#endif

extension Notification.Name {
    static let routineDidUpdate = Notification.Name("routineDidUpdate")
    static let routineTagDidRename = Notification.Name("routineTagDidRename")
    static let routineTagDidDelete = Notification.Name("routineTagDidDelete")
}

extension NotificationCenter {
    func postRoutineDidUpdate() {
        post(name: .routineDidUpdate, object: nil)
#if canImport(WidgetKit)
        Task { @MainActor in
            WidgetStatsService.refresh(using: PersistenceController.shared.container)
            WidgetCenter.shared.reloadAllTimelines()
        }
#endif
    }

    func postRoutineTagDidRename(from oldName: String, to newName: String) {
        post(
            name: .routineTagDidRename,
            object: nil,
            userInfo: [
                RoutineTagNotificationKey.oldName.rawValue: oldName,
                RoutineTagNotificationKey.newName.rawValue: newName
            ]
        )
    }

    func postRoutineTagDidDelete(_ tagName: String) {
        post(
            name: .routineTagDidDelete,
            object: nil,
            userInfo: [
                RoutineTagNotificationKey.tagName.rawValue: tagName
            ]
        )
    }
}

enum RoutineTagNotificationKey: String {
    case oldName
    case newName
    case tagName
}

extension Notification {
    var routineTagRenamePayload: (oldName: String, newName: String)? {
        guard
            let oldName = userInfo?[RoutineTagNotificationKey.oldName.rawValue] as? String,
            let newName = userInfo?[RoutineTagNotificationKey.newName.rawValue] as? String
        else {
            return nil
        }
        return (oldName, newName)
    }

    var routineTagDeletedName: String? {
        userInfo?[RoutineTagNotificationKey.tagName.rawValue] as? String
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
        isArchivedOverride: Bool? = nil,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> NotificationPayload {
        let dueDate = RoutineDateMath.dueDate(for: task, referenceDate: referenceDate, calendar: calendar)
        let resolvedTriggerDate = triggerDate ?? {
            if task.recurrenceRule.usesExplicitTimeOfDay {
                return dueDate
            }
            return NotificationPreferences.reminderDate(on: dueDate, calendar: calendar)
        }()
        return NotificationPayload(
            identifier: task.id.uuidString,
            name: task.name,
            emoji: task.emoji,
            interval: max(Int(task.interval), 1),
            lastDone: task.lastDone,
            triggerDate: resolvedTriggerDate,
            isArchived: isArchivedOverride ?? task.isArchived(referenceDate: referenceDate, calendar: calendar),
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
                await scheduleNotification(notificationPayload(for: updatedTask.task, referenceDate: now))
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
            if advancedTask.task.isOneOffTask {
                cancelNotification(taskID.uuidString)
            } else {
                await scheduleNotification(notificationPayload(for: advancedTask.task, referenceDate: now))
            }
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
            guard !task.isArchived() else { return }
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let payload = notificationPayload(
                for: task,
                triggerDate: NotificationPreferences.reminderDate(on: tomorrow),
                isArchivedOverride: false,
                referenceDate: Date()
            )
            await scheduleNotification(payload)
        } catch {
            NSLog("Notification action failed to snooze routine: \(error.localizedDescription)")
        }
    }

    private static func cancelNotification(_ identifier: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private static func createNotificationTrigger(for payload: NotificationPayload) -> UNCalendarNotificationTrigger {
        let calendar = Calendar.current
        let now = Date()

        let targetDate: Date
        if let triggerDate = payload.triggerDate {
            targetDate = triggerDate
        } else {
            let dueDate = calendar.date(
                byAdding: .day,
                value: payload.interval,
                to: payload.lastDone ?? now
            ) ?? now
            let preferredReminderDate = NotificationPreferences.reminderDate(on: dueDate, calendar: calendar)
            targetDate = preferredReminderDate > now
                ? preferredReminderDate
                : NotificationPreferences.nextReminderDate(after: now, calendar: calendar)
        }

        let safeDate = targetDate > now ? targetDate : now.addingTimeInterval(60)
        let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: safeDate)
        return UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
    }

    private static func createNotificationContent(for payload: NotificationPayload) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let trimmedName = payload.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleName = (trimmedName?.isEmpty == false ? trimmedName : nil) ?? "Your routine"
        let trimmedEmoji = payload.emoji?.trimmingCharacters(in: .whitespacesAndNewlines)
        let emojiPrefix = (trimmedEmoji?.isEmpty == false ? trimmedEmoji : nil).map { "\($0) " } ?? ""

        content.title = "\(emojiPrefix)\(titleName) is due"
        if payload.isChecklistDriven, let nextDueChecklistItemTitle = payload.nextDueChecklistItemTitle {
            content.body = "\(nextDueChecklistItemTitle) is due today. Tap Done to buy due items or Snooze until tomorrow."
        } else if payload.isChecklistDriven {
            content.body = "Checklist items are due today. Tap Done to buy due items or Snooze until tomorrow."
        } else if payload.isChecklistCompletionRoutine {
            content.body = "Due today. Open the app to complete each checklist item."
        } else {
            content.body = "Due today. Tap Done to reset the timer or Snooze until tomorrow."
        }
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        return content
    }

    private static func scheduleNotification(_ payload: NotificationPayload) async {
        guard NotificationPreferences.notificationsEnabled else { return }
        guard !payload.isArchived else {
            cancelNotification(payload.identifier)
            return
        }

        let request = UNNotificationRequest(
            identifier: payload.identifier,
            content: createNotificationContent(for: payload),
            trigger: createNotificationTrigger(for: payload)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func taskDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineTask> {
        FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
    }
}

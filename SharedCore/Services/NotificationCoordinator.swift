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
            FocusTimerWidgetService.refresh(using: PersistenceController.shared.container)
#if os(iOS) && canImport(ActivityKit)
            await FocusTimerLiveActivityService.sync(using: PersistenceController.shared.container)
#endif
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

    static func shouldScheduleNotification(
        for task: RoutineTask,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard !task.isArchived(referenceDate: referenceDate, calendar: calendar) else { return false }

        if let reminderDate = activeReminderDate(for: task, referenceDate: referenceDate) {
            return reminderDate > referenceDate
        }

        if task.isOneOffTask {
            guard !task.isCompletedOneOff, !task.isCanceledOneOff else { return false }
            guard let deadline = task.deadline else { return false }
            return deadline > referenceDate
        }

        return !task.isSoftIntervalRoutine && !task.isOngoing
    }

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
        let reminderDate = activeReminderDate(for: task, referenceDate: referenceDate)
        let resolvedTriggerDate = triggerDate ?? {
            if let reminderDate {
                return reminderDate
            }
            if task.isOneOffTask {
                return task.deadline
            }
            if task.recurrenceRule.usesExplicitTimeOfDay {
                return dueDate
            }
            return NotificationPreferences.reminderDate(on: dueDate, calendar: calendar)
        }()
        let usesExactTime = reminderDate != nil || task.isOneOffTask || task.recurrenceRule.usesExplicitTimeOfDay
        return NotificationPayload(
            identifier: task.id.uuidString,
            name: task.name,
            emoji: task.emoji,
            interval: max(Int(task.interval), 1),
            lastDone: task.lastDone,
            dueDate: dueDate,
            triggerDate: resolvedTriggerDate,
            isOneOffTask: task.isOneOffTask,
            isCustomReminder: reminderDate != nil,
            isArchived: isArchivedOverride ?? task.isArchived(referenceDate: referenceDate, calendar: calendar),
            usesExactTime: usesExactTime,
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
        case UNNotificationDefaultActionIdentifier:
            RoutinaDeepLinkDispatcher.open(.task(taskID))
            NotificationCenter.default.postRoutineDidUpdate()
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
            if !shouldScheduleNotification(for: advancedTask.task, referenceDate: now) {
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
            let now = Date()
            guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
            guard !task.isArchived(referenceDate: now) else { return }
            let calendar = Calendar.current
            let tomorrow = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: now)
            ) ?? now
            task.snoozedUntil = tomorrow
            try context.save()
            let payload = notificationPayload(
                for: task,
                triggerDate: NotificationPreferences.reminderDate(on: tomorrow, calendar: calendar),
                isArchivedOverride: false,
                referenceDate: tomorrow,
                calendar: calendar
            )
            await scheduleNotification(payload)
            NotificationCenter.default.postRoutineDidUpdate()
        } catch {
            context.rollback()
            NSLog("Notification action failed to snooze routine: \(error.localizedDescription)")
        }
    }

    private static func cancelNotification(_ identifier: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    static func createNotificationTrigger(
        for payload: NotificationPayload,
        now: Date = Date()
    ) -> UNCalendarNotificationTrigger {
        let calendar = Calendar.current

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

        let safeDate: Date
        if targetDate > now {
            safeDate = targetDate
        } else if payload.usesExactTime {
            safeDate = now.addingTimeInterval(60)
        } else {
            safeDate = NotificationPreferences.nextReminderDate(after: now, calendar: calendar)
        }
        let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: safeDate)
        return UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
    }

    static func createNotificationContent(for payload: NotificationPayload) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let trimmedName = payload.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleName = (trimmedName?.isEmpty == false ? trimmedName : nil) ?? (payload.isOneOffTask ? "Your task" : "Your routine")
        let trimmedEmoji = payload.emoji?.trimmingCharacters(in: .whitespacesAndNewlines)
        let emojiPrefix = (trimmedEmoji?.isEmpty == false ? trimmedEmoji : nil).map { "\($0) " } ?? ""

        if payload.isCustomReminder {
            content.title = "\(emojiPrefix)\(titleName) reminder"
        } else {
            content.title = payload.isOneOffTask ? "\(emojiPrefix)\(titleName) deadline" : "\(emojiPrefix)\(titleName) is due"
        }
        content.subtitle = notificationSubtitle(for: payload)
        if payload.isCustomReminder {
            content.body = customReminderNotificationBody(for: payload)
        } else if payload.isOneOffTask {
            content.body = oneOffNotificationBody(for: payload)
        } else if payload.isChecklistDriven, let nextDueChecklistItemTitle = payload.nextDueChecklistItemTitle {
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
#if os(iOS) || os(macOS)
        if #available(iOS 15.0, macOS 12.0, *) {
            content.interruptionLevel = payload.usesExactTime ? .timeSensitive : .active
            content.relevanceScore = payload.usesExactTime ? 1.0 : 0.5
        }
#endif
        return content
    }

    private static func notificationSubtitle(for payload: NotificationPayload) -> String {
        guard payload.usesExactTime, let dueDate = payload.dueDate else { return "" }
        if payload.isCustomReminder, let triggerDate = payload.triggerDate {
            return "Reminder \(triggerDate.formatted(date: .abbreviated, time: .shortened))"
        }
        if payload.isOneOffTask {
            return "Due \(dueDate.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Scheduled for \(dueDate.formatted(date: .omitted, time: .shortened))"
    }

    private static func oneOffNotificationBody(for payload: NotificationPayload) -> String {
        guard let dueDate = payload.dueDate else {
            return "This task is due now. Open Routina to review it."
        }
        return "This task is due \(dueDate.formatted(date: .abbreviated, time: .shortened)). Open Routina to mark it done or update the deadline."
    }

    private static func customReminderNotificationBody(for payload: NotificationPayload) -> String {
        if payload.isOneOffTask, let dueDate = payload.dueDate {
            return "This task is due \(dueDate.formatted(date: .abbreviated, time: .shortened)). Open Routina to review it."
        }
        return "Open Routina to review this routine."
    }

    private static func activeReminderDate(
        for task: RoutineTask,
        referenceDate: Date
    ) -> Date? {
        guard let reminderAt = task.reminderAt, reminderAt > referenceDate else { return nil }
        if task.isOneOffTask {
            guard !task.isCompletedOneOff, !task.isCanceledOneOff else { return nil }
        }
        return reminderAt
    }

    private static func scheduleNotification(_ payload: NotificationPayload) async {
        guard NotificationPreferences.notificationsEnabled else { return }
        guard !payload.isArchived else {
            cancelNotification(payload.identifier)
            return
        }

        cancelNotification(payload.identifier)
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

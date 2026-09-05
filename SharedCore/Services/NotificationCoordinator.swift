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
    func postRoutineDidUpdate(widgetRefreshDelayMilliseconds: Int64? = nil) {
        post(name: .routineDidUpdate, object: nil)
        #if canImport(WidgetKit)
            Task { @MainActor in
                RoutineWidgetRefreshScheduler.schedule(delayMilliseconds: widgetRefreshDelayMilliseconds)
            }
        #endif
    }

    func postRoutineTagDidRename(from oldName: String, to newName: String) {
        post(
            name: .routineTagDidRename,
            object: nil,
            userInfo: [
                RoutineTagNotificationKey.oldName.rawValue: oldName,
                RoutineTagNotificationKey.newName.rawValue: newName,
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

#if canImport(WidgetKit)
    @MainActor
    private enum RoutineWidgetRefreshScheduler {
        private static var pendingTask: Task<Void, Never>?
        private static let defaultWidgetRefreshQuietWindowMilliseconds: Int64 = 1_500

        static func schedule(delayMilliseconds: Int64? = nil) {
            pendingTask?.cancel()
            guard MacAppWidgetAvailability.isEnabled else { return }

            pendingTask = Task { @MainActor in
                let quietWindowMilliseconds = delayMilliseconds ?? defaultWidgetRefreshQuietWindowMilliseconds
                try? await Task.sleep(for: .milliseconds(quietWindowMilliseconds))
                guard !Task.isCancelled else { return }
                guard MacAppWidgetAvailability.isEnabled else { return }

                WidgetStatsService.refresh(using: PersistenceController.shared.container)
                FocusTimerWidgetService.refresh(using: PersistenceController.shared.container)
                #if os(iOS) && canImport(ActivityKit)
                    await FocusTimerLiveActivityService.sync(using: PersistenceController.shared.container)
                #endif
                #if os(macOS)
                    MacAppWidgetAvailability.reloadTimelines()
                #else
                    WidgetCenter.shared.reloadAllTimelines()
                #endif
            }
        }
    }
#endif

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
    static let eventNotificationIdentifierPrefix = "event-"
    static let advancedOccurrenceNotificationLimit = 12
    static let advancedOccurrenceIdentifierMarker = NotificationRequestMetadata.advancedOccurrenceIdentifierMarker

    static func shouldScheduleNotification(
        for task: RoutineTask,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard !task.isArchived(referenceDate: referenceDate, calendar: calendar) else { return false }
        guard !RoutineAssumedCompletion.isEligible(task) else { return false }

        if let reminderDate = activeReminderDate(for: task, referenceDate: referenceDate) {
            return reminderDate > referenceDate
        }

        if task.isOneOffTask {
            guard !task.isCompletedOneOff, !task.isCanceledOneOff else { return false }
            guard let deadline = task.deadline else { return false }
            return deadline > referenceDate
        }

        guard task.usesEffectiveRoutineCadence else { return false }

        if task.recurrenceRule.usesAdvancedModel {
            guard !task.isSoftIntervalRoutine, !task.isOngoing else { return false }
            return RoutineDateMath.upcomingDueDate(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ) != .distantFuture
        }

        if RoutineDateMath.usesExactTimedOccurrences(for: task) {
            return RoutineDateMath.upcomingDueDate(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ) > referenceDate
        }

        return !task.isSoftIntervalRoutine && !task.isOngoing
    }

    static func shouldScheduleNotification(
        for event: RoutineEvent,
        referenceDate: Date = Date()
    ) -> Bool {
        guard let reminderAt = event.reminderAt else { return false }
        guard reminderAt > referenceDate else { return false }
        if let endedAt = event.endedAt, endedAt <= referenceDate {
            return false
        }
        return true
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
        let dueDate: Date? =
            task.isOneOffTask
            ? task.deadline
            : RoutineDateMath.upcomingDueDate(for: task, referenceDate: referenceDate, calendar: calendar)
        let reminderDate = activeReminderDate(for: task, referenceDate: referenceDate)
        let resolvedTriggerDate =
            triggerDate
            ?? {
                if let reminderDate {
                    return reminderDate
                }
                if task.isOneOffTask {
                    return task.deadline
                }
                if task.recurrenceRule.usesTimeConstraint {
                    return dueDate
                }
                return dueDate.map { NotificationPreferences.reminderDate(on: $0, calendar: calendar) }
            }()
        let usesExactTime = reminderDate != nil || task.isOneOffTask || task.recurrenceRule.usesTimeConstraint
        let recurrenceOccurrenceDates =
            triggerDate == nil
            ? advancedNotificationOccurrenceDates(
                for: task,
                dueDate: dueDate,
                referenceDate: referenceDate,
                calendar: calendar
            )
            : []
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
            nextDueChecklistItemTitle: task.nextDueChecklistItem(referenceDate: referenceDate, calendar: calendar)?.title,
            recurrenceOccurrenceDates: recurrenceOccurrenceDates
        )
    }

    static func notificationPayload(
        for event: RoutineEvent,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> NotificationPayload {
        let eventDate = RoutineEvent.reminderEventDate(
            startedAt: event.startedAt,
            isAllDay: event.isAllDay,
            calendar: calendar
        )
        return NotificationPayload(
            identifier: eventNotificationIdentifier(for: event.id),
            kind: .event,
            name: event.displayTitle,
            emoji: event.emoji,
            interval: 1,
            lastDone: nil,
            dueDate: eventDate ?? event.startedAt,
            triggerDate: event.reminderAt,
            isOneOffTask: false,
            isCustomReminder: true,
            isArchived: !shouldScheduleNotification(for: event, referenceDate: referenceDate),
            usesExactTime: true,
            isChecklistDriven: false,
            isChecklistCompletionRoutine: false,
            nextDueChecklistItemTitle: nil,
            deepLink: .event(event.id),
            isAllDayEvent: event.isAllDay
        )
    }

    static func eventNotificationIdentifier(for eventID: UUID) -> String {
        "\(eventNotificationIdentifierPrefix)\(eventID.uuidString)"
    }

    static func cancelNotification(_ identifier: String) {
        let center = UNUserNotificationCenter.current()
        let identifiers = notificationIdentifiers(for: identifier)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    static func createNotificationTrigger(
        for payload: NotificationPayload,
        now: Date = Date()
    ) -> UNCalendarNotificationTrigger? {
        resolvedNotificationDate(for: payload, now: now).map(createNotificationTrigger(at:))
    }

    static func resolvedNotificationDate(
        for payload: NotificationPayload,
        now: Date = Date()
    ) -> Date? {
        let calendar = Calendar.current

        let targetDate: Date
        if let triggerDate = payload.triggerDate {
            targetDate = triggerDate
        } else {
            let dueDate =
                calendar.date(
                    byAdding: .day,
                    value: payload.interval,
                    to: payload.lastDone ?? now
                ) ?? now
            let preferredReminderDate = NotificationPreferences.reminderDate(on: dueDate, calendar: calendar)
            targetDate =
                preferredReminderDate > now
                ? preferredReminderDate
                : NotificationPreferences.nextReminderDate(after: now, calendar: calendar)
        }

        let safeDate: Date
        if targetDate > now {
            safeDate = targetDate
        } else if payload.usesExactTime {
            return nil
        } else {
            safeDate = NotificationPreferences.nextReminderDate(after: now, calendar: calendar)
        }
        return NotificationSchedulingOverrideStore.normalizedOccurrenceDate(safeDate)
    }

    private static func activeReminderDate(
        for task: RoutineTask,
        referenceDate: Date
    ) -> Date? {
        guard task.isOneOffTask else { return nil }
        guard let reminderAt = task.reminderAt, reminderAt > referenceDate else { return nil }
        guard !task.isCompletedOneOff, !task.isCanceledOneOff else { return nil }
        return reminderAt
    }
}

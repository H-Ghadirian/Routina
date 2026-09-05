import Foundation
import SwiftData
import UserNotifications

extension NotificationCoordinator {
    @MainActor
    static func handleResponse(
        actionIdentifier: String,
        requestIdentifier: String,
        occurrenceDate: Date? = nil
    ) async {
        guard let taskID = taskID(fromNotificationIdentifier: requestIdentifier) else { return }

        switch actionIdentifier {
        case doneActionIdentifier:
            await markTaskDone(taskID: taskID, occurrenceDate: occurrenceDate)
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
    private static func markTaskDone(taskID: UUID, occurrenceDate: Date?) async {
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
                guard
                    let updatedTask = try RoutineLogHistory.markDueChecklistItemsDone(
                        taskID: taskID,
                        doneAt: now,
                        context: context,
                        calendar: .current
                    )
                else {
                    return
                }
                await scheduleNotification(notificationPayload(for: updatedTask.task, referenceDate: now))
                NotificationCenter.default.postRoutineDidUpdate()
                return
            }

            let completionDate: Date
            let logs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
            if let occurrenceDate,
                RoutineDateMath.canMarkSelectedExactTimedOccurrenceDone(
                    for: task,
                    completionDate: occurrenceDate,
                    referenceDate: now,
                    logs: logs,
                    calendar: .current
                )
            {
                completionDate = occurrenceDate
            } else if let exactTimedTarget = RoutineDateMath.completionTargetDate(
                for: task,
                selectedDay: now,
                referenceDate: now,
                calendar: .current
            ) {
                completionDate = exactTimedTarget
            } else if RoutineDateMath.usesExactTimedOccurrences(for: task) {
                if shouldScheduleNotification(for: task, referenceDate: now) {
                    await scheduleNotification(notificationPayload(for: task, referenceDate: now))
                } else {
                    cancelNotification(taskID.uuidString)
                }
                NotificationCenter.default.postRoutineDidUpdate()
                return
            } else {
                completionDate = now
            }

            guard RoutineDateMath.canMarkDone(for: task, referenceDate: completionDate, calendar: .current) else {
                return
            }

            guard
                let advancedTask = try RoutineLogHistory.advanceTask(
                    taskID: taskID,
                    completedAt: completionDate,
                    referenceDate: now,
                    context: context,
                    calendar: .current
                )
            else {
                return
            }
            if !shouldScheduleNotification(for: advancedTask.task, referenceDate: completionDate) {
                cancelNotification(taskID.uuidString)
            } else {
                await scheduleNotification(notificationPayload(for: advancedTask.task, referenceDate: completionDate))
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
            let tomorrow =
                calendar.date(
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

    static func createNotificationContent(
        for payload: NotificationPayload,
        originalScheduledAt: Date? = nil
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let trimmedName = payload.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTitle: String
        switch payload.kind {
        case .task:
            fallbackTitle = payload.isOneOffTask ? "Your one-time task" : "Your repeating task"
        case .event:
            fallbackTitle = "Your event"
        }
        let titleName = (trimmedName?.isEmpty == false ? trimmedName : nil) ?? fallbackTitle
        let trimmedEmoji = payload.emoji?.trimmingCharacters(in: .whitespacesAndNewlines)
        let emojiPrefix = (trimmedEmoji?.isEmpty == false ? trimmedEmoji : nil).map { "\($0) " } ?? ""

        if payload.kind == .event {
            content.title = "\(emojiPrefix)\(titleName) reminder"
            content.subtitle = eventNotificationSubtitle(for: payload)
            content.body = eventNotificationBody(for: payload)
            content.sound = .default
            if let deepLink = payload.deepLink {
                content.userInfo = deepLink.notificationUserInfo
            }
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
            addSchedulingMetadata(
                to: content,
                payload: payload,
                sourceTitle: "\(emojiPrefix)\(titleName)",
                originalScheduledAt: originalScheduledAt
            )
            return content
        }

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
            content.body = "\(nextDueChecklistItemTitle) is due today. Tap Done to reset due items or Snooze until tomorrow."
        } else if payload.isChecklistDriven {
            content.body = "Checklist items are due today. Tap Done to reset due items or Snooze until tomorrow."
        } else if payload.isChecklistCompletionRoutine {
            content.body = "Due today. Open the app to complete each checklist item."
        } else {
            content.body = "Due today. Tap Done to reset the timer or Snooze until tomorrow."
        }
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.interruptionLevel = payload.usesExactTime ? .timeSensitive : .active
        content.relevanceScore = payload.usesExactTime ? 1.0 : 0.5
        addSchedulingMetadata(
            to: content,
            payload: payload,
            sourceTitle: "\(emojiPrefix)\(titleName)",
            originalScheduledAt: originalScheduledAt
        )
        return content
    }

    private static func eventNotificationSubtitle(for payload: NotificationPayload) -> String {
        guard let dueDate = payload.dueDate else { return "" }
        if payload.isAllDayEvent {
            return "Event \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Starts \(dueDate.formatted(date: .abbreviated, time: .shortened))"
    }

    private static func eventNotificationBody(for payload: NotificationPayload) -> String {
        guard let dueDate = payload.dueDate else {
            return "Open Routina to review this event."
        }
        if payload.isAllDayEvent {
            return "This event is on \(dueDate.formatted(date: .abbreviated, time: .omitted)). Open Routina to review it."
        }
        return "This event starts \(dueDate.formatted(date: .abbreviated, time: .shortened)). Open Routina to review it."
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
        return
            "This task is due \(dueDate.formatted(date: .abbreviated, time: .shortened)). Open Routina to mark it done or update the deadline."
    }

    private static func customReminderNotificationBody(for payload: NotificationPayload) -> String {
        if payload.isOneOffTask, let dueDate = payload.dueDate {
            return "This task is due \(dueDate.formatted(date: .abbreviated, time: .shortened)). Open Routina to review it."
        }
        return "Open Routina to review this repeating task."
    }

    static func scheduleNotification(_ payload: NotificationPayload) async {
        guard NotificationPreferences.notificationsEnabled else { return }
        guard !payload.isArchived else {
            cancelNotification(payload.identifier)
            return
        }

        cancelNotification(payload.identifier)
        let now = Date()
        if !payload.recurrenceOccurrenceDates.isEmpty {
            for (index, occurrence) in payload.recurrenceOccurrenceDates
                .prefix(advancedOccurrenceNotificationLimit)
                .enumerated()
            {
                let occurrencePayload = payload.forRecurrenceOccurrence(occurrence)
                guard
                    let originalScheduledAt = resolvedNotificationDate(
                        for: occurrencePayload,
                        now: now
                    )
                else {
                    continue
                }
                guard
                    let scheduledAt = await effectiveScheduledDate(
                        sourceIdentifier: payload.identifier,
                        originalScheduledAt: originalScheduledAt,
                        now: now
                    )
                else {
                    continue
                }
                let request = UNNotificationRequest(
                    identifier: advancedOccurrenceIdentifier(base: payload.identifier, index: index),
                    content: createNotificationContent(
                        for: occurrencePayload,
                        originalScheduledAt: originalScheduledAt
                    ),
                    trigger: createNotificationTrigger(at: scheduledAt)
                )
                try? await UNUserNotificationCenter.current().add(request)
            }
            return
        }
        guard let originalScheduledAt = resolvedNotificationDate(for: payload, now: now) else {
            return
        }
        guard
            let scheduledAt = await effectiveScheduledDate(
                sourceIdentifier: payload.identifier,
                originalScheduledAt: originalScheduledAt,
                now: now
            )
        else {
            return
        }
        let request = UNNotificationRequest(
            identifier: payload.identifier,
            content: createNotificationContent(
                for: payload,
                originalScheduledAt: originalScheduledAt
            ),
            trigger: createNotificationTrigger(at: scheduledAt)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func removeScheduledNotification(_ notification: ScheduledNotificationSummary) async {
        if let originalScheduledAt = notification.originalScheduledAt {
            await NotificationSchedulingOverrideStore.shared.skip(
                sourceIdentifier: notification.sourceIdentifier,
                originalScheduledAt: originalScheduledAt
            )
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notification.identifier]
        )
    }

    static func pauseScheduledNotification(
        _ notification: ScheduledNotificationSummary,
        until requestedDate: Date
    ) async {
        guard let originalScheduledAt = notification.originalScheduledAt else { return }
        let now = Date()
        let pausedUntil = NotificationSchedulingOverrideStore.normalizedOccurrenceDate(
            max(requestedDate, now.addingTimeInterval(60))
        )
        await NotificationSchedulingOverrideStore.shared.pause(
            sourceIdentifier: notification.sourceIdentifier,
            originalScheduledAt: originalScheduledAt,
            until: pausedUntil,
            now: now
        )

        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        guard let request = requests.first(where: { $0.identifier == notification.identifier }) else {
            return
        }
        center.removePendingNotificationRequests(withIdentifiers: [notification.identifier])
        let pausedRequest = UNNotificationRequest(
            identifier: notification.identifier,
            content: request.content,
            trigger: createNotificationTrigger(at: pausedUntil)
        )
        try? await center.add(pausedRequest)
    }

    static func effectiveScheduledDate(
        sourceIdentifier: String,
        originalScheduledAt: Date,
        now: Date,
        overrideStore: NotificationSchedulingOverrideStore = .shared
    ) async -> Date? {
        guard
            let schedulingOverride = await overrideStore.schedulingOverride(
                sourceIdentifier: sourceIdentifier,
                originalScheduledAt: originalScheduledAt,
                now: now
            )
        else {
            return originalScheduledAt
        }
        switch schedulingOverride {
        case .skip:
            return nil
        case let .pause(until: pausedUntil):
            return pausedUntil > now ? pausedUntil : nil
        }
    }

    static func createNotificationTrigger(at date: Date) -> UNCalendarNotificationTrigger {
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        return UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
    }

    private static func addSchedulingMetadata(
        to content: UNMutableNotificationContent,
        payload: NotificationPayload,
        sourceTitle: String,
        originalScheduledAt: Date?
    ) {
        var userInfo = content.userInfo
        userInfo[NotificationRequestMetadata.sourceIdentifierKey] = payload.identifier
        userInfo[NotificationRequestMetadata.sourceKindKey] = payload.kind.rawValue
        userInfo[NotificationRequestMetadata.sourceTitleKey] = sourceTitle
        if let originalScheduledAt {
            userInfo[NotificationRequestMetadata.originalScheduledAtKey] =
                NotificationSchedulingOverrideStore.normalizedOccurrenceDate(originalScheduledAt).timeIntervalSince1970
        }
        content.userInfo = userInfo
    }

    static func advancedNotificationOccurrenceDates(
        for task: RoutineTask,
        dueDate: Date?,
        referenceDate: Date,
        calendar: Calendar
    ) -> [Date] {
        guard task.recurrenceRule.advanced != nil else { return [] }
        var dates: [Date] = []
        if let dueDate, dueDate != .distantFuture, dueDate > referenceDate {
            dates.append(dueDate)
        }
        var occurrenceThreshold: Date? = referenceDate
        for _ in 0..<advancedOccurrenceNotificationLimit {
            guard
                let date = RoutineDateMath.nextAdvancedEffectiveOccurrence(
                    for: task,
                    after: occurrenceThreshold,
                    calendar: calendar
                )
            else {
                break
            }
            if !dates.contains(date) {
                dates.append(date)
                if dates.count == advancedOccurrenceNotificationLimit { break }
            }
            occurrenceThreshold = date
        }
        return dates.sorted()
    }

    static func notificationOccurrenceDate(from userInfo: [AnyHashable: Any]) -> Date? {
        let value = userInfo[NotificationRequestMetadata.originalScheduledAtKey]
        if let number = value as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }
        if let interval = value as? Double {
            return Date(timeIntervalSince1970: interval)
        }
        return nil
    }

    private static func advancedOccurrenceIdentifier(base: String, index: Int) -> String {
        "\(base)\(advancedOccurrenceIdentifierMarker)\(index)"
    }

    static func notificationIdentifiers(for base: String) -> [String] {
        [base]
            + (0..<advancedOccurrenceNotificationLimit).map {
                advancedOccurrenceIdentifier(base: base, index: $0)
            }
    }

    private static func taskID(fromNotificationIdentifier identifier: String) -> UUID? {
        let base =
            identifier.components(separatedBy: advancedOccurrenceIdentifierMarker).first
            ?? identifier
        return UUID(uuidString: base)
    }

    private static func taskDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineTask> {
        FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
    }
}

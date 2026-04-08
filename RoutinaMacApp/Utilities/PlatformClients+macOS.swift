import Foundation
import UserNotifications

extension RoutinaAppBootstrap.PlatformClients {
    static let macOSLive = RoutinaAppBootstrap.PlatformClients(
        notificationClient: .live,
        appIconClient: .live,
        locationClient: .live
    )
}

extension AppIconClient {
    static let live = AppIconClient(
        requestChange: { option in
            await PlatformSupport.requestAppIconChange(to: option)
        }
    )
}

extension LocationClient {
    static let live = LocationClient(
        snapshot: { requestAuthorizationIfNeeded in
            await OneShotLocationProvider().fetchSnapshot(
                requestAuthorizationIfNeeded: requestAuthorizationIfNeeded
            )
        }
    )
}

extension NotificationClient {
    static let live = NotificationClient(
        schedule: { payload in
            guard NotificationPreferences.notificationsEnabled else { return }
            guard !payload.isPaused else {
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: [payload.identifier])
                center.removeDeliveredNotifications(withIdentifiers: [payload.identifier])
                return
            }

            let request = UNNotificationRequest(
                identifier: payload.identifier,
                content: createNotificationContent(for: payload),
                trigger: createNotificationTrigger(for: payload)
            )
            try? await UNUserNotificationCenter.current().add(request)
        },
        cancel: { identifier in
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.removeDeliveredNotifications(withIdentifiers: [identifier])
        },
        cancelAll: {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
        },
        requestAuthorizationIfNeeded: {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                return true
            case .denied:
                return false
            case .notDetermined:
                return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            @unknown default:
                return false
            }
        }
    )

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
        content.categoryIdentifier = NotificationCoordinator.categoryIdentifier
        return content
    }
}

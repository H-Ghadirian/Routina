import Foundation
import UserNotifications

struct NotificationPayload: Sendable {
    let identifier: String
    let name: String?
    let interval: Int
    let lastDone: Date?
}

struct NotificationClient: Sendable {
    var schedule: @Sendable (_ payload: NotificationPayload) async -> Void
    var cancel: @Sendable (_ identifier: String) async -> Void
}

extension NotificationClient {
    static let live = NotificationClient(
        schedule: { payload in
            let request = UNNotificationRequest(
                identifier: payload.identifier,
                content: createNotificationContent(for: payload.name),
                trigger: createCalendarNotificationTriggerFor(
                    interval: payload.interval,
                    lastDone: payload.lastDone ?? Date()
                )
            )
            try? await UNUserNotificationCenter.current().add(request)
        },
        cancel: { identifier in
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.removeDeliveredNotifications(withIdentifiers: [identifier])
        }
    )

    private static func createCalendarNotificationTriggerFor(
        interval: Int,
        lastDone: Date
    ) -> UNCalendarNotificationTrigger {
        let dueDate = Calendar.current.date(byAdding: .day, value: interval, to: lastDone) ?? Date()
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        return UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
    }

    private static func createNotificationContent(for name: String?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Time to complete \(name ?? "your routine")!"
        content.body = "Your routine is due today."
        content.sound = .default
        return content
    }
}

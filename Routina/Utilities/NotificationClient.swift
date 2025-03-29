import Foundation
import UserNotifications

struct NotificationClient {
    var schedule: (_ task: RoutineTask) async -> Void
}
#if os(iOS)
extension NotificationClient {
    static let live = NotificationClient(
        schedule: { task in
            let request = UNNotificationRequest(
                identifier: task.objectID.uriRepresentation().absoluteString,
                content: createNotificationContent(for: task.name),
                trigger: createCalendarNotificationTriggerFor(
                    interval: Int(task.interval),
                    lastDone: task.lastDone ?? Date()
                )
            )
            try? await UNUserNotificationCenter.current().add(request)
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
#endif

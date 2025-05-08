import Foundation
import UserNotifications

struct NotificationPayload: Sendable {
    let identifier: String
    let name: String?
    let emoji: String?
    let interval: Int
    let lastDone: Date?
    let triggerDate: Date?
    let isPaused: Bool
    let isChecklistDriven: Bool
    let isChecklistCompletionRoutine: Bool
    let nextDueChecklistItemTitle: String?
}

struct NotificationClient: Sendable {
    var schedule: @Sendable (_ payload: NotificationPayload) async -> Void
    var cancel: @Sendable (_ identifier: String) async -> Void
    var cancelAll: @Sendable () async -> Void
    var requestAuthorizationIfNeeded: @Sendable () async -> Bool
}

extension NotificationClient {
    static let noop = NotificationClient(
        schedule: { _ in },
        cancel: { _ in },
        cancelAll: { },
        requestAuthorizationIfNeeded: { false }
    )
}

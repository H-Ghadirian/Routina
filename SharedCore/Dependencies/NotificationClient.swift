import Foundation
import UserNotifications

enum NotificationPayloadKind: Equatable, Sendable {
    case task
    case event
}

struct NotificationPayload: Sendable {
    let identifier: String
    let kind: NotificationPayloadKind
    let name: String?
    let emoji: String?
    let interval: Int
    let lastDone: Date?
    let dueDate: Date?
    let triggerDate: Date?
    let isOneOffTask: Bool
    let isCustomReminder: Bool
    let isArchived: Bool
    let usesExactTime: Bool
    let isChecklistDriven: Bool
    let isChecklistCompletionRoutine: Bool
    let nextDueChecklistItemTitle: String?
    let deepLink: RoutinaDeepLink?
    let isAllDayEvent: Bool
    let recurrenceOccurrenceDates: [Date]

    init(
        identifier: String,
        kind: NotificationPayloadKind = .task,
        name: String?,
        emoji: String?,
        interval: Int,
        lastDone: Date?,
        dueDate: Date?,
        triggerDate: Date?,
        isOneOffTask: Bool,
        isCustomReminder: Bool,
        isArchived: Bool,
        usesExactTime: Bool,
        isChecklistDriven: Bool,
        isChecklistCompletionRoutine: Bool,
        nextDueChecklistItemTitle: String?,
        deepLink: RoutinaDeepLink? = nil,
        isAllDayEvent: Bool = false,
        recurrenceOccurrenceDates: [Date] = []
    ) {
        self.identifier = identifier
        self.kind = kind
        self.name = name
        self.emoji = emoji
        self.interval = interval
        self.lastDone = lastDone
        self.dueDate = dueDate
        self.triggerDate = triggerDate
        self.isOneOffTask = isOneOffTask
        self.isCustomReminder = isCustomReminder
        self.isArchived = isArchived
        self.usesExactTime = usesExactTime
        self.isChecklistDriven = isChecklistDriven
        self.isChecklistCompletionRoutine = isChecklistCompletionRoutine
        self.nextDueChecklistItemTitle = nextDueChecklistItemTitle
        self.deepLink = deepLink
        self.isAllDayEvent = isAllDayEvent
        self.recurrenceOccurrenceDates = recurrenceOccurrenceDates
    }

    func forRecurrenceOccurrence(_ occurrence: Date) -> NotificationPayload {
        NotificationPayload(
            identifier: identifier,
            kind: kind,
            name: name,
            emoji: emoji,
            interval: interval,
            lastDone: lastDone,
            dueDate: occurrence,
            triggerDate: occurrence,
            isOneOffTask: isOneOffTask,
            isCustomReminder: isCustomReminder,
            isArchived: isArchived,
            usesExactTime: true,
            isChecklistDriven: isChecklistDriven,
            isChecklistCompletionRoutine: isChecklistCompletionRoutine,
            nextDueChecklistItemTitle: nextDueChecklistItemTitle,
            deepLink: deepLink,
            isAllDayEvent: isAllDayEvent
        )
    }
}

struct NotificationClient: Sendable {
    var schedule: @Sendable (_ payload: NotificationPayload) async -> Void
    var cancel: @Sendable (_ identifier: String) async -> Void
    var cancelAll: @Sendable () async -> Void
    var requestAuthorizationIfNeeded: @Sendable () async -> Bool
    var systemNotificationsAuthorized: @Sendable () async -> Bool
}

extension NotificationClient {
    static let noop = NotificationClient(
        schedule: { _ in },
        cancel: { _ in },
        cancelAll: { },
        requestAuthorizationIfNeeded: { false },
        systemNotificationsAuthorized: { false }
    )
}

import Foundation
import UserNotifications

enum NotificationPayloadKind: String, Equatable, Sendable {
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

enum ScheduledNotificationSourceKind: String, Equatable, Sendable {
    case task
    case event
    case unknown
}

enum NotificationRequestMetadata {
    static let sourceIdentifierKey = "routina.notification.sourceIdentifier"
    static let sourceKindKey = "routina.notification.sourceKind"
    static let sourceTitleKey = "routina.notification.sourceTitle"
    static let originalScheduledAtKey = "routina.notification.originalScheduledAt"
    static let advancedOccurrenceIdentifierMarker = ".occurrence."

    static func baseIdentifier(from requestIdentifier: String) -> String {
        requestIdentifier.components(separatedBy: advancedOccurrenceIdentifierMarker).first
            ?? requestIdentifier
    }
}

struct ScheduledNotificationSummary: Equatable, Identifiable, Sendable {
    let identifier: String
    let sourceIdentifier: String
    let sourceKind: ScheduledNotificationSourceKind
    let sourceTitle: String
    let title: String
    let subtitle: String
    let body: String
    let scheduledAt: Date?
    let originalScheduledAt: Date?

    init(
        identifier: String,
        sourceIdentifier: String? = nil,
        sourceKind: ScheduledNotificationSourceKind = .unknown,
        sourceTitle: String? = nil,
        title: String,
        subtitle: String,
        body: String,
        scheduledAt: Date?,
        originalScheduledAt: Date? = nil
    ) {
        self.identifier = identifier
        self.sourceIdentifier = sourceIdentifier
            ?? NotificationRequestMetadata.baseIdentifier(from: identifier)
        self.sourceKind = sourceKind
        self.sourceTitle = sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.scheduledAt = scheduledAt
        self.originalScheduledAt = originalScheduledAt ?? scheduledAt
    }

    var id: String { identifier }

    var detailText: String {
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSubtitle.isEmpty {
            return trimmedSubtitle
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isPaused: Bool {
        guard let scheduledAt, let originalScheduledAt else { return false }
        return abs(scheduledAt.timeIntervalSince(originalScheduledAt)) >= 60
    }
}

struct ScheduledNotificationGroup: Equatable, Identifiable, Sendable {
    let sourceIdentifier: String
    let sourceKind: ScheduledNotificationSourceKind
    let title: String
    let notifications: [ScheduledNotificationSummary]

    var queueSummary: String {
        guard let nextDate = notifications.compactMap(\.scheduledAt).min() else {
            let count = notifications.count
            return count == 1 ? "1 queued alert" : "\(count) queued alerts"
        }
        let laterCount = max(notifications.count - 1, 0)
        let nextText = nextDate.formatted(date: .abbreviated, time: .shortened)
        return laterCount == 0
            ? "Next alert \(nextText)"
            : "Next alert \(nextText) · \(laterCount) later"
    }

    var id: String { sourceIdentifier }

    static func groups(
        from notifications: [ScheduledNotificationSummary]
    ) -> [ScheduledNotificationGroup] {
        Dictionary(grouping: notifications, by: \ScheduledNotificationSummary.sourceIdentifier)
            .map { sourceIdentifier, groupedNotifications in
                let sortedNotifications = groupedNotifications.sorted(by: NotificationClient.scheduledNotificationSort)
                let first = sortedNotifications[0]
                return ScheduledNotificationGroup(
                    sourceIdentifier: sourceIdentifier,
                    sourceKind: first.sourceKind,
                    title: resolvedTitle(for: first),
                    notifications: sortedNotifications
                )
            }
            .sorted { lhs, rhs in
                let lhsNotification = lhs.notifications[0]
                let rhsNotification = rhs.notifications[0]
                return NotificationClient.scheduledNotificationSort(lhsNotification, rhsNotification)
            }
    }

    private static func resolvedTitle(for notification: ScheduledNotificationSummary) -> String {
        let sourceTitle = notification.sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sourceTitle.isEmpty {
            return sourceTitle
        }

        let notificationTitle = notification.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let knownSuffixes = [" reminder", " deadline", " is due"]
        for suffix in knownSuffixes where notificationTitle.hasSuffix(suffix) {
            return String(notificationTitle.dropLast(suffix.count))
        }
        if !notificationTitle.isEmpty {
            return notificationTitle
        }

        switch notification.sourceKind {
        case .task:
            return "Task"
        case .event:
            return "Event"
        case .unknown:
            return "Routina notification"
        }
    }
}

enum NotificationSchedulingOverride: Equatable, Sendable {
    case skip
    case pause(until: Date)
}

private struct NotificationSchedulingOverrideRecord: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case skip
        case pause
    }

    let sourceIdentifier: String
    let originalScheduledAt: Date
    let kind: Kind
    let pausedUntil: Date?
}

actor NotificationSchedulingOverrideStore {
    static let shared = NotificationSchedulingOverrideStore()

    private static let defaultStorageKey = "notificationSchedulingOverrides.v1"
    private static let retentionAfterEffectiveDate: TimeInterval = 7 * 24 * 60 * 60

    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = SharedDefaults.app,
        storageKey: String = NotificationSchedulingOverrideStore.defaultStorageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func schedulingOverride(
        sourceIdentifier: String,
        originalScheduledAt: Date,
        now: Date = Date()
    ) -> NotificationSchedulingOverride? {
        let records = loadPrunedRecords(now: now)
        let normalizedDate = Self.normalizedOccurrenceDate(originalScheduledAt)
        guard let record = records.first(where: {
            $0.sourceIdentifier == sourceIdentifier
                && $0.originalScheduledAt == normalizedDate
        }) else {
            return nil
        }

        switch record.kind {
        case .skip:
            return .skip
        case .pause:
            guard let pausedUntil = record.pausedUntil else { return .skip }
            return .pause(until: pausedUntil)
        }
    }

    func skip(
        sourceIdentifier: String,
        originalScheduledAt: Date,
        now: Date = Date()
    ) {
        save(
            kind: .skip,
            pausedUntil: nil,
            sourceIdentifier: sourceIdentifier,
            originalScheduledAt: originalScheduledAt,
            now: now
        )
    }

    func pause(
        sourceIdentifier: String,
        originalScheduledAt: Date,
        until pausedUntil: Date,
        now: Date = Date()
    ) {
        save(
            kind: .pause,
            pausedUntil: Self.normalizedOccurrenceDate(pausedUntil),
            sourceIdentifier: sourceIdentifier,
            originalScheduledAt: originalScheduledAt,
            now: now
        )
    }

    static func normalizedOccurrenceDate(_ date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / 60) * 60)
    }

    private func save(
        kind: NotificationSchedulingOverrideRecord.Kind,
        pausedUntil: Date?,
        sourceIdentifier: String,
        originalScheduledAt: Date,
        now: Date
    ) {
        let normalizedDate = Self.normalizedOccurrenceDate(originalScheduledAt)
        var records = loadPrunedRecords(now: now).filter {
            !($0.sourceIdentifier == sourceIdentifier && $0.originalScheduledAt == normalizedDate)
        }
        records.append(
            NotificationSchedulingOverrideRecord(
                sourceIdentifier: sourceIdentifier,
                originalScheduledAt: normalizedDate,
                kind: kind,
                pausedUntil: pausedUntil
            )
        )
        persist(records)
    }

    private func loadPrunedRecords(now: Date) -> [NotificationSchedulingOverrideRecord] {
        let records = loadRecords()
        let pruned = records.filter { record in
            let effectiveDate = max(record.originalScheduledAt, record.pausedUntil ?? record.originalScheduledAt)
            return now.timeIntervalSince(effectiveDate) <= Self.retentionAfterEffectiveDate
        }
        if pruned != records {
            persist(pruned)
        }
        return pruned
    }

    private func loadRecords() -> [NotificationSchedulingOverrideRecord] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([NotificationSchedulingOverrideRecord].self, from: data)) ?? []
    }

    private func persist(_ records: [NotificationSchedulingOverrideRecord]) {
        guard !records.isEmpty else {
            defaults.removeObject(forKey: storageKey)
            return
        }
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

struct NotificationClient: Sendable {
    var schedule: @Sendable (_ payload: NotificationPayload) async -> Void
    var cancel: @Sendable (_ identifier: String) async -> Void
    var cancelAll: @Sendable () async -> Void
    var requestAuthorizationIfNeeded: @Sendable () async -> Bool
    var systemNotificationsAuthorized: @Sendable () async -> Bool
    var pendingScheduledNotifications: @Sendable () async -> [ScheduledNotificationSummary]
    var removeScheduledNotification: @Sendable (_ notification: ScheduledNotificationSummary) async -> Void
    var pauseScheduledNotification: @Sendable (_ notification: ScheduledNotificationSummary, _ until: Date) async -> Void
}

extension NotificationClient {
    static let noop = NotificationClient(
        schedule: { _ in },
        cancel: { _ in },
        cancelAll: { },
        requestAuthorizationIfNeeded: { false },
        systemNotificationsAuthorized: { false },
        pendingScheduledNotifications: { [] },
        removeScheduledNotification: { _ in },
        pauseScheduledNotification: { _, _ in }
    )

    static func scheduledNotificationSummaries(
        from requests: [UNNotificationRequest]
    ) -> [ScheduledNotificationSummary] {
        requests
            .map { request in
                let scheduledAt = scheduledDate(for: request.trigger)
                let userInfo = request.content.userInfo
                let sourceIdentifier = userInfo[NotificationRequestMetadata.sourceIdentifierKey] as? String
                    ?? NotificationRequestMetadata.baseIdentifier(from: request.identifier)
                let sourceKind = resolvedSourceKind(
                    rawValue: userInfo[NotificationRequestMetadata.sourceKindKey] as? String,
                    sourceIdentifier: sourceIdentifier
                )
                return ScheduledNotificationSummary(
                    identifier: request.identifier,
                    sourceIdentifier: sourceIdentifier,
                    sourceKind: sourceKind,
                    sourceTitle: userInfo[NotificationRequestMetadata.sourceTitleKey] as? String,
                    title: request.content.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    subtitle: request.content.subtitle,
                    body: request.content.body,
                    scheduledAt: scheduledAt,
                    originalScheduledAt: metadataDate(
                        from: userInfo[NotificationRequestMetadata.originalScheduledAtKey]
                    ) ?? scheduledAt
                )
            }
            .sorted(by: scheduledNotificationSort)
    }

    private static func scheduledDate(for trigger: UNNotificationTrigger?) -> Date? {
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            return calendarTrigger.nextTriggerDate()
        }
        if let intervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            return intervalTrigger.nextTriggerDate()
        }
        return nil
    }

    static func scheduledNotificationSort(
        _ lhs: ScheduledNotificationSummary,
        _ rhs: ScheduledNotificationSummary
    ) -> Bool {
        switch (lhs.scheduledAt, rhs.scheduledAt) {
        case let (.some(lhsDate), .some(rhsDate)) where lhsDate != rhsDate:
            return lhsDate < rhsDate
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            let titleOrder = lhs.title.localizedStandardCompare(rhs.title)
            if titleOrder != .orderedSame {
                return titleOrder == .orderedAscending
            }
            return lhs.identifier < rhs.identifier
        }
    }

    private static func resolvedSourceKind(
        rawValue: String?,
        sourceIdentifier: String
    ) -> ScheduledNotificationSourceKind {
        if let rawValue, let kind = ScheduledNotificationSourceKind(rawValue: rawValue) {
            return kind
        }
        if sourceIdentifier.hasPrefix(NotificationCoordinator.eventNotificationIdentifierPrefix) {
            return .event
        }
        if UUID(uuidString: sourceIdentifier) != nil {
            return .task
        }
        return .unknown
    }

    private static func metadataDate(from value: Any?) -> Date? {
        if let number = value as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }
        if let value = value as? Double {
            return Date(timeIntervalSince1970: value)
        }
        return nil
    }
}

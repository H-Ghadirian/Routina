import CloudKit
import CoreData
import CryptoKit
import Foundation

enum CloudKitSyncDiagnostics {
    struct Snapshot: Equatable {
        var summary: String
        var timestampText: String
        var pushStatus: String
        var manualRefreshSummary: String
        var manualRefreshTimestampText: String
        var manualRefreshDisplayMessage: String
    }

    static let didUpdateNotification = Notification.Name("cloudKitSyncDiagnosticsDidUpdate")

    private static let summaryKey = "cloudKitSyncDiagnostics.summary"
    private static let timestampKey = "cloudKitSyncDiagnostics.timestamp"
    private static let pushStatusKey = "cloudKitSyncDiagnostics.pushStatus"
    private static let manualRefreshSummaryKey = "cloudKitSyncDiagnostics.manualRefreshSummary"
    private static let manualRefreshTimestampKey = "cloudKitSyncDiagnostics.manualRefreshTimestamp"
    private static let manualRefreshDisplayMessageKey = "cloudKitSyncDiagnostics.manualRefreshDisplayMessage"
    private static let defaults = UserDefaults.standard
    private static let observerBox = ObserverBox()
    private static let manualRefreshLock = NSLock()

    static func startIfNeeded() {
        guard observerBox.observer == nil else { return }

        let observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            record(notification)
        }
        observerBox.observer = observer
    }

    static func snapshot() -> Snapshot {
        Snapshot(
            summary: defaults.string(forKey: summaryKey) ?? "No CloudKit event yet",
            timestampText: timestampString(from: defaults.object(forKey: timestampKey) as? Date),
            pushStatus: defaults.string(forKey: pushStatusKey) ?? "Push not registered yet",
            manualRefreshSummary: defaults.string(forKey: manualRefreshSummaryKey) ?? "No manual refresh yet",
            manualRefreshTimestampText: timestampString(
                from: defaults.object(forKey: manualRefreshTimestampKey) as? Date
            ),
            manualRefreshDisplayMessage: defaults.string(
                forKey: manualRefreshDisplayMessageKey
            ) ?? ""
        )
    }

    static func recordManualRefreshStarted(mode: CloudSyncManualRefreshProgress.Mode) {
        let modeDescription = mode == .full ? "all iCloud data" : "recent iCloud changes"
        recordManualRefresh(
            summary: "status=started mode=\(mode.rawValue) received=0 changed=0 deleted=0",
            displayMessage: "Checking \(modeDescription)…"
        )
    }

    static func recordManualRefreshProgress(_ progress: CloudSyncManualRefreshProgress) {
        recordManualRefresh(
            summary: manualRefreshSummary(status: "receiving", progress: progress),
            displayMessage: progress.displayMessage
        )
    }

    static func recordManualRefreshDownloadFinished(
        _ progress: CloudSyncManualRefreshProgress
    ) {
        let noun = progress.receivedRecordCount == 1 ? "item" : "items"
        recordManualRefresh(
            summary: manualRefreshSummary(status: "applying", progress: progress),
            displayMessage: "Applying \(progress.receivedRecordCount) iCloud \(noun)…"
        )
    }

    static func recordManualRefreshSucceeded(
        _ progress: CloudSyncManualRefreshProgress,
        savedChangeToken: Bool
    ) {
        recordManualRefresh(
            summary: "\(manualRefreshSummary(status: "succeeded", progress: progress)) tokenSaved=\(savedChangeToken)",
            displayMessage: "Latest iCloud data received."
        )
    }

    static func recordManualRefreshFailure(
        _ error: Error,
        progress: CloudSyncManualRefreshProgress?
    ) {
        let progressSummary = progress.map {
            manualRefreshSummary(status: "failed", progress: $0)
        } ?? "status=failed mode=unknown"
        recordManualRefresh(
            summary: "\(progressSummary) error=\(describe(error))",
            displayMessage: CloudSyncFeedbackSupport.manualRefreshErrorMessage(for: error)
        )
    }

    static func recordPushRegistrationSuccess(tokenByteCount: Int) {
        defaults.set("Push registered (token bytes: \(tokenByteCount))", forKey: pushStatusKey)
        NotificationCenter.default.post(name: didUpdateNotification, object: nil)
    }

    static func recordPushRegistrationFailure(_ error: Error) {
        defaults.set("Push registration failed: \(error.localizedDescription)", forKey: pushStatusKey)
        NotificationCenter.default.post(name: didUpdateNotification, object: nil)
    }

    static func recordRemoteNotificationReceived() {
        defaults.set("Push registered, remote notification received", forKey: pushStatusKey)
        NotificationCenter.default.post(name: didUpdateNotification, object: nil)
    }

    static func recordSubscriptionStatus(_ status: String) {
        defaults.set("\(defaults.string(forKey: pushStatusKey) ?? "Push state unknown") | \(status)", forKey: pushStatusKey)
        NotificationCenter.default.post(name: didUpdateNotification, object: nil)
    }

    private static func manualRefreshSummary(
        status: String,
        progress: CloudSyncManualRefreshProgress
    ) -> String {
        "status=\(status) mode=\(progress.mode.rawValue) received=\(progress.receivedRecordCount) changed=\(progress.changedRecordCount) deleted=\(progress.deletedRecordCount)"
    }

    private static func recordManualRefresh(
        summary: String,
        displayMessage: String
    ) {
        manualRefreshLock.lock()
        defaults.set(summary, forKey: manualRefreshSummaryKey)
        defaults.set(Date(), forKey: manualRefreshTimestampKey)
        defaults.set(displayMessage, forKey: manualRefreshDisplayMessageKey)
        manualRefreshLock.unlock()
        NotificationCenter.default.post(name: didUpdateNotification, object: nil)
    }

    private static func record(_ notification: Notification) {
        let summary = summaryText(from: notification)
        let now = Date()

        defaults.set(summary, forKey: summaryKey)
        defaults.set(now, forKey: timestampKey)

        NotificationCenter.default.post(name: didUpdateNotification, object: nil)
    }

    private static func summaryText(from notification: Notification) -> String {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
            return "CloudKit event notification without payload"
        }

        let typeText: String
        switch event.type {
        case .setup:
            typeText = "setup"
        case .import:
            typeText = "import"
        case .export:
            typeText = "export"
        @unknown default:
            typeText = "unknown"
        }

        let statusText = event.succeeded ? "succeeded" : "failed"
        let errorText = event.error.map { " error=\(describe($0))" } ?? ""

        return "type=\(typeText) status=\(statusText)\(errorText)"
    }

    static func describe(_ error: Error) -> String {
        guard let ckError = error as? CKError else {
            return error.localizedDescription
        }

        var parts: [String] = []
        parts.append("ckCode=\(ckError.code.rawValue)")
        parts.append("ckName=\(ckError.code)")
        parts.append("message=\(ckError.localizedDescription)")

        if ckError.code == .partialFailure {
            let partials = partialErrors(from: ckError)
            if !partials.isEmpty {
                let rootPartials = partials.filter { _, error in
                    (error as? CKError)?.code != .batchRequestFailed
                }
                let relevantPartials = rootPartials.isEmpty ? partials : rootPartials
                let partialSummary = relevantPartials
                    .map { item, error in
                        "\(diagnosticItemLabel(for: item)) \(describePartial(error))"
                    }
                    .sorted()
                    .prefix(3)
                    .joined(separator: ", ")

                parts.append("partialCount=\(partials.count)")
                if relevantPartials.count != partials.count {
                    parts.append("rootPartialCount=\(relevantPartials.count)")
                }
                parts.append("partials=\(partialSummary)")
            } else {
                parts.append("partials=unavailable")
            }
        }

        return parts.joined(separator: " ")
    }

    private static func partialErrors(from ckError: CKError) -> [AnyHashable: Error] {
        if let partials = ckError.partialErrorsByItemID, !partials.isEmpty {
            return partials
        }

        guard let rawPartials = ckError.userInfo[CKPartialErrorsByItemIDKey] as? NSDictionary else {
            return [:]
        }

        return rawPartials.reduce(into: [:]) { result, entry in
            guard let item = entry.key as? AnyHashable,
                  let error = entry.value as? Error else {
                return
            }
            result[item] = error
        }
    }

    private static func diagnosticItemLabel(for item: AnyHashable) -> String {
        let itemKind: String
        switch item.base {
        case is CKRecord.ID:
            itemKind = "record"
        case is CKRecordZone.ID:
            itemKind = "zone"
        default:
            itemKind = "item"
        }

        let digest = SHA256.hash(data: Data(String(reflecting: item).utf8))
            .prefix(6)
            .map { String(format: "%02x", $0) }
            .joined()
        return "\(itemKind)#\(digest)"
    }

    private static func describePartial(_ error: Error) -> String {
        if let ckError = error as? CKError {
            var parts = [
                "ckCode=\(ckError.code.rawValue)",
                "ckName=\(ckError.code)",
            ]
            if let retryAfter = ckError.retryAfterSeconds {
                parts.append("retryAfter=\(retryAfter)")
            }
            return parts.joined(separator: " ")
        }

        let nsError = error as NSError
        return "domain=\(nsError.domain) code=\(nsError.code)"
    }

    private static func timestampString(from date: Date?) -> String {
        guard let date else { return "Never" }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

private final class ObserverBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: NSObjectProtocol?

    var observer: NSObjectProtocol? {
        get {
            lock.withLock { value }
        }
        set {
            lock.withLock {
                value = newValue
            }
        }
    }
}

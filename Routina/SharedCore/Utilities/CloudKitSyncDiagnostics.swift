import CloudKit
import CoreData
import Foundation

enum CloudKitSyncDiagnostics {
    struct Snapshot: Equatable {
        var summary: String
        var timestampText: String
        var pushStatus: String
    }

    static let didUpdateNotification = Notification.Name("cloudKitSyncDiagnosticsDidUpdate")

    private static let summaryKey = "cloudKitSyncDiagnostics.summary"
    private static let timestampKey = "cloudKitSyncDiagnostics.timestamp"
    private static let pushStatusKey = "cloudKitSyncDiagnostics.pushStatus"
    private static let defaults = UserDefaults.standard

    static func startIfNeeded() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            record(notification)
        }
    }

    static func snapshot() -> Snapshot {
        Snapshot(
            summary: defaults.string(forKey: summaryKey) ?? "No CloudKit event yet",
            timestampText: timestampString(from: defaults.object(forKey: timestampKey) as? Date),
            pushStatus: defaults.string(forKey: pushStatusKey) ?? "Push not registered yet"
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

    private static func record(_ notification: Notification) {
        let summary = summaryText(from: notification)
        let now = Date()

        defaults.set(summary, forKey: summaryKey)
        defaults.set(now, forKey: timestampKey)

        NSLog("CloudKit event: \(summary)")
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

    private static func describe(_ error: Error) -> String {
        guard let ckError = error as? CKError else {
            return error.localizedDescription
        }

        var parts: [String] = []
        parts.append("ckCode=\(ckError.code.rawValue)")
        parts.append("ckName=\(ckError.code)")
        parts.append("message=\(ckError.localizedDescription)")

        if ckError.code == .partialFailure,
           let partials = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
           !partials.isEmpty {
            let partialSummary = partials.prefix(3).map { key, value in
                if let nested = value as? CKError {
                    return "\(key):\(nested.code.rawValue)"
                }
                return "\(key):\(value.localizedDescription)"
            }.joined(separator: ",")
            parts.append("partials=\(partialSummary)")
        }

        return parts.joined(separator: " ")
    }

    private static func timestampString(from date: Date?) -> String {
        guard let date else { return "Never" }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

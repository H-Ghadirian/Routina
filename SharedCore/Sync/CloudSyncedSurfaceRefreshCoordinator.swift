import CoreData
import Foundation

@MainActor
enum CloudSyncedSurfaceRefreshCoordinator {
    private static var observers: [NSObjectProtocol] = []
    private static var pendingRefreshTask: Task<Void, Never>?
    private static var firstPendingSurfaceRefreshAt: Date?
    private static var lastSurfaceRefreshAt: Date?

    private static let surfaceRefreshQuietWindowMilliseconds: Int64 = 1_500
    private static let widgetRefreshQuietWindowMilliseconds: Int64 = 30_000
    private static let minimumSurfaceRefreshSpacing: TimeInterval = 2.0
    private static let maximumSurfaceRefreshDeferral: TimeInterval = 5.0

    static func startIfNeeded() {
        guard observers.isEmpty else { return }

        let center = NotificationCenter.default

        observers.append(
            center.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification,
                object: nil,
                queue: .main
            ) { notification in
                guard Self.shouldRefreshSurfaces(for: notification) else { return }
                Task { @MainActor in
                    scheduleSurfaceRefresh()
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: .NSPersistentStoreRemoteChange,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    scheduleSurfaceRefresh()
                }
            }
        )
    }

    nonisolated private static func shouldRefreshSurfaces(for notification: Notification) -> Bool {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
            return true
        }

        guard event.type == .import else { return false }
        return event.succeeded
    }

    private static func scheduleSurfaceRefresh() {
        let now = Date()
        if firstPendingSurfaceRefreshAt == nil {
            firstPendingSurfaceRefreshAt = now
        }
        let delayMilliseconds = surfaceRefreshDelayMilliseconds(at: now)

        pendingRefreshTask?.cancel()
        pendingRefreshTask = Task { @MainActor in
            if delayMilliseconds > 0 {
                try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            }
            guard !Task.isCancelled else { return }
            performSurfaceRefresh()
        }
    }

    private static func surfaceRefreshDelayMilliseconds(at now: Date) -> Int64 {
        let coalescingDelay = coalescingDelaySeconds(at: now)
        let spacingDelay = spacingDelaySeconds(at: now)
        let delaySeconds = max(coalescingDelay, spacingDelay)
        return Int64((delaySeconds * 1_000).rounded(.up))
    }

    private static func coalescingDelaySeconds(at now: Date) -> TimeInterval {
        guard let firstPendingSurfaceRefreshAt else {
            return TimeInterval(surfaceRefreshQuietWindowMilliseconds) / 1_000
        }

        let deferredSeconds = now.timeIntervalSince(firstPendingSurfaceRefreshAt)
        let remainingDeferral = max(0, maximumSurfaceRefreshDeferral - deferredSeconds)
        let quietWindowSeconds = TimeInterval(surfaceRefreshQuietWindowMilliseconds) / 1_000
        return min(quietWindowSeconds, remainingDeferral)
    }

    private static func spacingDelaySeconds(at now: Date) -> TimeInterval {
        guard let lastSurfaceRefreshAt else { return 0 }
        return max(0, minimumSurfaceRefreshSpacing - now.timeIntervalSince(lastSurfaceRefreshAt))
    }

    private static func performSurfaceRefresh() {
        firstPendingSurfaceRefreshAt = nil
        lastSurfaceRefreshAt = Date()
        RoutinaUserPreferencesStore.applyToDefaults(from: PersistenceController.shared.container.mainContext)
        NotificationCenter.default.postRoutineDidUpdate(
            widgetRefreshDelayMilliseconds: widgetRefreshQuietWindowMilliseconds
        )
    }
}

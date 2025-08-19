import CoreData
import Foundation

@MainActor
enum CloudSyncedSurfaceRefreshCoordinator {
    private static var observers: [NSObjectProtocol] = []
    private static var pendingRefreshTask: Task<Void, Never>?

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
        pendingRefreshTask?.cancel()
        pendingRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            NotificationCenter.default.postRoutineDidUpdate()
        }
    }
}

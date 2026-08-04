import Foundation

@MainActor
final class RoutinaMacAIReadOnlySnapshotScheduler {
    private let persistence: PersistenceController
    private var refreshTask: Task<Void, Never>?

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func scheduleLaunchRefresh() {
        scheduleRefresh(delayNanoseconds: 400_000_000)
    }

    func scheduleRefresh(delayNanoseconds: UInt64 = 500_000_000) {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            self?.refreshNow()
        }
    }

    func refreshNow() {
        guard !AppEnvironment.isAutomatedTestMode else { return }

        do {
            if SharedDefaults.app[.appSettingMacLocalAIAccessEnabled] {
                _ = try RoutinaAIReadOnlySnapshotStore.refresh(
                    using: persistence.container.mainContext
                )
            } else {
                try RoutinaAIReadOnlySnapshotStore.remove()
            }
        } catch {
            NSLog("Failed to refresh Routina's read-only AI snapshot: %@", error.localizedDescription)
        }
    }
}

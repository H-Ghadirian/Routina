import SwiftData

enum RoutinaAppSceneBootstrap {
    @MainActor
    static func preparePersistence() -> PersistenceController {
        RoutinaAppBootstrap.configure()
        let persistence = PersistenceController.shared
        RoutinaUserPreferencesStore.migrateDefaultsIfNeeded(in: persistence.container.mainContext)
        RoutinaUserPreferencesStore.startDefaultsMirror()
        RoutinaUITestSeeder.seedIfRequested(in: persistence.container.mainContext)
        RoutinaScreenshotDataSeeder.seedIfRequested(in: persistence.container.mainContext)
        if !AppEnvironment.isAutomatedTestMode {
            PersistenceController.startBackgroundStartupMaintenanceIfNeeded(
                in: persistence.container
            )
        }
        scheduleDuplicateIDCleanup(using: persistence)
        return persistence
    }

    @MainActor
    private static func scheduleDuplicateIDCleanup(using persistence: PersistenceController) {
        guard !AppEnvironment.isAutomatedTestMode else { return }
        let context = persistence.container.mainContext
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            RoutineDuplicateIDCleanup.run(in: context)
        }
    }
}

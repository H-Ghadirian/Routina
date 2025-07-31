import SwiftData

enum RoutinaAppSceneBootstrap {
    @MainActor
    static func preparePersistence() -> PersistenceController {
        RoutinaAppBootstrap.configure()
        let persistence = PersistenceController.shared
        RoutinaUITestSeeder.seedIfRequested(in: persistence.container.mainContext)
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

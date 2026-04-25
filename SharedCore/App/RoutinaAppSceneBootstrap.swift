import SwiftData

enum RoutinaAppSceneBootstrap {
    @MainActor
    static func preparePersistence() -> PersistenceController {
        RoutinaAppBootstrap.configure()
        let persistence = PersistenceController.shared
        RoutinaUITestSeeder.seedIfRequested(in: persistence.container.mainContext)
        return persistence
    }
}

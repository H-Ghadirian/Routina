import SwiftData

enum RoutinaAppSceneBootstrap {
    @MainActor
    static func preparePersistence() -> PersistenceController {
        RoutinaAppBootstrap.configure()
        return PersistenceController.shared
    }
}

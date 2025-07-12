import SwiftData

package enum RoutinaSupportBootstrap {
    @MainActor
    package static func prepare() -> PersistenceController {
        RoutinaAppBootstrap.configure()
        return PersistenceController.shared
    }
}

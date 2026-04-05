import SwiftUI

/// Coordinates scroll-to-section between the sidebar nav and the add/edit form.
@Observable
final class AddEditFormCoordinator {
    var scrollTarget: String?
}

private struct AddEditFormCoordinatorKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = AddEditFormCoordinator()
}

extension EnvironmentValues {
    var addEditFormCoordinator: AddEditFormCoordinator {
        get { self[AddEditFormCoordinatorKey.self] }
        set { self[AddEditFormCoordinatorKey.self] = newValue }
    }
}

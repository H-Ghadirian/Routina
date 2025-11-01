import ComposableArchitecture
import SwiftData

private enum ModelContextProviderKey: DependencyKey {
    static let liveValue: @MainActor @Sendable () -> ModelContext = {
        PersistenceController.shared.container.mainContext
    }
}

private enum NotificationClientKey: DependencyKey {
    static let liveValue = NotificationClient.live
}

extension DependencyValues {
    var modelContext: @MainActor @Sendable () -> ModelContext {
        get { self[ModelContextProviderKey.self] }
        set { self[ModelContextProviderKey.self] = newValue }
    }

    var notificationClient: NotificationClient {
        get { self[NotificationClientKey.self] }
        set { self[NotificationClientKey.self] = newValue }
    }
}

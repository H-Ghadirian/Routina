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

private enum AppIconClientKey: DependencyKey {
    static let liveValue = AppIconClient.live
}

private enum LocationClientKey: DependencyKey {
    static let liveValue = LocationClient.live
}

private enum CloudSyncClientKey: DependencyKey {
    static let liveValue = CloudSyncClient.live
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

    var appIconClient: AppIconClient {
        get { self[AppIconClientKey.self] }
        set { self[AppIconClientKey.self] = newValue }
    }

    var locationClient: LocationClient {
        get { self[LocationClientKey.self] }
        set { self[LocationClientKey.self] = newValue }
    }

    var cloudSyncClient: CloudSyncClient {
        get { self[CloudSyncClientKey.self] }
        set { self[CloudSyncClientKey.self] = newValue }
    }
}

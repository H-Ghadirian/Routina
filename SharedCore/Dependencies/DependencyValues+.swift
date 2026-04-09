import ComposableArchitecture
import SwiftData

private enum ModelContextProviderKey: DependencyKey {
    static let liveValue: @MainActor @Sendable () -> ModelContext = {
        PersistenceController.shared.container.mainContext
    }
}

private enum NotificationClientKey: DependencyKey {
    static let liveValue = NotificationClient.noop
}

private enum AppIconClientKey: DependencyKey {
    static let liveValue = AppIconClient.noop
}

private enum LocationClientKey: DependencyKey {
    static let liveValue = LocationClient.noop
}

private enum CloudSyncClientKey: DependencyKey {
    static let liveValue = CloudSyncClient.live
}

private enum AppSettingsClientKey: DependencyKey {
    static let liveValue = AppSettingsClient.live
    static let testValue = AppSettingsClient.noop
}

private enum AppInfoClientKey: DependencyKey {
    static let liveValue = AppInfoClient.live
    static let testValue = AppInfoClient.noop
}

private enum URLOpenerClientKey: DependencyKey {
    static let liveValue = URLOpenerClient.live
    static let testValue = URLOpenerClient.noop
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

    var appSettingsClient: AppSettingsClient {
        get { self[AppSettingsClientKey.self] }
        set { self[AppSettingsClientKey.self] = newValue }
    }

    var appInfoClient: AppInfoClient {
        get { self[AppInfoClientKey.self] }
        set { self[AppInfoClientKey.self] = newValue }
    }

    var urlOpenerClient: URLOpenerClient {
        get { self[URLOpenerClientKey.self] }
        set { self[URLOpenerClientKey.self] = newValue }
    }
}

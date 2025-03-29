import ComposableArchitecture
import CoreData

private enum ManagedObjectContextKey: DependencyKey {
    static let liveValue: NSManagedObjectContext = {
        fatalError("NSManagedObjectContext has not been set in DependencyValues.")
    }()
}

private enum NotificationClientKey: DependencyKey {
    static let liveValue = NotificationClient.live
}

extension DependencyValues {
    var managedObjectContext: NSManagedObjectContext {
        get { self[ManagedObjectContextKey.self] }
        set { self[ManagedObjectContextKey.self] = newValue }
    }
    var notificationClient: NotificationClient {
        get { self[NotificationClientKey.self] }
        set { self[NotificationClientKey.self] = newValue }
    }
}

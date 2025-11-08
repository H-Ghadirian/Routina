import ComposableArchitecture
import CoreData

private enum ManagedObjectContextKey: DependencyKey {
    static let liveValue: NSManagedObjectContext = {
        PersistenceController.shared.container.viewContext
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

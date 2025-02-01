import ComposableArchitecture
import CoreData

private enum ManagedObjectContextKey: DependencyKey {
    static let liveValue: NSManagedObjectContext = {
        fatalError("NSManagedObjectContext has not been set in DependencyValues.")
    }()
}

extension DependencyValues {
    var managedObjectContext: NSManagedObjectContext {
        get { self[ManagedObjectContextKey.self] }
        set { self[ManagedObjectContextKey.self] = newValue }
    }
}

import CoreData
import Foundation

public struct PersistenceController {
    public static let shared = PersistenceController()

    private static let cloudContainerIdentifier = "iCloud.ir.hamedgh.Routinam"

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        let primaryContainer = NSPersistentCloudKitContainer(name: "RoutinaModel")

        if inMemory {
            primaryContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        Self.configureStoreDescriptions(for: primaryContainer, useCloudKit: !inMemory)

        if let primaryError = Self.loadStores(for: primaryContainer) {
            NSLog("CloudKit store load failed: \(primaryError), \(primaryError.userInfo). Falling back to local store.")

            let fallbackContainer = NSPersistentCloudKitContainer(name: "RoutinaModel")
            if inMemory {
                fallbackContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
            }
            Self.configureStoreDescriptions(for: fallbackContainer, useCloudKit: false)

            if let fallbackError = Self.loadStores(for: fallbackContainer) {
                fatalError("Unresolved error \(fallbackError), \(fallbackError.userInfo)")
            }
            container = fallbackContainer
        } else {
            container = primaryContainer
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    private static func configureStoreDescriptions(
        for container: NSPersistentCloudKitContainer,
        useCloudKit: Bool
    ) {
        container.persistentStoreDescriptions.forEach { description in
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            description.cloudKitContainerOptions = useCloudKit
                ? NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudContainerIdentifier)
                : nil
        }
    }

    private static func loadStores(for container: NSPersistentCloudKitContainer) -> NSError? {
        let semaphore = DispatchSemaphore(value: 0)
        var loadError: NSError?

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                loadError = error
            }
            semaphore.signal()
        }

        semaphore.wait()
        return loadError
    }
}

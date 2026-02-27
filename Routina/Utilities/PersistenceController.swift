import CoreData
import Foundation

public struct PersistenceController {
    public static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        let primaryContainer = NSPersistentCloudKitContainer(name: "RoutinaModel")
        let persistentStoreURL = inMemory ? nil : Self.persistentStoreURL()

        if inMemory {
            primaryContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else if let persistentStoreURL {
            primaryContainer.persistentStoreDescriptions.first?.url = persistentStoreURL
        }

        let useCloudKit = !inMemory && AppEnvironment.cloudKitContainerIdentifier != nil
        Self.configureStoreDescriptions(
            for: primaryContainer,
            useCloudKit: useCloudKit,
            cloudContainerIdentifier: AppEnvironment.cloudKitContainerIdentifier
        )

        if let primaryError = Self.loadStores(for: primaryContainer) {
            NSLog("CloudKit store load failed: \(primaryError), \(primaryError.userInfo). Falling back to local store.")

            let fallbackContainer = NSPersistentCloudKitContainer(name: "RoutinaModel")
            if inMemory {
                fallbackContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
            } else if let persistentStoreURL {
                fallbackContainer.persistentStoreDescriptions.first?.url = persistentStoreURL
            }
            Self.configureStoreDescriptions(
                for: fallbackContainer,
                useCloudKit: false,
                cloudContainerIdentifier: nil
            )

            if let fallbackError = Self.loadStores(for: fallbackContainer) {
                NSLog("Local store load failed: \(fallbackError), \(fallbackError.userInfo). Falling back to in-memory store.")

                let memoryContainer = NSPersistentCloudKitContainer(name: "RoutinaModel")
                memoryContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
                Self.configureStoreDescriptions(
                    for: memoryContainer,
                    useCloudKit: false,
                    cloudContainerIdentifier: nil
                )

                if let memoryError = Self.loadStores(for: memoryContainer) {
                    NSLog("In-memory store load failed: \(memoryError), \(memoryError.userInfo)")
                }
                container = memoryContainer
            } else {
                container = fallbackContainer
            }
        } else {
            container = primaryContainer
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    private static func configureStoreDescriptions(
        for container: NSPersistentCloudKitContainer,
        useCloudKit: Bool,
        cloudContainerIdentifier: String?
    ) {
        container.persistentStoreDescriptions.forEach { description in
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            if useCloudKit, let cloudContainerIdentifier {
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: cloudContainerIdentifier
                )
            } else {
                description.cloudKitContainerOptions = nil
            }
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

    private static func persistentStoreURL() -> URL? {
        do {
            let applicationSupportDirectory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let storesDirectory = applicationSupportDirectory.appendingPathComponent("RoutinaData", isDirectory: true)
            try FileManager.default.createDirectory(at: storesDirectory, withIntermediateDirectories: true)
            return storesDirectory.appendingPathComponent(AppEnvironment.persistentStoreFileName)
        } catch {
            NSLog("Failed to resolve persistent store URL: \(error.localizedDescription)")
            return nil
        }
    }
}

extension PersistenceController: @unchecked Sendable {}

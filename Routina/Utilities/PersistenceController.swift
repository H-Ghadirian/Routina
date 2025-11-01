import Foundation
import SwiftData

public struct PersistenceController {
    public static let shared = PersistenceController()

    let container: ModelContainer

    init(inMemory: Bool = false) {
        let primaryCloudDatabase = Self.cloudKitDatabase(inMemory: inMemory)

        do {
            let primaryConfiguration = Self.makeConfiguration(
                inMemory: inMemory,
                cloudKitDatabase: primaryCloudDatabase
            )
            container = try ModelContainer(
                for: RoutineTask.self,
                RoutineLog.self,
                configurations: primaryConfiguration
            )
        } catch {
            NSLog(
                "Primary ModelContainer init failed: \(error.localizedDescription)."
            )

            if !inMemory {
                Self.removePersistentStoreFiles()

                do {
                    let retriedConfiguration = Self.makeConfiguration(
                        inMemory: inMemory,
                        cloudKitDatabase: primaryCloudDatabase
                    )
                    container = try ModelContainer(
                        for: RoutineTask.self,
                        RoutineLog.self,
                        configurations: retriedConfiguration
                    )
                    return
                } catch {
                    NSLog("Retry after store reset failed: \(error.localizedDescription). Falling back to local-only store.")
                }
            }

            do {
                let localFallback = Self.makeConfiguration(inMemory: inMemory, cloudKitDatabase: .none)
                container = try ModelContainer(
                    for: RoutineTask.self,
                    RoutineLog.self,
                    configurations: localFallback
                )
            } catch {
                NSLog("Local-only ModelContainer init failed: \(error.localizedDescription). Falling back to in-memory store.")

                do {
                    let memoryFallback = Self.makeConfiguration(inMemory: true, cloudKitDatabase: .none)
                    container = try ModelContainer(
                        for: RoutineTask.self,
                        RoutineLog.self,
                        configurations: memoryFallback
                    )
                } catch {
                    fatalError("Failed to initialize in-memory ModelContainer: \(error.localizedDescription)")
                }
            }
        }
    }

    private static func cloudKitDatabase(inMemory: Bool) -> ModelConfiguration.CloudKitDatabase {
        guard !inMemory,
              let cloudContainerIdentifier = AppEnvironment.cloudKitContainerIdentifier,
              !cloudContainerIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return .none
        }

        return .private(cloudContainerIdentifier)
    }

    private static func makeConfiguration(
        inMemory: Bool,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    ) -> ModelConfiguration {
        if inMemory {
            return ModelConfiguration(
                nil,
                schema: nil,
                isStoredInMemoryOnly: true,
                allowsSave: true,
                groupContainer: .automatic,
                cloudKitDatabase: cloudKitDatabase
            )
        }

        if let storeURL = persistentStoreURL() {
            return ModelConfiguration(
                nil,
                schema: nil,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: cloudKitDatabase
            )
        }

        return ModelConfiguration(
            nil,
            schema: nil,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: cloudKitDatabase
        )
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

    private static func removePersistentStoreFiles() {
        guard let storeURL = persistentStoreURL() else { return }

        let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
        let shmURL = URL(fileURLWithPath: storeURL.path + "-shm")
        let fileManager = FileManager.default

        [storeURL, walURL, shmURL].forEach { url in
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.removeItem(at: url)
            }
        }
    }
}

extension PersistenceController: @unchecked Sendable {}

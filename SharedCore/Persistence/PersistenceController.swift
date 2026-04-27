import Foundation
import SwiftData

public struct PersistenceController {
    public static let shared = PersistenceController()

    let container: ModelContainer

    init(inMemory: Bool = false) {
        let primaryCloudDatabase = Self.cloudKitDatabase(inMemory: inMemory)
        let hasExistingPersistentStore = !inMemory && Self.persistentStoreExists()

        do {
            let primaryConfiguration = Self.makeConfiguration(
                inMemory: inMemory,
                cloudKitDatabase: primaryCloudDatabase
            )
            container = try ModelContainer(
                for: RoutineTask.self,
                RoutineLog.self,
                FocusSession.self,
                RoutinePlace.self,
                RoutineAttachment.self,
                configurations: primaryConfiguration
            )
        } catch {
            NSLog(
                "Primary ModelContainer init failed: \(error.localizedDescription)."
            )

            switch Self.strategyAfterPrimaryInitializationFailure(
                inMemory: inMemory,
                hasExistingPersistentStore: hasExistingPersistentStore
            ) {
            case .abortToProtectExistingStore:
                let diagnosticsURL = Self.writeStoreOpenFailureDiagnostics(
                    underlyingError: error
                )
                fatalError(
                    Self.storeOpenFailureMessage(
                        underlyingError: error,
                        diagnosticsPath: diagnosticsURL?.path
                    )
                )
            case .retryPrimaryPersistentStore:
                do {
                    let retriedConfiguration = Self.makeConfiguration(
                        inMemory: inMemory,
                        cloudKitDatabase: primaryCloudDatabase
                    )
                    container = try ModelContainer(
                        for: RoutineTask.self,
                        RoutineLog.self,
                        FocusSession.self,
                        RoutinePlace.self,
                        RoutineAttachment.self,
                        configurations: retriedConfiguration
                    )
                    return
                } catch {
                    NSLog("Retry with the same persistent-store configuration failed: \(error.localizedDescription). Falling back to local-only store.")
                }
            case .skipRetryAndUseFallbacks:
                break
            }

            do {
                let localFallback = Self.makeConfiguration(inMemory: inMemory, cloudKitDatabase: .none)
                container = try ModelContainer(
                    for: RoutineTask.self,
                    RoutineLog.self,
                    FocusSession.self,
                    RoutinePlace.self,
                    RoutineAttachment.self,
                    configurations: localFallback
                )
            } catch {
                NSLog("Local-only ModelContainer init failed: \(error.localizedDescription). Falling back to in-memory store.")

                do {
                    let memoryFallback = Self.makeConfiguration(inMemory: true, cloudKitDatabase: .none)
                    container = try ModelContainer(
                        for: RoutineTask.self,
                        RoutineLog.self,
                        FocusSession.self,
                        RoutinePlace.self,
                        RoutineAttachment.self,
                        configurations: memoryFallback
                    )
                } catch {
                    fatalError("Failed to initialize in-memory ModelContainer: \(error.localizedDescription)")
                }
            }
        }
    }

    enum PrimaryInitializationFailureStrategy: Equatable {
        case abortToProtectExistingStore
        case retryPrimaryPersistentStore
        case skipRetryAndUseFallbacks
    }

    public static func makeLocalOnlyContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = Self.makeConfiguration(
            inMemory: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: RoutineTask.self,
            RoutineLog.self,
            FocusSession.self,
            RoutinePlace.self,
            RoutineAttachment.self,
            configurations: configuration
        )
    }

    static func strategyAfterPrimaryInitializationFailure(
        inMemory: Bool,
        hasExistingPersistentStore: Bool
    ) -> PrimaryInitializationFailureStrategy {
        if inMemory {
            return .skipRetryAndUseFallbacks
        }

        if hasExistingPersistentStore {
            return .abortToProtectExistingStore
        }

        return .retryPrimaryPersistentStore
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

    private static func persistentStoreExists() -> Bool {
        guard let storeURL = persistentStoreURL() else { return false }
        return FileManager.default.fileExists(atPath: storeURL.path)
    }

    static func storeOpenFailureMessage(
        underlyingError: Error,
        storePath: String? = nil,
        diagnosticsPath: String? = nil
    ) -> String {
        let resolvedStorePath = storePath ?? persistentStoreURL()?.path ?? "unknown location"
        let diagnosticsLine: String
        if let diagnosticsPath {
            diagnosticsLine = "\nDiagnostics were written to: \(diagnosticsPath)"
        } else {
            diagnosticsLine = ""
        }
        return """
        Routina refused to open an existing persistent store at \(resolvedStorePath) because the store could not be read with the current app schema.

        To protect user data, the app will not fall back to a new empty store when an existing store is present.
        Underlying error: \(underlyingError.localizedDescription)
        \(diagnosticsLine)
        """
    }

    static func writeStoreOpenFailureDiagnostics(
        underlyingError: Error,
        storePath: String? = nil,
        diagnosticsURL: URL? = nil,
        now: Date = Date()
    ) -> URL? {
        let targetURL = diagnosticsURL ?? defaultStoreOpenFailureDiagnosticsURL()
        guard let targetURL else { return nil }

        let diagnostics = storeOpenFailureDiagnosticsReport(
            underlyingError: underlyingError,
            storePath: storePath,
            now: now
        )

        do {
            let directoryURL = targetURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            try diagnostics.write(to: targetURL, atomically: true, encoding: .utf8)
            NSLog("Persistence diagnostics written to \(targetURL.path)")
            return targetURL
        } catch {
            NSLog("Failed to write persistence diagnostics: \(error.localizedDescription)")
            return nil
        }
    }

    static func storeOpenFailureDiagnosticsReport(
        underlyingError: Error,
        storePath: String? = nil,
        now: Date = Date()
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: now)
        let resolvedStorePath = storePath ?? persistentStoreURL()?.path ?? "unknown location"
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown bundle"

        return """
        Routina Persistence Failure Diagnostics
        Timestamp: \(timestamp)
        Bundle: \(bundleIdentifier)
        Data Mode: \(AppEnvironment.dataModeLabel)
        Store Path: \(resolvedStorePath)
        Underlying Error: \(underlyingError.localizedDescription)
        """
    }

    private static func defaultStoreOpenFailureDiagnosticsURL() -> URL? {
        if let storeURL = persistentStoreURL() {
            return storeURL.deletingLastPathComponent().appendingPathComponent("PersistenceFailure.txt")
        }

        do {
            let applicationSupportDirectory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return applicationSupportDirectory
                .appendingPathComponent("RoutinaData", isDirectory: true)
                .appendingPathComponent("PersistenceFailure.txt")
        } catch {
            NSLog("Failed to resolve diagnostics URL: \(error.localizedDescription)")
            return nil
        }
    }

}

extension PersistenceController: @unchecked Sendable {}

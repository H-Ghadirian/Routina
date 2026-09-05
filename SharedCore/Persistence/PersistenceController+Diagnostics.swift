import Foundation

extension PersistenceController {
    static func persistentStoreURL() -> URL? {
        do {
            let applicationSupportDirectory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let storesDirectory = applicationSupportDirectory.appendingPathComponent(
                "RoutinaData",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: storesDirectory,
                withIntermediateDirectories: true
            )
            return storesDirectory.appendingPathComponent(AppEnvironment.persistentStoreFileName)
        } catch {
            NSLog("Failed to resolve persistent store URL: \(error.localizedDescription)")
            return nil
        }
    }

    static func persistentStoreExists() -> Bool {
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
            return storeURL.deletingLastPathComponent().appendingPathComponent(
                "PersistenceFailure.txt"
            )
        }

        do {
            let applicationSupportDirectory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return
                applicationSupportDirectory
                .appendingPathComponent("RoutinaData", isDirectory: true)
                .appendingPathComponent("PersistenceFailure.txt")
        } catch {
            NSLog("Failed to resolve diagnostics URL: \(error.localizedDescription)")
            return nil
        }
    }
}

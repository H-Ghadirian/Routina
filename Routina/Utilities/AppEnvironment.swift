import Foundation

enum AppEnvironment {
    private static let processEnvironment = ProcessInfo.processInfo.environment
    private static let bundleIdentifier = Bundle.main.bundleIdentifier?.lowercased()

    static let isSandboxDataMode: Bool = {
        if let value = boolValue(from: processEnvironment["ROUTINA_SANDBOX"]) {
            return value
        }

        if let infoValue = infoDictionary["RoutinaSandboxDataMode"] as? Bool {
            return infoValue
        }

        if let infoString = infoDictionary["RoutinaSandboxDataMode"] as? String,
           let value = boolValue(from: infoString) {
            return value
        }

        // Fallback for targets where custom Info keys are absent.
        if bundleIdentifier?.contains(".dev") == true {
            return true
        }
        if bundleIdentifier?.contains(".prod") == true {
            return false
        }

        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    static let cloudKitContainerIdentifier: String? = {
        if let override = resolvedString(
            infoKey: "RoutinaCloudKitContainerIdentifier",
            envKey: "ROUTINA_CLOUDKIT_CONTAINER_ID"
        ) {
            return override
        }

        // Fallback to convention-based containers when custom Info keys are absent.
        if bundleIdentifier?.contains(".dev") == true {
            return "iCloud.ir.hamedgh.Routinam.dev"
        }
        if bundleIdentifier?.contains(".prod") == true {
            return "iCloud.ir.hamedgh.Routinam.prod"
        }

        guard !isSandboxDataMode else { return nil }

        return "iCloud.ir.hamedgh.Routinam"
    }()

    static let persistentStoreFileName: String = {
        if let override = resolvedString(
            infoKey: "RoutinaPersistentStoreFilename",
            envKey: "ROUTINA_STORE_FILENAME"
        ) {
            return override
        }

        return isSandboxDataMode ? "RoutinaModel-Sandbox.sqlite" : "RoutinaModel.sqlite"
    }()

    static let userDefaultsSuiteName: String = {
        if let override = resolvedString(
            infoKey: "RoutinaUserDefaultsSuiteName",
            envKey: "ROUTINA_USER_DEFAULTS_SUITE"
        ) {
            return override
        }

        return isSandboxDataMode ? "app.sandbox" : "app"
    }()

    static let dataModeLabel: String = {
        if isSandboxDataMode {
            return cloudKitContainerIdentifier == nil ? "Sandbox (local only)" : "Sandbox (separate iCloud)"
        }

        return cloudKitContainerIdentifier == nil ? "Production (local only)" : "Production (iCloud)"
    }()
}

private extension AppEnvironment {
    static var infoDictionary: [String: Any] {
        Bundle.main.infoDictionary ?? [:]
    }

    static func resolvedString(infoKey: String, envKey: String) -> String? {
        if let environmentValue = processEnvironment[envKey],
           !environmentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environmentValue
        }

        if let infoValue = infoDictionary[infoKey] as? String,
           !infoValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return infoValue
        }

        return nil
    }

    static func boolValue(from raw: String?) -> Bool? {
        guard let raw else { return nil }

        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return nil
        }
    }
}

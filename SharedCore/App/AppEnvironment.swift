import Foundation
import Security

enum AppEnvironment {
    static let productionDeepLinkURLScheme = "routina"
    static let sandboxDeepLinkURLScheme = "routina-dev"
    static let supportedDeepLinkURLSchemes: Set<String> = [
        productionDeepLinkURLScheme,
        sandboxDeepLinkURLScheme
    ]

    private static let processEnvironment = ProcessInfo.processInfo.environment
    private static let bundleIdentifier = Bundle.main.bundleIdentifier?.lowercased()

    static let deepLinkURLScheme: String = {
        if let override = resolvedString(
            infoKey: "RoutinaDeepLinkURLScheme",
            envKey: "ROUTINA_DEEP_LINK_URL_SCHEME"
        ).map(AppEnvironment.cleanedURLScheme),
           supportedDeepLinkURLSchemes.contains(override) {
            return override
        }

        if bundleIdentifier?.contains(".dev") == true {
            return sandboxDeepLinkURLScheme
        }

        return productionDeepLinkURLScheme
    }()

    static let isUITestMode: Bool = {
        if let value = boolValue(from: processEnvironment["ROUTINA_UI_TEST_MODE"]) {
            return value
        }

        return false
    }()
    static let isAutomatedTestMode: Bool = {
        isUITestMode || processEnvironment["XCTestConfigurationFilePath"] != nil
    }()

    static let isDevelopmentAppVariant: Bool = {
        if let infoValue = infoDictionary["RoutinaSandboxDataMode"] as? Bool {
            return infoValue
        }

        if let infoString = infoDictionary["RoutinaSandboxDataMode"] as? String,
           let value = boolValue(from: infoString) {
            return value
        }

        return bundleIdentifier?.contains(".dev") == true
    }()

    static let isScreenshotDataSeedRequested: Bool = {
        screenshotDataSeedRequested(
            isDevelopmentAppVariant: isDevelopmentAppVariant,
            processEnvironment: processEnvironment
        )
    }()

    static func screenshotDataSeedRequested(
        isDevelopmentAppVariant: Bool,
        processEnvironment: [String: String]
    ) -> Bool {
        guard isDevelopmentAppVariant else { return false }
        return boolValue(from: processEnvironment["ROUTINA_SCREENSHOT_DATA_SEED"]) ?? false
    }

    static let exitsAfterScreenshotDataSeed: Bool = {
        guard isScreenshotDataSeedRequested else { return false }
        return boolValue(from: processEnvironment["ROUTINA_SCREENSHOT_DATA_SEED_EXIT"]) ?? false
    }()

    static let isSandboxDataMode: Bool = {
        if isAutomatedTestMode {
            return true
        }

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
        if isAutomatedTestMode {
            return nil
        }

        if let override = resolvedString(
            infoKey: "RoutinaCloudKitContainerIdentifier",
            envKey: "ROUTINA_CLOUDKIT_CONTAINER_ID"
        ) {
            return override
        }

        if bundleIdentifier?.contains(".dev") == true {
            return "iCloud.ir.hamedgh.Routinam.dev"
        }
        if bundleIdentifier?.contains(".prod") == true {
            return "iCloud.ir.hamedgh.Routinam.prod"
        }

        guard !isSandboxDataMode else { return nil }

        return "iCloud.ir.hamedgh.Routinam"
    }()

    static let isCloudSyncEnabled: Bool = {
        cloudKitContainerIdentifier != nil
    }()

    private static let cloudKitEnvironmentEntitlementKey =
        "com.apple.developer.icloud-container-environment"

    /// The CloudKit environment from this executable's code-signature entitlement.
    ///
    /// This intentionally does not derive from the selected container or the app's
    /// configured data mode: those values cannot prove how the installed binary was signed.
    static let signedCloudKitEnvironmentDescription: String = {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil) else {
            return "Unavailable"
        }

        let entitlementValue = SecTaskCopyValueForEntitlement(
            task,
            cloudKitEnvironmentEntitlementKey as CFString,
            nil
        )
        return cloudKitEnvironmentDescription(from: entitlementValue)
        #else
        // iOS does not expose the public SecTask entitlement-reading API. In
        // particular, TestFlight and App Store apps do not have an embedded
        // provisioning profile that could serve as a signed-entitlement fallback.
        return "Unavailable on iOS"
        #endif
    }()

    static let operatingSystemDescription: String = {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(operatingSystemName) \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }()

    static let persistentStoreFileName: String = {
        if isUITestMode,
           let override = processEnvironment["ROUTINA_STORE_FILENAME"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }

        if let override = resolvedString(
            infoKey: "RoutinaPersistentStoreFilename",
            envKey: "ROUTINA_STORE_FILENAME"
        ) {
            return override
        }

        if isUITestMode {
            return "RoutinaModel-UITests.sqlite"
        }

        return isSandboxDataMode ? "RoutinaModel-Sandbox.sqlite" : "RoutinaModel.sqlite"
    }()

    static let userDefaultsSuiteName: String = {
        if isUITestMode,
           let override = processEnvironment["ROUTINA_USER_DEFAULTS_SUITE"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }

        if let override = resolvedString(
            infoKey: "RoutinaUserDefaultsSuiteName",
            envKey: "ROUTINA_USER_DEFAULTS_SUITE"
        ) {
            return override
        }

        if isUITestMode {
            return "app.ui-tests"
        }

        return isSandboxDataMode ? "app.sandbox" : "app"
    }()

    static let uiTestSeedProfile: String? = {
        guard isUITestMode,
              let rawValue = processEnvironment["ROUTINA_UI_TEST_SEED_PROFILE"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty
        else {
            return nil
        }

        return rawValue
    }()

    static let exitsAfterUITestSeed: Bool = {
        guard isUITestMode else { return false }
        return boolValue(from: processEnvironment["ROUTINA_UI_TEST_EXIT_AFTER_SEED"]) ?? false
    }()

    static let uiTestReportPath: String? = {
        guard isUITestMode,
              let rawValue = processEnvironment["ROUTINA_UI_TEST_REPORT_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty
        else {
            return nil
        }

        return rawValue
    }()

    static let dataModeLabel: String = {
        if isSandboxDataMode {
            return isCloudSyncEnabled ? "Sandbox (separate iCloud)" : "Sandbox (local only)"
        }

        return isCloudSyncEnabled ? "Production (iCloud)" : "Production (local only)"
    }()

    static func cloudKitEnvironmentDescription(from entitlementValue: Any?) -> String {
        guard let rawValue = entitlementValue as? String else {
            return entitlementValue == nil ? "Not present" : "Unexpected value"
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "Not present" }

        switch value.lowercased() {
        case "development":
            return "Development"
        case "production":
            return "Production"
        default:
            return value
        }
    }

    private static var operatingSystemName: String {
        #if os(macOS)
        "macOS"
        #elseif os(iOS)
        "iOS"
        #else
        "Apple OS"
        #endif
    }

    static func cleanedURLScheme(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum RoutinaPublicLinks {
    static let support = URL(string: "https://h-ghadirian.github.io/")!
    static let privacyPolicy = URL(string: "https://h-ghadirian.github.io/#privacy")!
    static let termsOfUse = URL(string: "https://h-ghadirian.github.io/#terms")!
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

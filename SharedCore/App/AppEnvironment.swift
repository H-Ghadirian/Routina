import Foundation

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

    static let defaultUnlocksAllTasks: Bool = {
        if let value = boolValue(from: processEnvironment["ROUTINA_UNLOCK_ALL_TASKS"]) {
            return value
        }

        if let infoValue = infoDictionary["RoutinaUnlockAllTasks"] as? Bool {
            return infoValue
        }

        if let infoString = infoDictionary["RoutinaUnlockAllTasks"] as? String,
           let value = boolValue(from: infoString) {
            return value
        }

        return false
    }()

    static var unlocksAllTasks: Bool {
        if let value = boolValue(from: processEnvironment["ROUTINA_UNLOCK_ALL_TASKS"]) {
            return value
        }

        let key = UserDefaultBoolValueKey.appSettingUnlockUnlimitedTasks.rawValue
        guard SharedDefaults.app.object(forKey: key) != nil else {
            return defaultUnlocksAllTasks
        }
        return SharedDefaults.app[.appSettingUnlockUnlimitedTasks]
    }

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

    static let dataModeLabel: String = {
        if isSandboxDataMode {
            return isCloudSyncEnabled ? "Sandbox (separate iCloud)" : "Sandbox (local only)"
        }

        return isCloudSyncEnabled ? "Production (iCloud)" : "Production (local only)"
    }()

    static func subscriptionProductID(for plan: RoutinaSubscriptionPlan) -> String {
        resolvedString(
            infoKey: plan.subscriptionInfoKey,
            envKey: plan.subscriptionEnvironmentKey
        ) ?? plan.defaultProductID
    }

    static func cleanedURLScheme(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
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

private extension RoutinaSubscriptionPlan {
    var subscriptionInfoKey: String {
        switch self {
        case .weekly:
            return "RoutinaSubscriptionWeeklyProductID"
        case .monthly:
            return "RoutinaSubscriptionMonthlyProductID"
        case .annual:
            return "RoutinaSubscriptionAnnualProductID"
        case .lifetime:
            return "RoutinaSubscriptionLifetimeProductID"
        }
    }

    var subscriptionEnvironmentKey: String {
        switch self {
        case .weekly:
            return "ROUTINA_SUBSCRIPTION_WEEKLY_PRODUCT_ID"
        case .monthly:
            return "ROUTINA_SUBSCRIPTION_MONTHLY_PRODUCT_ID"
        case .annual:
            return "ROUTINA_SUBSCRIPTION_ANNUAL_PRODUCT_ID"
        case .lifetime:
            return "ROUTINA_SUBSCRIPTION_LIFETIME_PRODUCT_ID"
        }
    }
}

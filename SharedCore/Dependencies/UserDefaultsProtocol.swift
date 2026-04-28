import Foundation

extension UserDefaults: @retroactive @unchecked Sendable {}

extension UserDefaults: UserDefaultsProtocol {
    public subscript(key: UserDefaultBoolValueKey) -> Bool {
        get {
            return object(forKey: key.rawValue) as? Bool ?? false
        }
        set {
            self.set(newValue, forKey: key.rawValue)
        }
    }

    public subscript(key: UserDefaultStringValueKey) -> String? {
        get {
            string(forKey: key.rawValue)
        }
        set {
            set(newValue, forKey: key.rawValue)
        }
    }

    public func register(defaults keysWithValues: [UserDefaultBoolValueKey: Bool]) {
        var rawDefaults: [String: Any] = [:]
        for (key, value) in keysWithValues {
            rawDefaults[key.rawValue] = value
        }
        self.register(defaults: rawDefaults)
    }
}

protocol SharedDefaultsProtocol {
    static var app: UserDefaults { get }
}

enum SharedDefaults: SharedDefaultsProtocol {
    static let app: UserDefaults = {
        if let suiteDefaults = UserDefaults(suiteName: AppEnvironment.userDefaultsSuiteName) {
            return suiteDefaults
        }

        NSLog("Invalid UserDefaults suite '\(AppEnvironment.userDefaultsSuiteName)'. Falling back to standard defaults.")
        return .standard
    }()
}

public enum UserDefaultBoolValueKey: String, Sendable {
    case appSettingNotificationsEnabled
    case appSettingHideUnavailableRoutines
    case appSettingAppLockEnabled
    case appSettingGitFeaturesEnabled
    case appSettingShowPersianDates
    case requestNotificationPermission
}

public enum UserDefaultStringValueKey: String, Sendable {
    case selectedMacAppIcon
    case appSettingAppColorScheme
    case appSettingRoutineListSectioningMode
    case appSettingTagCounterDisplayMode
    case appSettingRelatedTagRules
    case appSettingTagColors
    case appSettingTemporaryViewState
    case macFormSectionOrder
}

public protocol UserDefaultsProtocol {
    subscript(key: UserDefaultBoolValueKey) -> Bool { get set }
    subscript(key: UserDefaultStringValueKey) -> String? { get set }
    func register(defaults keysWithValues: [UserDefaultBoolValueKey: Bool])
}

struct AppSettingsClient: Sendable {
    var notificationsEnabled: @Sendable () -> Bool
    var setNotificationsEnabled: @Sendable (Bool) -> Void
    var hideUnavailableRoutines: @Sendable () -> Bool
    var setHideUnavailableRoutines: @Sendable (Bool) -> Void
    var appLockEnabled: @Sendable () -> Bool
    var setAppLockEnabled: @Sendable (Bool) -> Void
    var gitFeaturesEnabled: @Sendable () -> Bool
    var setGitFeaturesEnabled: @Sendable (Bool) -> Void
    var showPersianDates: @Sendable () -> Bool
    var setShowPersianDates: @Sendable (Bool) -> Void
    var appColorScheme: @Sendable () -> AppColorScheme
    var setAppColorScheme: @Sendable (AppColorScheme) -> Void
    var routineListSectioningMode: @Sendable () -> RoutineListSectioningMode
    var setRoutineListSectioningMode: @Sendable (RoutineListSectioningMode) -> Void
    var tagCounterDisplayMode: @Sendable () -> TagCounterDisplayMode
    var setTagCounterDisplayMode: @Sendable (TagCounterDisplayMode) -> Void
    var relatedTagRules: @Sendable () -> [RoutineRelatedTagRule]
    var setRelatedTagRules: @Sendable ([RoutineRelatedTagRule]) -> Void
    var tagColors: @Sendable () -> [String: String]
    var setTagColors: @Sendable ([String: String]) -> Void
    var notificationReminderTime: @Sendable () -> Date
    var setNotificationReminderTime: @Sendable (Date) -> Void
    var selectedAppIcon: @Sendable () -> AppIconOption
    var temporaryViewState: @Sendable () -> TemporaryViewState?
    var setTemporaryViewState: @Sendable (TemporaryViewState?) -> Void
    var resetTemporaryViewState: @Sendable () -> Void
}

enum CloudSettingsKeyValueSync {
    static let didChangeNotification = Notification.Name("CloudSettingsKeyValueSync.didChange")

    private static let observerBox = CloudSettingsObserverBox()
    private static let syncedStringKeys: Set<UserDefaultStringValueKey> = [
        .selectedMacAppIcon,
        .appSettingRelatedTagRules,
        .appSettingTagColors
    ]

    static func startIfNeeded() {
        guard AppEnvironment.isCloudSyncEnabled,
              !AppEnvironment.isAutomatedTestMode else {
            return
        }

        guard observerBox.observer == nil else {
            synchronizeKnownValues()
            return
        }

        let observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { notification in
            handleExternalChange(notification)
        }
        observerBox.observer = observer
        synchronizeKnownValues()
    }

    static func string(for key: UserDefaultStringValueKey) -> String? {
        guard syncedStringKeys.contains(key),
              AppEnvironment.isCloudSyncEnabled,
              !AppEnvironment.isAutomatedTestMode else {
            return SharedDefaults.app[key]
        }

        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        guard let remoteValue = store.string(forKey: key.rawValue) else {
            return SharedDefaults.app[key]
        }

        if SharedDefaults.app[key] != remoteValue {
            SharedDefaults.app[key] = remoteValue
        }
        return remoteValue
    }

    static func setString(_ value: String?, for key: UserDefaultStringValueKey) {
        SharedDefaults.app[key] = value

        guard syncedStringKeys.contains(key),
              AppEnvironment.isCloudSyncEnabled,
              !AppEnvironment.isAutomatedTestMode else {
            return
        }

        let store = NSUbiquitousKeyValueStore.default
        if let value {
            store.set(value, forKey: key.rawValue)
        } else {
            store.removeObject(forKey: key.rawValue)
        }
        store.synchronize()
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    private static func synchronizeKnownValues() {
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        var didUpdateLocalDefaults = false

        for key in syncedStringKeys {
            if let remoteValue = store.string(forKey: key.rawValue) {
                if SharedDefaults.app[key] != remoteValue {
                    SharedDefaults.app[key] = remoteValue
                    didUpdateLocalDefaults = true
                }
            } else if let localValue = SharedDefaults.app[key] {
                store.set(localValue, forKey: key.rawValue)
            }
        }

        store.synchronize()
        if didUpdateLocalDefaults {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    private static func handleExternalChange(_ notification: Notification) {
        guard let changedRawKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            synchronizeKnownValues()
            return
        }

        let store = NSUbiquitousKeyValueStore.default
        var didUpdateLocalDefaults = false
        for key in syncedStringKeys where changedRawKeys.contains(key.rawValue) {
            let value = store.string(forKey: key.rawValue)
            if SharedDefaults.app[key] != value {
                SharedDefaults.app[key] = value
                didUpdateLocalDefaults = true
            }
        }

        if didUpdateLocalDefaults {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }
}

private final class CloudSettingsObserverBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: NSObjectProtocol?

    var observer: NSObjectProtocol? {
        get {
            lock.withLock { value }
        }
        set {
            lock.withLock {
                value = newValue
            }
        }
    }
}

extension AppSettingsClient {
    static let live = AppSettingsClient(
        notificationsEnabled: {
            SharedDefaults.app[.appSettingNotificationsEnabled]
        },
        setNotificationsEnabled: { isEnabled in
            SharedDefaults.app[.appSettingNotificationsEnabled] = isEnabled
        },
        hideUnavailableRoutines: {
            SharedDefaults.app[.appSettingHideUnavailableRoutines]
        },
        setHideUnavailableRoutines: { isHidden in
            SharedDefaults.app[.appSettingHideUnavailableRoutines] = isHidden
        },
        appLockEnabled: {
            SharedDefaults.app[.appSettingAppLockEnabled]
        },
        setAppLockEnabled: { isEnabled in
            SharedDefaults.app[.appSettingAppLockEnabled] = isEnabled
        },
        gitFeaturesEnabled: {
            SharedDefaults.app[.appSettingGitFeaturesEnabled]
        },
        setGitFeaturesEnabled: { isEnabled in
            SharedDefaults.app[.appSettingGitFeaturesEnabled] = isEnabled
        },
        showPersianDates: {
            SharedDefaults.app[.appSettingShowPersianDates]
        },
        setShowPersianDates: { isEnabled in
            SharedDefaults.app[.appSettingShowPersianDates] = isEnabled
        },
        appColorScheme: {
            AppColorScheme(
                rawValue: SharedDefaults.app[.appSettingAppColorScheme] ?? ""
            ) ?? .system
        },
        setAppColorScheme: { scheme in
            SharedDefaults.app[.appSettingAppColorScheme] = scheme.rawValue
        },
        routineListSectioningMode: {
            RoutineListSectioningMode(
                rawValue: SharedDefaults.app[.appSettingRoutineListSectioningMode] ?? ""
            ) ?? .defaultValue
        },
        setRoutineListSectioningMode: { mode in
            SharedDefaults.app[.appSettingRoutineListSectioningMode] = mode.rawValue
        },
        tagCounterDisplayMode: {
            TagCounterDisplayMode(
                rawValue: SharedDefaults.app[.appSettingTagCounterDisplayMode] ?? ""
            ) ?? .defaultValue
        },
        setTagCounterDisplayMode: { mode in
            SharedDefaults.app[.appSettingTagCounterDisplayMode] = mode.rawValue
        },
        relatedTagRules: {
            guard let rawValue = CloudSettingsKeyValueSync.string(for: .appSettingRelatedTagRules),
                  let data = rawValue.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([RoutineRelatedTagRule].self, from: data)
            else {
                return []
            }
            return RoutineTagRelations.sanitized(decoded)
        },
        setRelatedTagRules: { rules in
            let sanitizedRules = RoutineTagRelations.sanitized(rules)
            guard !sanitizedRules.isEmpty else {
                CloudSettingsKeyValueSync.setString(nil, for: .appSettingRelatedTagRules)
                return
            }
            guard let data = try? JSONEncoder().encode(sanitizedRules),
                  let rawValue = String(data: data, encoding: .utf8)
            else {
                return
            }
            CloudSettingsKeyValueSync.setString(rawValue, for: .appSettingRelatedTagRules)
        },
        tagColors: {
            guard let rawValue = CloudSettingsKeyValueSync.string(for: .appSettingTagColors),
                  let data = rawValue.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data)
            else {
                return [:]
            }
            return RoutineTagColors.sanitized(decoded)
        },
        setTagColors: { colors in
            let sanitizedColors = RoutineTagColors.sanitized(colors)
            guard !sanitizedColors.isEmpty else {
                CloudSettingsKeyValueSync.setString(nil, for: .appSettingTagColors)
                return
            }
            guard let data = try? JSONEncoder().encode(sanitizedColors),
                  let rawValue = String(data: data, encoding: .utf8)
            else {
                return
            }
            CloudSettingsKeyValueSync.setString(rawValue, for: .appSettingTagColors)
        },
        notificationReminderTime: {
            NotificationPreferences.reminderTimeDate()
        },
        setNotificationReminderTime: { date in
            NotificationPreferences.storeReminderTime(date)
        },
        selectedAppIcon: {
            .persistedSelection
        },
        temporaryViewState: {
            guard let rawValue = SharedDefaults.app[.appSettingTemporaryViewState],
                  let data = rawValue.data(using: .utf8)
            else {
                return nil
            }

            return try? JSONDecoder().decode(TemporaryViewState.self, from: data)
        },
        setTemporaryViewState: { state in
            guard let state else {
                SharedDefaults.app[.appSettingTemporaryViewState] = nil
                return
            }

            guard let data = try? JSONEncoder().encode(state),
                  let rawValue = String(data: data, encoding: .utf8)
            else {
                return
            }

            SharedDefaults.app[.appSettingTemporaryViewState] = rawValue
        },
        resetTemporaryViewState: {
            SharedDefaults.app[.appSettingHideUnavailableRoutines] = false
            SharedDefaults.app[.appSettingTemporaryViewState] = nil
        }
    )

    static let noop = AppSettingsClient(
        notificationsEnabled: { false },
        setNotificationsEnabled: { _ in },
        hideUnavailableRoutines: { false },
        setHideUnavailableRoutines: { _ in },
        appLockEnabled: { false },
        setAppLockEnabled: { _ in },
        gitFeaturesEnabled: { false },
        setGitFeaturesEnabled: { _ in },
        showPersianDates: { false },
        setShowPersianDates: { _ in },
        appColorScheme: { .system },
        setAppColorScheme: { _ in },
        routineListSectioningMode: { .defaultValue },
        setRoutineListSectioningMode: { _ in },
        tagCounterDisplayMode: { .defaultValue },
        setTagCounterDisplayMode: { _ in },
        relatedTagRules: { [] },
        setRelatedTagRules: { _ in },
        tagColors: { [:] },
        setTagColors: { _ in },
        notificationReminderTime: { Date() },
        setNotificationReminderTime: { _ in },
        selectedAppIcon: { .orange },
        temporaryViewState: { nil },
        setTemporaryViewState: { _ in },
        resetTemporaryViewState: { }
    )
}

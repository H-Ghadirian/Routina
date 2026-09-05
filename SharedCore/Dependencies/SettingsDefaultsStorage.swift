import Foundation

enum CloudSettingsKeyValueSync {
    static let didChangeNotification = Notification.Name("CloudSettingsKeyValueSync.didChange")

    private static let observerBox = CloudSettingsObserverBox()
    private static let syncedStringKeys: Set<UserDefaultStringValueKey> = [
        .selectedMacAppIcon,
        .appSettingRelatedTagRules,
        .appSettingTagRules,
        .appSettingFlagRules,
        .appSettingDefinedFlags,
        .appSettingTagColors,
        .appSettingFastFilterTags,
        .appSettingIOSStatsDashboardHiddenItemIDs,
        .appSettingIOSStatsDashboardItemOrderIDs,
        .appSettingIOSStatsSummaryDisplayMode,
        .appSettingMacStatsDashboardHiddenItemIDs,
        .appSettingMacStatsDashboardItemOrderIDs,
        .appSettingMacStatsSummaryDisplayMode,
        .appSettingHiddenDayPlanTimelineActivityIDs,
        .appSettingMacTaskLadderOrganization,
    ]

    static func startIfNeeded() {
        guard AppEnvironment.isCloudSyncEnabled,
            !AppEnvironment.isAutomatedTestMode
        else {
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
            !AppEnvironment.isAutomatedTestMode
        else {
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
        AppSettingsPersistenceMirror.schedule()

        guard syncedStringKeys.contains(key),
            AppEnvironment.isCloudSyncEnabled,
            !AppEnvironment.isAutomatedTestMode
        else {
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

enum TemporaryViewStateDefaultsStore {
    static func load(from defaults: UserDefaults = SharedDefaults.app) -> TemporaryViewState? {
        guard let rawValue = defaults[.appSettingTemporaryViewState],
            let data = rawValue.data(using: .utf8)
        else {
            return nil
        }

        return try? JSONDecoder().decode(TemporaryViewState.self, from: data)
    }

    @discardableResult
    static func storeIfChanged(
        _ state: TemporaryViewState?,
        in defaults: UserDefaults = SharedDefaults.app
    ) -> Bool {
        if let state {
            guard load(from: defaults) != state else { return false }
            guard let data = try? JSONEncoder().encode(state),
                let rawValue = String(data: data, encoding: .utf8)
            else {
                return false
            }
            defaults[.appSettingTemporaryViewState] = rawValue
            return true
        }

        guard defaults[.appSettingTemporaryViewState] != nil else { return false }
        defaults[.appSettingTemporaryViewState] = nil
        return true
    }
}

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

public enum UserDefaultBoolValueKey: String {
    case appSettingNotificationsEnabled
    case appSettingHideUnavailableRoutines
    case requestNotificationPermission
}

public enum UserDefaultStringValueKey: String {
    case selectedMacAppIcon
    case appSettingRoutineListSectioningMode
    case appSettingTemporaryViewState
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
    var routineListSectioningMode: @Sendable () -> RoutineListSectioningMode
    var setRoutineListSectioningMode: @Sendable (RoutineListSectioningMode) -> Void
    var notificationReminderTime: @Sendable () -> Date
    var setNotificationReminderTime: @Sendable (Date) -> Void
    var selectedAppIcon: @Sendable () -> AppIconOption
    var temporaryViewState: @Sendable () -> TemporaryViewState?
    var setTemporaryViewState: @Sendable (TemporaryViewState?) -> Void
    var resetTemporaryViewState: @Sendable () -> Void
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
        routineListSectioningMode: {
            RoutineListSectioningMode(
                rawValue: SharedDefaults.app[.appSettingRoutineListSectioningMode] ?? ""
            ) ?? .defaultValue
        },
        setRoutineListSectioningMode: { mode in
            SharedDefaults.app[.appSettingRoutineListSectioningMode] = mode.rawValue
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
        routineListSectioningMode: { .defaultValue },
        setRoutineListSectioningMode: { _ in },
        notificationReminderTime: { Date() },
        setNotificationReminderTime: { _ in },
        selectedAppIcon: { .orange },
        temporaryViewState: { nil },
        setTemporaryViewState: { _ in },
        resetTemporaryViewState: { }
    )
}

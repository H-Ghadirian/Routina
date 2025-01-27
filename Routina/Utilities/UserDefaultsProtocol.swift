import Foundation

extension UserDefaults: UserDefaultsProtocol {
    public subscript(key: UserDefaultBoolValueKey) -> Bool {
        get {
            return object(forKey: key.rawValue) as? Bool ?? false
        }
        set {
            self.set(newValue, forKey: key.rawValue)
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
    static var app: UserDefaults { get set }
}

enum SharedDefaults: SharedDefaultsProtocol {
    static var app = UserDefaults(suiteName: "app")!
}

public enum UserDefaultBoolValueKey: String {
    case appSettingNotificationsEnabled
    case requestNotificationPermission
}

public protocol UserDefaultsProtocol {
    subscript(key: UserDefaultBoolValueKey) -> Bool { get set }
    func register(defaults keysWithValues: [UserDefaultBoolValueKey: Bool])
}

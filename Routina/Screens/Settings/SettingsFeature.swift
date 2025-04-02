import ComposableArchitecture
import SwiftUI
import UserNotifications

@Reducer
struct SettingsFeature {

    @ObservableState
    struct State: Equatable {
        var appVersion: String = ""
        var notificationsEnabled: Bool = SharedDefaults.app[.appSettingNotificationsEnabled]
        var systemSettingsNotificationsEnabled: Bool = true
    }

    enum Action: Equatable {
        case toggleNotifications(Bool)
        case openAppSettingsTapped
        case onAppear
        case onAppBecameActive
        case contactUsTapped
        case systemNotificationPermissionChecked(Bool)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleNotifications(let isOn):
                AmplitudeTracker.shared.logEvent("Notifications toggled \(isOn)")
                state.notificationsEnabled = isOn
                SharedDefaults.app[.appSettingNotificationsEnabled] = isOn
                return .none

            case .openAppSettingsTapped:
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                return .none
                
            case .onAppear:
                state.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                return .run { send in
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    let systemEnabled = settings.authorizationStatus == .authorized
                    await send(.systemNotificationPermissionChecked(systemEnabled))
                }
                
            case .contactUsTapped:
                AmplitudeTracker.shared.logEvent("Contact us")
#if os(iOS)
                if let emailURL = URL(string: "mailto:h.qadirian@gmail.com") {
                    return .run { _ in
                        await MainActor.run {
                            UIApplication.shared.open(emailURL)
                        }
                    }
                }
#endif
                return .none

            case let .systemNotificationPermissionChecked(value):
                state.systemSettingsNotificationsEnabled = value
                return .none
            case .onAppBecameActive:
                return .run { send in
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    let systemEnabled = settings.authorizationStatus == .authorized
                    await send(.systemNotificationPermissionChecked(systemEnabled))
                }
            }
        }
    }
}

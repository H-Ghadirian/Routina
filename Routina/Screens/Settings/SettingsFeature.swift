import ComposableArchitecture
import SwiftUI

@Reducer
struct SettingsFeature {

    @ObservableState
    struct State: Equatable {
        var appVersion: String = ""
        var notificationsEnabled: Bool = SharedDefaults.app[.appSettingNotificationsEnabled]
    }

    enum Action: Equatable {
        case toggleNotifications(Bool)
        case openAppSettingsTapped
        case onAppear
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleNotifications(let isOn):
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
                return .none
            }
        }
    }
}

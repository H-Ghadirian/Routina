import ComposableArchitecture
import SwiftUI

@Reducer
struct SettingsFeature {

    @ObservableState
    struct State: Equatable {
        var version: String = "1.0"
        var notificationsEnabled: Bool = SharedDefaults.app[.appSettingNotificationsEnabled]
    }

    enum Action: Equatable {
        case checkForUpdates
        case updateVersion(String)
        case toggleNotifications(Bool)
        case openAppSettingsTapped
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .checkForUpdates:
                state.version = "1.1"
                return .none
            case .updateVersion(let version):
                state.version = version
                return .none

            case .toggleNotifications(let isOn):
                state.notificationsEnabled = isOn
                SharedDefaults.app[.appSettingNotificationsEnabled] = isOn
                return .none

            case .openAppSettingsTapped:
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                return .none
            }
        }
    }
}

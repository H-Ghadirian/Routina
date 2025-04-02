import ComposableArchitecture
import UserNotifications
import AmplitudeSwift

@Reducer
struct AppFeature {

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var home = HomeFeature.State()
        var settings = SettingsFeature.State()
    }

    @CasePathable
    enum Action: Equatable {
        case tabSelected(Tab)
        case home(HomeFeature.Action)
        case settings(SettingsFeature.Action)
        case onAppear
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                AmplitudeTracker.shared.logEvent("Tab selected: \(tab.rawValue)")
                state.selectedTab = tab
                return .none
            case .onAppear:
                AmplitudeTracker.shared.logEvent("App opened")
                return .run { _ in
                    await requestNotificationAuthorization()
                }
            default:
                return .none
            }
        }
    }

    private func requestNotificationAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        print("🔔 Notification permission granted: \(granted ?? false)")
    }
}

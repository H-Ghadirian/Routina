import ComposableArchitecture

struct AppFeature: Reducer {
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
                state.selectedTab = tab
                return .none
            default:
                return .none
            }
        }
    }
}

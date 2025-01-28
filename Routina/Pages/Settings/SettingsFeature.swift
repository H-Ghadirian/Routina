import ComposableArchitecture

struct SettingsFeature: Reducer {
    struct State: Equatable {
        var version: String = "1.0"
    }

    enum Action: Equatable {
        case checkForUpdates
        case updateVersion(String)
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
            }
        }
    }
}

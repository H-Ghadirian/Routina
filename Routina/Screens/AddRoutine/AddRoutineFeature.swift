import ComposableArchitecture

struct AddRoutineFeature: Reducer {
    struct State: Equatable {
        var routineName: String = ""
    }

    enum Action: Equatable {
        case routineNameChanged(String)
        case saveTapped
        case cancelTapped
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .routineNameChanged(name):
            state.routineName = name
            return .none
        case .saveTapped:
            // Save logic here
            return .none
        case .cancelTapped:
            return .none
        }
    }
}

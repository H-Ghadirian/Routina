import Foundation
import ComposableArchitecture

struct AddRoutineFeature: Reducer {
    struct State: Equatable {
        var routineName: String = ""
        var frequency: Int = 1
    }

    enum Action: Equatable {
        case routineNameChanged(String)
        case frequencyChanged(Int)
        case saveTapped
        case cancelTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case didCancel
            case didSave(String, Int)
        }
    }

    var onSave: (String, Int) -> Effect<Action>
    var onCancel: () -> Effect<Action>

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .routineNameChanged(name):
            state.routineName = name
            return .none

        case let .frequencyChanged(freq):
            state.frequency = freq
            return .none

        case .saveTapped:
            return onSave(state.routineName, state.frequency)

        case .cancelTapped:
            return onCancel()
        case .delegate(_):
            return .none
        }
    }
}

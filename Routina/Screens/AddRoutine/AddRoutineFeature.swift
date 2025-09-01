import Foundation
import ComposableArchitecture

@Reducer
struct AddRoutineFeature {
    struct State: Equatable {
        var routineName: String = ""
        var frequency: Int = 1
    }

    enum Action: Equatable {
        case routineNameChanged(String)
        case frequencyChanged(Int)
        case saveButtonTapped
        case cancelButtonTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case didCancel
            case didSave(String, Int)
        }
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .routineNameChanged(name):
                state.routineName = name
                return .none

            case let .frequencyChanged(freq):
                state.frequency = freq
                return .none

            case .saveButtonTapped:
                return .send(.delegate(.didSave(state.routineName, state.frequency)))

            case .cancelButtonTapped:
                return .send(.delegate(.didCancel))
                
            case .delegate:
                return .none
            }
        }
    }
}

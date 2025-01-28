import ComposableArchitecture
import Foundation

struct HomeFeature: Reducer {
    struct State: Equatable {
        var callMomDueDate: Date = Date()
        var logs: [Date] = []
    }

    enum Action: Equatable {
        case markAsDone
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .markAsDone:
                state.logs.append(Date())
                return .none
            }
        }
    }
}

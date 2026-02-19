import Foundation
import ComposableArchitecture

struct AddRoutineFeature: Reducer {
    enum Frequency: String, CaseIterable, Equatable {
        case day = "Day"
        case week = "Week"
        case month = "Month"

        var daysMultiplier: Int {
            switch self {
            case .day:
                return 1
            case .week:
                return 7
            case .month:
                return 30
            }
        }

        var singularLabel: String {
            switch self {
            case .day:
                return "day"
            case .week:
                return "week"
            case .month:
                return "month"
            }
        }
    }

    struct State: Equatable {
        var routineName: String = ""
        var frequency: Frequency = .day
        var frequencyValue: Int = 1
    }

    enum Action: Equatable {
        case routineNameChanged(String)
        case frequencyChanged(Frequency)
        case frequencyValueChanged(Int)
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

        case let .frequencyValueChanged(value):
            state.frequencyValue = value
            return .none

        case .saveTapped:
            let frequencyInDays = state.frequencyValue * state.frequency.daysMultiplier
            return onSave(state.routineName, frequencyInDays)

        case .cancelTapped:
            return onCancel()
        case .delegate(_):
            return .none
        }
    }
}

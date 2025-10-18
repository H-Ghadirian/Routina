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

    @ObservableState
    struct State: Equatable {
        var routineName: String = ""
        var routineEmoji: String = "✨"
        var routineTags: [String] = []
        var tagDraft: String = ""
        var frequency: Frequency = .day
        var frequencyValue: Int = 1
        var existingRoutineNames: [String] = []
        var nameValidationMessage: String?

        var trimmedRoutineName: String {
            routineName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var isSaveDisabled: Bool {
            trimmedRoutineName.isEmpty || nameValidationMessage != nil
        }
    }

    enum Action: Equatable {
        case routineNameChanged(String)
        case routineEmojiChanged(String)
        case tagDraftChanged(String)
        case addTagTapped
        case removeTag(String)
        case frequencyChanged(Frequency)
        case frequencyValueChanged(Int)
        case existingRoutineNamesChanged([String])
        case saveTapped
        case cancelTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case didCancel
            case didSave(String, Int, String, [String])
        }
    }

    var onSave: (String, Int, String, [String]) -> Effect<Action>
    var onCancel: () -> Effect<Action>

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .routineNameChanged(name):
            state.routineName = name
            updateNameValidation(&state)
            return .none

        case let .routineEmojiChanged(emoji):
            state.routineEmoji = sanitizedEmoji(from: emoji, fallback: state.routineEmoji)
            return .none

        case let .tagDraftChanged(value):
            state.tagDraft = value
            return .none

        case .addTagTapped:
            state.routineTags = RoutineTag.appending(state.tagDraft, to: state.routineTags)
            state.tagDraft = ""
            return .none

        case let .removeTag(tag):
            state.routineTags = RoutineTag.removing(tag, from: state.routineTags)
            return .none

        case let .frequencyChanged(freq):
            state.frequency = freq
            return .none

        case let .frequencyValueChanged(value):
            state.frequencyValue = value
            return .none

        case let .existingRoutineNamesChanged(names):
            state.existingRoutineNames = names
            updateNameValidation(&state)
            return .none

        case .saveTapped:
            state.routineTags = RoutineTag.appending(state.tagDraft, to: state.routineTags)
            state.tagDraft = ""
            updateNameValidation(&state)
            guard !state.isSaveDisabled else { return .none }
            let frequencyInDays = state.frequencyValue * state.frequency.daysMultiplier
            return onSave(state.trimmedRoutineName, frequencyInDays, state.routineEmoji, state.routineTags)

        case .cancelTapped:
            return onCancel()
        case .delegate(_):
            return .none
        }
    }

    private func sanitizedEmoji(from input: String, fallback: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return fallback }
        return String(first)
    }

    private func updateNameValidation(_ state: inout State) {
        guard let normalizedName = normalizedRoutineName(state.routineName) else {
            state.nameValidationMessage = nil
            return
        }

        let hasDuplicate = state.existingRoutineNames.contains { existingName in
            normalizedRoutineName(existingName) == normalizedName
        }

        state.nameValidationMessage = hasDuplicate
            ? "A routine with this name already exists."
            : nil
    }

    private func normalizedRoutineName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

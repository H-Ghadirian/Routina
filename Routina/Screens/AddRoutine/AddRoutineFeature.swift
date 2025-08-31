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
        var routineSteps: [RoutineStep] = []
        var stepDraft: String = ""
        var frequency: Frequency = .day
        var frequencyValue: Int = 1
        var existingRoutineNames: [String] = []
        var availablePlaces: [RoutinePlaceSummary] = []
        var selectedPlaceID: UUID?
        var nameValidationMessage: String?

        var trimmedRoutineName: String {
            RoutineTask.trimmedName(routineName) ?? ""
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
        case stepDraftChanged(String)
        case addStepTapped
        case removeStep(UUID)
        case moveStepUp(UUID)
        case moveStepDown(UUID)
        case frequencyChanged(Frequency)
        case frequencyValueChanged(Int)
        case existingRoutineNamesChanged([String])
        case availablePlacesChanged([RoutinePlaceSummary])
        case selectedPlaceChanged(UUID?)
        case saveTapped
        case cancelTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case didCancel
            case didSave(String, Int, String, UUID?, [String], [RoutineStep])
        }
    }

    var onSave: (String, Int, String, UUID?, [String], [RoutineStep]) -> Effect<Action>
    var onCancel: () -> Effect<Action>

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .routineNameChanged(name):
            state.routineName = name
            updateNameValidation(&state)
            return .none

        case let .routineEmojiChanged(emoji):
            state.routineEmoji = RoutineTask.sanitizedEmoji(emoji, fallback: state.routineEmoji)
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

        case let .stepDraftChanged(value):
            state.stepDraft = value
            return .none

        case .addStepTapped:
            state.routineSteps = appendStep(from: state.stepDraft, to: state.routineSteps)
            state.stepDraft = ""
            return .none

        case let .removeStep(stepID):
            state.routineSteps.removeAll { $0.id == stepID }
            return .none

        case let .moveStepUp(stepID):
            moveStep(stepID, by: -1, state: &state)
            return .none

        case let .moveStepDown(stepID):
            moveStep(stepID, by: 1, state: &state)
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

        case let .availablePlacesChanged(places):
            state.availablePlaces = places
            if let selectedPlaceID = state.selectedPlaceID,
               !places.contains(where: { $0.id == selectedPlaceID }) {
                state.selectedPlaceID = nil
            }
            return .none

        case let .selectedPlaceChanged(placeID):
            state.selectedPlaceID = placeID
            return .none

        case .saveTapped:
            state.routineTags = RoutineTag.appending(state.tagDraft, to: state.routineTags)
            state.tagDraft = ""
            state.routineSteps = appendStep(from: state.stepDraft, to: state.routineSteps)
            state.stepDraft = ""
            updateNameValidation(&state)
            guard !state.isSaveDisabled else { return .none }
            let frequencyInDays = state.frequencyValue * state.frequency.daysMultiplier
            return onSave(
                state.trimmedRoutineName,
                frequencyInDays,
                state.routineEmoji,
                state.selectedPlaceID,
                state.routineTags,
                RoutineStep.sanitized(state.routineSteps)
            )

        case .cancelTapped:
            return onCancel()
        case .delegate(_):
            return .none
        }
    }

    private func updateNameValidation(_ state: inout State) {
        guard let normalizedName = RoutineTask.normalizedName(state.routineName) else {
            state.nameValidationMessage = nil
            return
        }

        let hasDuplicate = state.existingRoutineNames.contains { existingName in
            RoutineTask.normalizedName(existingName) == normalizedName
        }

        state.nameValidationMessage = hasDuplicate
            ? "A routine with this name already exists."
            : nil
    }

    private func appendStep(from draft: String, to currentSteps: [RoutineStep]) -> [RoutineStep] {
        guard let title = RoutineStep.normalizedTitle(draft) else { return currentSteps }
        return currentSteps + [RoutineStep(title: title)]
    }

    private func moveStep(_ stepID: UUID, by offset: Int, state: inout State) {
        guard let index = state.routineSteps.firstIndex(where: { $0.id == stepID }) else { return }
        let targetIndex = index + offset
        guard state.routineSteps.indices.contains(targetIndex) else { return }
        let step = state.routineSteps.remove(at: index)
        state.routineSteps.insert(step, at: targetIndex)
    }
}

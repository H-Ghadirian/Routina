import ComposableArchitecture
import Foundation

struct TaskDetailStepChecklistEditActionHandler {
    typealias State = TaskDetailFeature.State
    typealias Action = TaskDetailFeature.Action

    var now: () -> Date

    func editStepDraftChanged(_ value: String, state: inout State) -> Effect<Action> {
        state.editStepDraft = value
        return .none
    }

    func editAddStepTapped(state: inout State) -> Effect<Action> {
        state.editRoutineSteps = appendStep(from: state.editStepDraft, to: state.editRoutineSteps)
        state.editStepDraft = ""
        disableAutoAssumeIfNeeded(state: &state)
        return .none
    }

    func editRemoveStep(_ stepID: UUID, state: inout State) -> Effect<Action> {
        state.editRoutineSteps.removeAll { $0.id == stepID }
        disableAutoAssumeIfNeeded(state: &state)
        return .none
    }

    func editMoveStepUp(_ stepID: UUID, state: inout State) -> Effect<Action> {
        moveStep(stepID, by: -1, state: &state)
        return .none
    }

    func editMoveStepDown(_ stepID: UUID, state: inout State) -> Effect<Action> {
        moveStep(stepID, by: 1, state: &state)
        return .none
    }

    func editChecklistItemDraftTitleChanged(
        _ value: String,
        state: inout State
    ) -> Effect<Action> {
        state.editChecklistItemDraftTitle = value
        return .none
    }

    func editChecklistItemDraftIntervalChanged(
        _ value: Int,
        state: inout State
    ) -> Effect<Action> {
        state.editChecklistItemDraftInterval = RoutineChecklistItem.clampedIntervalDays(value)
        return .none
    }

    func editAddChecklistItemTapped(state: inout State) -> Effect<Action> {
        state.editRoutineChecklistItems = appendChecklistItem(
            from: state.editChecklistItemDraftTitle,
            intervalDays: state.editChecklistItemDraftInterval,
            createdAt: now(),
            to: state.editRoutineChecklistItems
        )
        state.editChecklistItemDraftTitle = ""
        state.editChecklistItemDraftInterval = 3
        disableAutoAssumeIfNeeded(state: &state)
        return .none
    }

    func editRemoveChecklistItem(_ itemID: UUID, state: inout State) -> Effect<Action> {
        state.editRoutineChecklistItems.removeAll { $0.id == itemID }
        disableAutoAssumeIfNeeded(state: &state)
        return .none
    }

    private func moveStep(_ stepID: UUID, by offset: Int, state: inout State) {
        guard let index = state.editRoutineSteps.firstIndex(where: { $0.id == stepID }) else { return }
        let targetIndex = index + offset
        guard state.editRoutineSteps.indices.contains(targetIndex) else { return }
        let step = state.editRoutineSteps.remove(at: index)
        state.editRoutineSteps.insert(step, at: targetIndex)
    }

    private func appendStep(from draft: String, to currentSteps: [RoutineStep]) -> [RoutineStep] {
        guard let title = RoutineStep.normalizedTitle(draft) else { return currentSteps }
        return currentSteps + [RoutineStep(title: title)]
    }

    private func appendChecklistItem(
        from draftTitle: String,
        intervalDays: Int,
        createdAt: Date,
        to currentItems: [RoutineChecklistItem]
    ) -> [RoutineChecklistItem] {
        guard let title = RoutineChecklistItem.normalizedTitle(draftTitle) else { return currentItems }
        return currentItems + [
            RoutineChecklistItem(
                title: title,
                intervalDays: intervalDays,
                createdAt: createdAt
            )
        ]
    }

    private func disableAutoAssumeIfNeeded(state: inout State) {
        if !state.canAutoAssumeDailyDone {
            state.editAutoAssumeDailyDone = false
        }
    }
}

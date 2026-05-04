import ComposableArchitecture
import Foundation

struct TaskDetailBasicEditActionHandler {
    typealias State = TaskDetailFeature.State
    typealias Action = TaskDetailFeature.Action

    var draftMutationHandler: TaskDetailEditDraftMutationHandler

    func editRoutineNameChanged(_ name: String, state: inout State) -> Effect<Action> {
        draftMutationHandler.setName(name, state: &state)
        return .none
    }

    func editRoutineEmojiChanged(_ emoji: String, state: inout State) -> Effect<Action> {
        draftMutationHandler.setEmoji(emoji, state: &state)
        return .none
    }

    func editRoutineNotesChanged(_ notes: String, state: inout State) -> Effect<Action> {
        draftMutationHandler.setNotes(notes, state: &state)
        return .none
    }

    func editRoutineLinkChanged(_ link: String, state: inout State) -> Effect<Action> {
        draftMutationHandler.setLink(link, state: &state)
        return .none
    }

    func editPriorityChanged(_ priority: RoutineTaskPriority, state: inout State) -> Effect<Action> {
        draftMutationHandler.setPriority(priority, state: &state)
        return .none
    }

    func editImportanceChanged(_ importance: RoutineTaskImportance, state: inout State) -> Effect<Action> {
        draftMutationHandler.setImportance(importance, state: &state)
        return .none
    }

    func editUrgencyChanged(_ urgency: RoutineTaskUrgency, state: inout State) -> Effect<Action> {
        draftMutationHandler.setUrgency(urgency, state: &state)
        return .none
    }

    func editPressureChanged(_ pressure: RoutineTaskPressure, state: inout State) -> Effect<Action> {
        draftMutationHandler.setPressure(pressure, state: &state)
        return .none
    }

    func editImagePicked(_ data: Data?, state: inout State) -> Effect<Action> {
        draftMutationHandler.setImage(data, state: &state)
        return .none
    }

    func editRemoveImageTapped(state: inout State) -> Effect<Action> {
        draftMutationHandler.removeImage(state: &state)
        return .none
    }

    func editAttachmentPicked(
        data: Data,
        fileName: String,
        state: inout State
    ) -> Effect<Action> {
        draftMutationHandler.addAttachment(data: data, fileName: fileName, state: &state)
        return .none
    }

    func editRemoveAttachment(_ id: UUID, state: inout State) -> Effect<Action> {
        draftMutationHandler.removeAttachment(id, state: &state)
        return .none
    }

    func attachmentsLoaded(_ items: [AttachmentItem], state: inout State) -> Effect<Action> {
        state.taskAttachments = items
        return .none
    }

    func editEstimatedDurationChanged(_ value: Int?, state: inout State) -> Effect<Action> {
        draftMutationHandler.setEstimatedDuration(value, state: &state)
        return .none
    }

    func editActualDurationChanged(_ value: Int?, state: inout State) -> Effect<Action> {
        draftMutationHandler.setActualDuration(value, state: &state)
        return .none
    }

    func editStoryPointsChanged(_ value: Int?, state: inout State) -> Effect<Action> {
        draftMutationHandler.setStoryPoints(value, state: &state)
        return .none
    }

    func editFocusModeEnabledChanged(_ isEnabled: Bool, state: inout State) -> Effect<Action> {
        draftMutationHandler.setFocusModeEnabled(isEnabled, state: &state)
        return .none
    }

    func editColorChanged(_ color: RoutineTaskColor, state: inout State) -> Effect<Action> {
        draftMutationHandler.setColor(color, state: &state)
        return .none
    }
}

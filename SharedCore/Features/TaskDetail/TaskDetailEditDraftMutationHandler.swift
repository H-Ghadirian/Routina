import Foundation

struct TaskDetailEditDraftMutationHandler {
    let matrixPriority: (RoutineTaskImportance, RoutineTaskUrgency) -> RoutineTaskPriority
    let refreshTaskView: (inout TaskDetailFeature.State) -> Void

    func setName(_ name: String, state: inout TaskDetailFeature.State) {
        state.editRoutineName = name
    }

    func setEmoji(_ emoji: String, state: inout TaskDetailFeature.State) {
        state.editRoutineEmoji = RoutineTask.sanitizedEmoji(emoji, fallback: state.editRoutineEmoji)
    }

    func setNotes(_ notes: String, state: inout TaskDetailFeature.State) {
        state.editRoutineNotes = notes
    }

    func setLink(_ link: String, state: inout TaskDetailFeature.State) {
        state.editRoutineLink = link
    }

    func setPriority(_ priority: RoutineTaskPriority, state: inout TaskDetailFeature.State) {
        state.editPriority = priority
    }

    func setImportance(_ importance: RoutineTaskImportance, state: inout TaskDetailFeature.State) {
        state.editImportance = importance
        state.editPriority = matrixPriority(importance, state.editUrgency)
    }

    func setUrgency(_ urgency: RoutineTaskUrgency, state: inout TaskDetailFeature.State) {
        state.editUrgency = urgency
        state.editPriority = matrixPriority(state.editImportance, urgency)
    }

    func setPressure(_ pressure: RoutineTaskPressure, state: inout TaskDetailFeature.State) {
        state.editPressure = pressure
    }

    func setImage(_ data: Data?, state: inout TaskDetailFeature.State) {
        state.editImageData = data.flatMap(TaskImageProcessor.compressedImageData(from:))
    }

    func removeImage(state: inout TaskDetailFeature.State) {
        state.editImageData = nil
    }

    func addAttachment(
        data: Data,
        fileName: String,
        state: inout TaskDetailFeature.State
    ) {
        state.editAttachments.append(AttachmentItem(fileName: fileName, data: data))
    }

    func removeAttachment(_ id: UUID, state: inout TaskDetailFeature.State) {
        state.editAttachments.removeAll { $0.id == id }
    }

    func setTagDraft(_ value: String, state: inout TaskDetailFeature.State) {
        state.editTagDraft = value
    }

    func setGoalDraft(_ value: String, state: inout TaskDetailFeature.State) {
        state.editGoalDraft = value
    }

    func addTag(state: inout TaskDetailFeature.State) {
        state.editRoutineTags = RoutineTag.appending(state.editTagDraft, to: state.editRoutineTags)
        state.editTagDraft = ""
    }

    func addGoal(state: inout TaskDetailFeature.State) {
        state.editRoutineGoals = RoutineGoalSummary.appending(
            state.editGoalDraft,
            availableGoals: state.availableGoals,
            to: state.editRoutineGoals
        )
        state.editGoalDraft = ""
    }

    func removeTag(_ tag: String, state: inout TaskDetailFeature.State) {
        state.editRoutineTags = RoutineTag.removing(tag, from: state.editRoutineTags)
    }

    func removeGoal(_ goalID: UUID, state: inout TaskDetailFeature.State) {
        state.editRoutineGoals = RoutineGoalSummary.removing(goalID, from: state.editRoutineGoals)
    }

    func addRelationship(
        taskID: UUID,
        kind: RoutineTaskRelationshipKind,
        state: inout TaskDetailFeature.State
    ) {
        state.editRelationships = RoutineTaskRelationship.sanitized(
            state.editRelationships + [RoutineTaskRelationship(targetTaskID: taskID, kind: kind)],
            ownerID: state.task.id
        )
    }

    func removeRelationship(_ taskID: UUID, state: inout TaskDetailFeature.State) {
        state.editRelationships.removeAll { $0.targetTaskID == taskID }
    }

    func renameTag(
        oldName: String,
        newName: String,
        state: inout TaskDetailFeature.State
    ) {
        state.availableTags = RoutineTag.replacing(oldName, with: newName, in: state.availableTags)
        if RoutineTag.contains(oldName, in: state.editRoutineTags) {
            state.editRoutineTags = RoutineTag.replacing(oldName, with: newName, in: state.editRoutineTags)
        }
        if RoutineTag.contains(oldName, in: state.task.tags) {
            state.task.tags = RoutineTag.replacing(oldName, with: newName, in: state.task.tags)
            refreshTaskView(&state)
        }
    }

    func deleteTag(_ tag: String, state: inout TaskDetailFeature.State) {
        state.availableTags = RoutineTag.removing(tag, from: state.availableTags)
        state.editRoutineTags = RoutineTag.removing(tag, from: state.editRoutineTags)
        if RoutineTag.contains(tag, in: state.task.tags) {
            state.task.tags = RoutineTag.removing(tag, from: state.task.tags)
            refreshTaskView(&state)
        }
    }

    func setSelectedPlace(_ placeID: UUID?, state: inout TaskDetailFeature.State) {
        state.editSelectedPlaceID = placeID
    }

    func toggleTagSelection(_ tag: String, state: inout TaskDetailFeature.State) {
        if RoutineTag.contains(tag, in: state.editRoutineTags) {
            state.editRoutineTags = RoutineTag.removing(tag, from: state.editRoutineTags)
        } else {
            state.editRoutineTags = RoutineTag.appending(tag, to: state.editRoutineTags)
        }
    }

    func toggleGoalSelection(
        _ goal: RoutineGoalSummary,
        state: inout TaskDetailFeature.State
    ) {
        state.editRoutineGoals = RoutineGoalSummary.toggling(goal, in: state.editRoutineGoals)
    }

    func setEstimatedDuration(_ value: Int?, state: inout TaskDetailFeature.State) {
        state.editEstimatedDurationMinutes = RoutineTask.sanitizedEstimatedDurationMinutes(value)
    }

    func setActualDuration(_ value: Int?, state: inout TaskDetailFeature.State) {
        state.editActualDurationMinutes = RoutineTask.sanitizedActualDurationMinutes(value)
    }

    func setStoryPoints(_ value: Int?, state: inout TaskDetailFeature.State) {
        state.editStoryPoints = RoutineTask.sanitizedStoryPoints(value)
    }

    func setFocusModeEnabled(_ isEnabled: Bool, state: inout TaskDetailFeature.State) {
        state.editFocusModeEnabled = isEnabled
    }

    func setColor(_ color: RoutineTaskColor, state: inout TaskDetailFeature.State) {
        state.editColor = color
    }
}

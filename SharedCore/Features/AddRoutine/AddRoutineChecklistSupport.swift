import Foundation

enum AddRoutineChecklistEditor {
    static func setStepDraft(
        _ value: String,
        checklist: inout AddRoutineChecklistState
    ) {
        checklist.stepDraft = value
    }

    static func addStep(
        checklist: inout AddRoutineChecklistState
    ) {
        checklist.routineSteps = AddRoutineDraftFinalizer.appendingStep(
            from: checklist.stepDraft,
            to: checklist.routineSteps
        )
        checklist.stepDraft = ""
    }

    static func removeStep(
        _ stepID: UUID,
        checklist: inout AddRoutineChecklistState
    ) {
        checklist.routineSteps.removeAll { $0.id == stepID }
    }

    static func moveStep(
        _ stepID: UUID,
        by offset: Int,
        checklist: inout AddRoutineChecklistState
    ) {
        guard let index = checklist.routineSteps.firstIndex(where: { $0.id == stepID }) else {
            return
        }

        let targetIndex = index + offset
        guard checklist.routineSteps.indices.contains(targetIndex) else { return }

        let step = checklist.routineSteps.remove(at: index)
        checklist.routineSteps.insert(step, at: targetIndex)
    }

    static func setChecklistItemDraftTitle(
        _ value: String,
        checklist: inout AddRoutineChecklistState
    ) {
        checklist.checklistItemDraftTitle = value
    }

    static func setChecklistItemDraftInterval(
        _ value: Int,
        checklist: inout AddRoutineChecklistState
    ) {
        checklist.checklistItemDraftInterval = RoutineChecklistItem.clampedIntervalDays(value)
    }

    static func addChecklistItem(
        createdAt: Date,
        checklist: inout AddRoutineChecklistState
    ) {
        checklist.routineChecklistItems = AddRoutineDraftFinalizer.appendingChecklistItem(
            from: checklist.checklistItemDraftTitle,
            intervalDays: checklist.checklistItemDraftInterval,
            createdAt: createdAt,
            to: checklist.routineChecklistItems
        )
        checklist.checklistItemDraftTitle = ""
        checklist.checklistItemDraftInterval = 3
    }

    static func removeChecklistItem(
        _ itemID: UUID,
        checklist: inout AddRoutineChecklistState
    ) {
        checklist.routineChecklistItems.removeAll { $0.id == itemID }
    }
}

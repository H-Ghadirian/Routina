import ComposableArchitecture
import Foundation

extension TaskDetailFeature {
    func syncEditFormFromTask(_ state: inout State) {
        state.editRoutineName = state.task.name ?? ""
        state.editRoutineEmoji = state.task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨"
        state.editRoutineNotes = state.task.notes ?? ""
        state.editRoutineLink = state.task.link ?? ""
        state.editDeadline = state.task.deadline
        if state.task.derivedPriorityFromMatrix == state.task.priority || state.task.priority == .none {
            state.editImportance = state.task.importance
            state.editUrgency = state.task.urgency
        } else {
            let fallbackPosition = state.task.priority.defaultMatrixPosition
            state.editImportance = fallbackPosition.importance
            state.editUrgency = fallbackPosition.urgency
        }
        state.editPriority = state.task.priority
        state.editImageData = state.task.imageData
        state.editAttachments = state.taskAttachments
        state.editRoutineTags = state.task.tags
        state.editRelationships = state.task.relationships
        state.editTagDraft = ""
        state.editScheduleMode = state.task.scheduleMode
        state.editRoutineSteps = state.task.steps
        state.editStepDraft = ""
        state.editRoutineChecklistItems = state.task.checklistItems
        state.editChecklistItemDraftTitle = ""
        state.editChecklistItemDraftInterval = 3
        state.editSelectedPlaceID = state.task.placeID
        state.editColor = state.task.color

        let recurrenceRule = state.task.recurrenceRule
        state.editRecurrenceKind = recurrenceRule.kind
        state.editRecurrenceHasExplicitTime = recurrenceRule.usesExplicitTimeOfDay
        state.editRecurrenceTimeOfDay = recurrenceRule.timeOfDay ?? .defaultValue
        state.editRecurrenceWeekday = recurrenceRule.weekday ?? Calendar.current.component(.weekday, from: now)
        state.editRecurrenceDayOfMonth = recurrenceRule.dayOfMonth ?? Calendar.current.component(.day, from: now)
        state.editAutoAssumeDailyDone = state.task.autoAssumeDailyDone
        state.editEstimatedDurationMinutes = state.task.estimatedDurationMinutes
        state.editStoryPoints = state.task.storyPoints

        let interval = max(recurrenceRule.interval, 1)
        if recurrenceRule.kind == .intervalDays {
            if interval % 30 == 0 {
                state.editFrequency = .month
                state.editFrequencyValue = max(interval / 30, 1)
            } else if interval % 7 == 0 {
                state.editFrequency = .week
                state.editFrequencyValue = max(interval / 7, 1)
            } else {
                state.editFrequency = .day
                state.editFrequencyValue = interval
            }
        } else {
            state.editFrequency = .day
            state.editFrequencyValue = 1
        }
    }
}

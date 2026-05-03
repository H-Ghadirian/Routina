import Foundation

struct TaskDetailEditChangeRequest {
    let name: String
    let emoji: String
    let notes: String
    let link: String
    let estimatedDurationMinutes: Int?
    let storyPoints: Int?
    let deadline: Date?
    let reminderAt: Date?
    let priority: RoutineTaskPriority
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let color: RoutineTaskColor
    let imageData: Data?
    let editAttachments: [AttachmentItem]
    let taskAttachments: [AttachmentItem]
    let selectedPlaceID: UUID?
    let tags: [String]
    let relationships: [RoutineTaskRelationship]
    let tagDraft: String
    let scheduleMode: RoutineScheduleMode
    let steps: [RoutineStep]
    let stepDraft: String
    let checklistItems: [RoutineChecklistItem]
    let checklistItemDraftTitle: String
    let checklistItemDraftInterval: Int
    let frequency: TaskDetailFeature.EditFrequency
    let frequencyValue: Int
    let recurrenceKind: RoutineRecurrenceRule.Kind
    let recurrenceHasExplicitTime: Bool
    let recurrenceTimeOfDay: RoutineTimeOfDay
    let recurrenceWeekday: Int
    let recurrenceDayOfMonth: Int
    let autoAssumeDailyDone: Bool
    let focusModeEnabled: Bool
    let pressure: RoutineTaskPressure
    let task: RoutineTask

    init(state: TaskDetailFeature.State) {
        self.name = state.editRoutineName
        self.emoji = state.editRoutineEmoji
        self.notes = state.editRoutineNotes
        self.link = state.editRoutineLink
        self.estimatedDurationMinutes = state.editEstimatedDurationMinutes
        self.storyPoints = state.editStoryPoints
        self.deadline = state.editDeadline
        self.reminderAt = state.editReminderAt
        self.priority = state.editPriority
        self.importance = state.editImportance
        self.urgency = state.editUrgency
        self.color = state.editColor
        self.imageData = state.editImageData
        self.editAttachments = state.editAttachments
        self.taskAttachments = state.taskAttachments
        self.selectedPlaceID = state.editSelectedPlaceID
        self.tags = state.editRoutineTags
        self.relationships = state.editRelationships
        self.tagDraft = state.editTagDraft
        self.scheduleMode = state.editScheduleMode
        self.steps = state.editRoutineSteps
        self.stepDraft = state.editStepDraft
        self.checklistItems = state.editRoutineChecklistItems
        self.checklistItemDraftTitle = state.editChecklistItemDraftTitle
        self.checklistItemDraftInterval = state.editChecklistItemDraftInterval
        self.frequency = state.editFrequency
        self.frequencyValue = state.editFrequencyValue
        self.recurrenceKind = state.editRecurrenceKind
        self.recurrenceHasExplicitTime = state.editRecurrenceHasExplicitTime
        self.recurrenceTimeOfDay = state.editRecurrenceTimeOfDay
        self.recurrenceWeekday = state.editRecurrenceWeekday
        self.recurrenceDayOfMonth = state.editRecurrenceDayOfMonth
        self.autoAssumeDailyDone = state.editAutoAssumeDailyDone
        self.focusModeEnabled = state.editFocusModeEnabled
        self.pressure = state.editPressure
        self.task = state.task
    }
}

enum TaskDetailEditChangeDetector {
    static func canSave(_ request: TaskDetailEditChangeRequest) -> Bool {
        let trimmedName = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        let task = request.task
        let currentName = (task.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let currentEmoji = CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "✨"
        let currentNotes = CalendarTaskImportSupport.displayNotes(from: task.notes) ?? ""
        let currentLink = task.link ?? ""
        let currentTags = RoutineTag.deduplicated(task.tags)
        let currentRelationships = RoutineTaskRelationship.sanitized(task.relationships, ownerID: task.id)
        let currentDeadline = task.scheduleMode == .oneOff ? task.deadline : nil
        let candidateTags = RoutineTag.appending(request.tagDraft, to: request.tags)
        let candidateRelationships = RoutineTaskRelationship.sanitized(request.relationships, ownerID: task.id)
        let currentSteps = RoutineStep.sanitized(task.steps)
        let candidateSteps = RoutineStep.normalizedTitle(request.stepDraft).map { title in
            request.steps + [RoutineStep(title: title)]
        } ?? request.steps
        let currentChecklistItems = RoutineChecklistItem.sanitized(task.checklistItems)
        let candidateChecklistItems = RoutineChecklistItem.normalizedTitle(request.checklistItemDraftTitle).map { title in
            request.checklistItems + [
                RoutineChecklistItem(title: title, intervalDays: request.checklistItemDraftInterval)
            ]
        } ?? request.checklistItems
        let sanitizedCandidateChecklistItems = RoutineChecklistItem.sanitized(candidateChecklistItems)

        guard request.scheduleMode == .fixedInterval
            || request.scheduleMode == .softInterval
            || request.scheduleMode == .oneOff
            || !sanitizedCandidateChecklistItems.isEmpty
        else {
            return false
        }

        return trimmedName != currentName
            || request.emoji != currentEmoji
            || request.notes != currentNotes
            || request.link != currentLink
            || request.estimatedDurationMinutes != task.estimatedDurationMinutes
            || request.storyPoints != task.storyPoints
            || request.deadline != currentDeadline
            || request.reminderAt != task.reminderAt
            || request.priority != task.priority
            || request.importance != task.importance
            || request.urgency != task.urgency
            || request.color != task.color
            || request.imageData != task.imageData
            || request.editAttachments != request.taskAttachments
            || request.selectedPlaceID != task.placeID
            || candidateTags != currentTags
            || candidateRelationships != currentRelationships
            || request.scheduleMode != task.scheduleMode
            || RoutineStep.sanitized(candidateSteps) != currentSteps
            || sanitizedCandidateChecklistItems != currentChecklistItems
            || recurrenceRule(for: request) != task.recurrenceRule
            || request.autoAssumeDailyDone != task.autoAssumeDailyDone
            || request.focusModeEnabled != task.focusModeEnabled
            || request.pressure != task.pressure
    }

    private static func recurrenceRule(for request: TaskDetailEditChangeRequest) -> RoutineRecurrenceRule {
        switch request.recurrenceKind {
        case .intervalDays:
            return .interval(days: request.frequencyValue * request.frequency.daysMultiplier)
        case .dailyTime:
            return .daily(at: request.recurrenceTimeOfDay)
        case .weekly:
            return .weekly(
                on: request.recurrenceWeekday,
                at: request.recurrenceHasExplicitTime ? request.recurrenceTimeOfDay : nil
            )
        case .monthlyDay:
            return .monthly(
                on: request.recurrenceDayOfMonth,
                at: request.recurrenceHasExplicitTime ? request.recurrenceTimeOfDay : nil
            )
        }
    }
}

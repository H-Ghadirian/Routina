import Foundation

enum AddRoutinePriorityMatrix {
    static func priority(
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency
    ) -> RoutineTaskPriority {
        let score = importance.sortOrder + urgency.sortOrder
        switch score {
        case ..<4:
            return .low
        case 4...5:
            return .medium
        case 6...7:
            return .high
        default:
            return .urgent
        }
    }
}

struct AddRoutineDraftFinalizer {
    let now: Date

    func apply(to state: inout AddRoutineFeature.State) {
        AddRoutineOrganizationEditor.commitDraftTag(organization: &state.organization)
        state.checklist.routineSteps = Self.appendingStep(
            from: state.checklist.stepDraft,
            to: state.checklist.routineSteps
        )
        state.checklist.stepDraft = ""
        state.checklist.routineChecklistItems = Self.appendingChecklistItem(
            from: state.checklist.checklistItemDraftTitle,
            intervalDays: state.checklist.checklistItemDraftInterval,
            createdAt: now,
            to: state.checklist.routineChecklistItems
        )
        state.checklist.checklistItemDraftTitle = ""
        state.checklist.checklistItemDraftInterval = 3
    }

    static func appendingStep(
        from draft: String,
        to currentSteps: [RoutineStep]
    ) -> [RoutineStep] {
        guard let title = RoutineStep.normalizedTitle(draft) else { return currentSteps }
        return currentSteps + [RoutineStep(title: title)]
    }

    static func appendingChecklistItem(
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
}

struct AddRoutineSaveRequest {
    let name: String
    let frequencyInDays: Int
    let recurrenceRule: RoutineRecurrenceRule
    let emoji: String
    let notes: String?
    let link: String?
    let deadline: Date?
    let priority: RoutineTaskPriority
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let imageData: Data?
    let selectedPlaceID: UUID?
    let tags: [String]
    let relationships: [RoutineTaskRelationship]
    let steps: [RoutineStep]
    let scheduleMode: RoutineScheduleMode
    let checklistItems: [RoutineChecklistItem]
    let attachments: [AttachmentItem]
    let color: RoutineTaskColor

    init?(state: AddRoutineFeature.State) {
        guard !state.isSaveDisabled else { return nil }

        let basics = state.basics
        let organization = state.organization
        let schedule = state.schedule
        let checklist = state.checklist

        let frequencyInDays = schedule.scheduleMode == .oneOff
            ? 1
            : schedule.frequencyValue * schedule.frequency.daysMultiplier

        self.name = state.trimmedRoutineName
        self.frequencyInDays = frequencyInDays
        self.recurrenceRule = Self.selectedRecurrenceRule(
            schedule: schedule,
            fallbackInterval: frequencyInDays
        )
        self.emoji = basics.routineEmoji
        self.notes = RoutineTask.sanitizedNotes(basics.routineNotes)
        self.link = RoutineTask.sanitizedLink(basics.routineLink)
        self.deadline = schedule.scheduleMode.taskType == .todo ? basics.deadline : nil
        self.priority = AddRoutinePriorityMatrix.priority(
            importance: basics.importance,
            urgency: basics.urgency
        )
        self.importance = basics.importance
        self.urgency = basics.urgency
        self.imageData = basics.imageData
        self.selectedPlaceID = basics.selectedPlaceID
        self.tags = organization.routineTags
        self.relationships = organization.relationships
        self.steps = (schedule.scheduleMode == .fixedInterval || schedule.scheduleMode == .oneOff)
            ? RoutineStep.sanitized(checklist.routineSteps)
            : []
        self.scheduleMode = schedule.scheduleMode
        self.checklistItems = (schedule.scheduleMode == .fixedInterval || schedule.scheduleMode == .oneOff)
            ? []
            : RoutineChecklistItem.sanitized(checklist.routineChecklistItems)
        self.attachments = basics.attachments
        self.color = basics.routineColor
    }

    private static func selectedRecurrenceRule(
        schedule: AddRoutineScheduleState,
        fallbackInterval: Int
    ) -> RoutineRecurrenceRule {
        guard schedule.scheduleMode != .oneOff else {
            return .interval(days: 1)
        }

        guard schedule.scheduleMode != .derivedFromChecklist else {
            return .interval(days: max(fallbackInterval, 1))
        }

        switch schedule.recurrenceKind {
        case .intervalDays:
            return .interval(days: max(fallbackInterval, 1))
        case .dailyTime:
            return .daily(at: schedule.recurrenceTimeOfDay)
        case .weekly:
            return .weekly(on: schedule.recurrenceWeekday)
        case .monthlyDay:
            return .monthly(on: schedule.recurrenceDayOfMonth)
        }
    }
}

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
        AddRoutineOrganizationEditor.commitDraftGoal(organization: &state.organization)
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

struct AddRoutineSaveRequest: Equatable {
    let name: String
    let frequencyInDays: Int
    let recurrenceRule: RoutineRecurrenceRule
    let emoji: String
    let notes: String?
    let link: String?
    let links: [String]
    let deadline: Date?
    let isAllDay: Bool
    let availabilityStartDate: Date?
    let availabilityEndDate: Date?
    let reminderAt: Date?
    let priority: RoutineTaskPriority
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let pressure: RoutineTaskPressure
    let imageData: Data?
    let voiceNote: RoutineVoiceNote?
    let selectedPlaceID: UUID?
    let selectedPlaceIDs: [UUID]
    let tags: [String]
    let goals: [RoutineGoalSummary]
    let eventIDs: [UUID]
    let relationships: [RoutineTaskRelationship]
    let steps: [RoutineStep]
    let scheduleMode: RoutineScheduleMode
    let checklistItems: [RoutineChecklistItem]
    let attachments: [AttachmentItem]
    let color: RoutineTaskColor
    let autoAssumeDailyDone: Bool
    let estimatedDurationMinutes: Int?
    let storyPoints: Int?
    let focusModeEnabled: Bool

    init(
        name: String,
        frequencyInDays: Int,
        recurrenceRule: RoutineRecurrenceRule,
        emoji: String,
        notes: String? = nil,
        link: String? = nil,
        links: [String] = [],
        deadline: Date? = nil,
        isAllDay: Bool = false,
        availabilityStartDate: Date? = nil,
        availabilityEndDate: Date? = nil,
        reminderAt: Date? = nil,
        priority: RoutineTaskPriority,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure = .none,
        imageData: Data? = nil,
        voiceNote: RoutineVoiceNote? = nil,
        selectedPlaceID: UUID? = nil,
        selectedPlaceIDs: [UUID] = [],
        tags: [String] = [],
        goals: [RoutineGoalSummary] = [],
        eventIDs: [UUID] = [],
        relationships: [RoutineTaskRelationship] = [],
        steps: [RoutineStep] = [],
        scheduleMode: RoutineScheduleMode,
        checklistItems: [RoutineChecklistItem] = [],
        attachments: [AttachmentItem] = [],
        color: RoutineTaskColor,
        autoAssumeDailyDone: Bool = false,
        estimatedDurationMinutes: Int? = nil,
        storyPoints: Int? = nil,
        focusModeEnabled: Bool = false
    ) {
        self.name = name
        self.frequencyInDays = frequencyInDays
        self.recurrenceRule = recurrenceRule
        self.emoji = emoji
        self.notes = notes
        let sanitizedLinks = RoutineTask.sanitizedLinks(links.isEmpty ? link.map { [$0] } ?? [] : links)
        self.link = sanitizedLinks.first
        self.links = sanitizedLinks
        self.deadline = deadline
        self.isAllDay = isAllDay
        self.availabilityStartDate = availabilityStartDate
        self.availabilityEndDate = availabilityEndDate
        self.reminderAt = reminderAt
        self.priority = priority
        self.importance = importance
        self.urgency = urgency
        self.pressure = pressure
        self.imageData = imageData
        self.voiceNote = voiceNote
        let resolvedPlaceIDs = RoutinePlaceIDStorage.sanitized(
            selectedPlaceIDs.isEmpty ? selectedPlaceID.map { [$0] } ?? [] : selectedPlaceIDs
        )
        self.selectedPlaceID = resolvedPlaceIDs.first
        self.selectedPlaceIDs = resolvedPlaceIDs
        self.tags = RoutineTag.deduplicated(tags)
        self.goals = RoutineGoalSummary.sanitized(goals)
        self.eventIDs = RoutineEventIDStorage.sanitized(eventIDs)
        self.relationships = relationships
        self.steps = steps
        self.scheduleMode = scheduleMode
        self.checklistItems = checklistItems
        self.attachments = attachments
        self.color = color
        self.autoAssumeDailyDone = autoAssumeDailyDone
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.storyPoints = storyPoints
        self.focusModeEnabled = focusModeEnabled
    }

    init?(state: AddRoutineFeature.State, calendar: Calendar = .current) {
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
            fallbackInterval: frequencyInDays,
            isAllDay: basics.isAllDay
        )
        self.emoji = basics.routineEmoji
        self.notes = RoutineTask.sanitizedNotes(basics.routineNotes)
        let sanitizedLinks = RoutineTask.sanitizedLinks(fromEditorText: basics.routineLink)
        self.link = sanitizedLinks.first
        self.links = sanitizedLinks
        self.deadline = schedule.scheduleMode.taskType == .todo ? basics.deadline : nil
        self.isAllDay = basics.isAllDay
        let availabilityDateBounds = RoutineTask.normalizedAvailabilityDateBounds(
            startDate: basics.availabilityStartDate,
            endDate: basics.availabilityEndDate,
            calendar: calendar
        )
        self.availabilityStartDate = schedule.scheduleMode == .oneOff ? availabilityDateBounds.startDate : nil
        self.availabilityEndDate = schedule.scheduleMode == .oneOff ? availabilityDateBounds.endDate : nil
        self.reminderAt = schedule.scheduleMode == .oneOff ? basics.reminderAt : nil
        self.priority = AddRoutinePriorityMatrix.priority(
            importance: basics.importance,
            urgency: basics.urgency
        )
        self.importance = basics.importance
        self.urgency = basics.urgency
        self.pressure = basics.pressure
        self.imageData = basics.imageData
        self.voiceNote = basics.voiceNote
        self.selectedPlaceIDs = RoutinePlaceIDStorage.sanitized(
            basics.selectedPlaceIDs.isEmpty ? basics.selectedPlaceID.map { [$0] } ?? [] : basics.selectedPlaceIDs
        )
        self.selectedPlaceID = selectedPlaceIDs.first
        self.tags = RoutineTag.deduplicated(organization.routineTags)
        self.goals = organization.routineGoals
        self.eventIDs = RoutineEventIDStorage.sanitized(organization.eventIDs)
        self.relationships = organization.relationships
        self.steps = (schedule.scheduleMode.isStandardRoutineMode || schedule.scheduleMode == .oneOff)
            ? RoutineStep.sanitized(checklist.routineSteps)
            : []
        self.scheduleMode = schedule.scheduleMode
        self.checklistItems = RoutineChecklistItem.sanitized(checklist.routineChecklistItems)
        self.attachments = basics.attachments
        self.color = basics.routineColor
        self.estimatedDurationMinutes = RoutineTask.sanitizedEstimatedDurationMinutes(basics.estimatedDurationMinutes)
        self.storyPoints = RoutineTask.sanitizedStoryPoints(basics.storyPoints)
        self.focusModeEnabled = basics.focusModeEnabled
        self.autoAssumeDailyDone = schedule.autoAssumeDailyDone
            && RoutineAssumedCompletion.isEligible(
                scheduleMode: self.scheduleMode,
                recurrenceRule: self.recurrenceRule,
                hasSequentialSteps: !self.steps.isEmpty,
                hasChecklistItems: !self.checklistItems.isEmpty
            )
    }

    private static func selectedRecurrenceRule(
        schedule: AddRoutineScheduleState,
        fallbackInterval: Int,
        isAllDay: Bool
    ) -> RoutineRecurrenceRule {
        let usesAvailabilityTiming = !isAllDay
        let timeRange = usesAvailabilityTiming ? schedule.recurrenceTimeRange : nil

        guard schedule.scheduleMode != .oneOff else {
            return .interval(
                days: 1,
                at: usesAvailabilityTiming && schedule.recurrenceHasExplicitTime ? schedule.recurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        }

        guard !schedule.scheduleMode.isChecklistDrivenMode else {
            return .interval(days: max(fallbackInterval, 1))
        }

        switch schedule.recurrenceKind {
        case .intervalDays:
            return .interval(
                days: max(fallbackInterval, 1),
                at: usesAvailabilityTiming && schedule.recurrenceHasExplicitTime ? schedule.recurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        case .dailyTime:
            if let timeRange {
                return .daily(in: timeRange)
            }
            return RoutineRecurrenceRule(
                kind: .dailyTime,
                timeOfDay: usesAvailabilityTiming && schedule.recurrenceHasExplicitTime ? schedule.recurrenceTimeOfDay : nil
            )
        case .weekly:
            return .weekly(
                on: schedule.recurrenceWeekday,
                at: usesAvailabilityTiming && schedule.recurrenceHasExplicitTime ? schedule.recurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        case .monthlyDay:
            return .monthly(
                on: schedule.recurrenceDayOfMonth,
                at: usesAvailabilityTiming && schedule.recurrenceHasExplicitTime ? schedule.recurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        }
    }
}

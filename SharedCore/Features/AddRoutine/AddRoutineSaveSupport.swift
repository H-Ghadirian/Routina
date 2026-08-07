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
        let hadChecklistDraft = RoutineChecklistItem.normalizedTitle(
            state.checklist.checklistItemDraftTitle
        ) != nil

        AddRoutineOrganizationEditor.commitDraftTag(organization: &state.organization)
        AddRoutineOrganizationEditor.commitDraftGoal(organization: &state.organization)
        state.checklist.routineSteps = Self.appendingStep(
            from: state.checklist.stepDraft,
            to: state.checklist.routineSteps
        )
        state.checklist.stepDraft = ""
        state.checklist.routineChecklistItems = Self.appendingChecklistItem(
            from: state.checklist.checklistItemDraftTitle,
            intervalDays: state.schedule.scheduleMode.normalizedChecklistItemIntervalDays(
                state.checklist.checklistItemDraftInterval
            ),
            createdAt: now,
            to: state.checklist.routineChecklistItems
        )
        state.checklist.routineChecklistItems = RoutineChecklistItem.sanitized(
            state.checklist.routineChecklistItems,
            for: state.schedule.scheduleMode
        )
        state.checklist.checklistItemDraftTitle = ""
        if hadChecklistDraft {
            state.checklist.checklistItemDraftInterval = state.schedule.scheduleMode.storesChecklistItemIntervals ? 3 : 1
        }
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
    let customTaskSectionID: UUID?
    let frequencyInDays: Int
    let recurrenceRule: RoutineRecurrenceRule
    let emoji: String
    let taskDescription: String?
    let notes: String?
    let link: String?
    let links: [String]
    let linkItems: [RoutineTaskLink]
    let deadline: Date?
    let isAllDay: Bool
    let routineDurationMode: RoutineDurationMode
    let availabilityStartDate: Date?
    let availabilityEndDate: Date?
    let plannedDate: Date?
    let reminderAt: Date?
    let priority: RoutineTaskPriority
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let pressure: RoutineTaskPressure
    let thinkingNeeded: RoutineTaskThinkingNeeded
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
    let recurrenceTimeRangeRole: RoutineTimeRangeRole
    let attachments: [AttachmentItem]
    let color: RoutineTaskColor
    let autoAssumeDailyDone: Bool
    let hidesAssumedDoneCalendarBlock: Bool
    let autoAssumeDoneTimeOfDay: RoutineTimeOfDay?
    let estimatedDurationMinutes: Int?
    let actualDurationMinutes: Int?
    let storyPoints: Int?
    let focusModeEnabled: Bool
    let trackingCadenceEnabled: Bool
    let trackingNudgesEnabled: Bool

    init(
        name: String,
        customTaskSectionID: UUID? = nil,
        frequencyInDays: Int,
        recurrenceRule: RoutineRecurrenceRule,
        emoji: String,
        taskDescription: String? = nil,
        notes: String? = nil,
        link: String? = nil,
        links: [String] = [],
        linkItems: [RoutineTaskLink] = [],
        deadline: Date? = nil,
        isAllDay: Bool = false,
        routineDurationMode: RoutineDurationMode = .oneDay,
        availabilityStartDate: Date? = nil,
        availabilityEndDate: Date? = nil,
        plannedDate: Date? = nil,
        calendar: Calendar = .current,
        reminderAt: Date? = nil,
        priority: RoutineTaskPriority,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure = .none,
        thinkingNeeded: RoutineTaskThinkingNeeded = .none,
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
        recurrenceTimeRangeRole: RoutineTimeRangeRole = .availability,
        attachments: [AttachmentItem] = [],
        color: RoutineTaskColor,
        autoAssumeDailyDone: Bool = false,
        hidesAssumedDoneCalendarBlock: Bool = false,
        autoAssumeDoneTimeOfDay: RoutineTimeOfDay? = nil,
        estimatedDurationMinutes: Int? = nil,
        actualDurationMinutes: Int? = nil,
        storyPoints: Int? = nil,
        focusModeEnabled: Bool = false,
        trackingCadenceEnabled: Bool = true,
        trackingNudgesEnabled: Bool = true
    ) {
        self.name = name
        self.customTaskSectionID = customTaskSectionID
        self.frequencyInDays = frequencyInDays
        self.recurrenceRule = recurrenceRule
        self.emoji = emoji
        self.taskDescription = RoutineTask.sanitizedDescription(taskDescription)
        self.notes = notes
        let sanitizedLinkItems = RoutineTaskLinkStorage.sanitizedItems(linkItems.isEmpty
            ? (links.isEmpty ? link.map { [RoutineTaskLink(title: nil, url: $0)] } ?? [] : links.map { RoutineTaskLink(title: nil, url: $0) })
            : linkItems
        )
        self.link = sanitizedLinkItems.first?.url
        self.links = sanitizedLinkItems.map(\.url)
        self.linkItems = sanitizedLinkItems
        let sanitizedChecklistItems = RoutineChecklistItem.sanitized(checklistItems, for: scheduleMode)
        let availabilityDateBounds = RoutineTask.normalizedAvailabilityDateBounds(
            startDate: availabilityStartDate,
            endDate: availabilityEndDate,
            calendar: calendar
        )

        self.deadline = scheduleMode.taskType == .todo ? deadline : nil
        self.isAllDay = isAllDay
        self.routineDurationMode = scheduleMode.taskType == .todo ? .oneDay : routineDurationMode
        self.availabilityStartDate = scheduleMode.taskType == .todo ? availabilityDateBounds.startDate : nil
        self.availabilityEndDate = scheduleMode.taskType == .todo ? availabilityDateBounds.endDate : nil
        self.plannedDate = RoutineTaskPlanningSupport.supportsStoredPlanning(
                scheduleMode: scheduleMode,
                recurrenceRule: recurrenceRule,
                checklistItems: sanitizedChecklistItems,
                trackingCadenceEnabled: scheduleMode.taskType == .todo
                    ? true
                    : trackingCadenceEnabled
            )
            ? RoutineTask.effectivePlannedDate(
                plannedDate: plannedDate,
                scheduleMode: scheduleMode,
                availabilityStartDate: availabilityDateBounds.startDate,
                availabilityEndDate: availabilityDateBounds.endDate,
                calendar: calendar
            )
            : nil
        self.reminderAt = scheduleMode.taskType == .todo ? reminderAt : nil
        self.priority = priority
        self.importance = importance
        self.urgency = urgency
        self.pressure = pressure
        self.thinkingNeeded = thinkingNeeded
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
        self.steps = (scheduleMode.isStandardRoutineMode || scheduleMode == .oneOff || scheduleMode == .record)
            ? RoutineStep.sanitized(steps)
            : []
        self.scheduleMode = scheduleMode
        self.checklistItems = sanitizedChecklistItems
        self.recurrenceTimeRangeRole = recurrenceRule.timeRange == nil
            ? .availability
            : recurrenceTimeRangeRole
        self.attachments = attachments
        self.color = color
        self.trackingCadenceEnabled = scheduleMode.taskType == .todo ? true : trackingCadenceEnabled
        self.autoAssumeDailyDone = autoAssumeDailyDone
            && RoutineAssumedCompletion.isEligible(
                scheduleMode: scheduleMode,
                recurrenceRule: recurrenceRule,
                trackingCadenceEnabled: self.trackingCadenceEnabled,
                hasSequentialSteps: !self.steps.isEmpty,
                hasChecklistItems: !self.checklistItems.isEmpty
            )
        self.hidesAssumedDoneCalendarBlock = self.autoAssumeDailyDone
            && hidesAssumedDoneCalendarBlock
        self.autoAssumeDoneTimeOfDay = self.autoAssumeDailyDone ? autoAssumeDoneTimeOfDay : nil
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.actualDurationMinutes = scheduleMode.taskType == .record
            ? RoutineTask.sanitizedActualDurationMinutes(actualDurationMinutes)
            : nil
        self.storyPoints = storyPoints
        self.focusModeEnabled = focusModeEnabled
        self.trackingNudgesEnabled = scheduleMode.usesRoutineCadence
            ? self.trackingCadenceEnabled && trackingNudgesEnabled
            : true
    }

    init?(state: AddRoutineFeature.State, calendar: Calendar = .current) {
        guard !state.isSaveDisabled else { return nil }

        let basics = state.basics
        let organization = state.organization
        let schedule = state.schedule
        let checklist = state.checklist

        let trackingCadenceEnabled = schedule.scheduleMode.taskType == .todo
            ? true
            : basics.trackingCadenceEnabled
        let recurrenceDraft = state.recurrenceDraftForPersistence(calendar: calendar)
        guard let recurrenceRule = recurrenceDraft.resolvedRecurrenceRule(calendar: calendar) else {
            return nil
        }
        let frequencyInDays: Int
        if schedule.recurrenceDraftIsAuthoritative {
            frequencyInDays = recurrenceDraft.cadence == .none
                ? 1
                : recurrenceRule.approximateIntervalDays
        } else if !schedule.scheduleMode.usesRoutineCadence || !trackingCadenceEnabled {
            frequencyInDays = 1
        } else if schedule.recurrenceEditorMode == .advanced {
            frequencyInDays = schedule.advancedRecurrenceRule.approximateIntervalDays
        } else {
            frequencyInDays = TaskFormRecurrenceConstraints.effectiveIntervalDays(
                value: schedule.frequencyValue,
                unit: schedule.frequency,
                scheduleMode: schedule.scheduleMode,
                routineDurationMode: basics.routineDurationMode,
                recurrenceKind: schedule.recurrenceKind
            )
        }

        self.name = state.trimmedRoutineName
        self.customTaskSectionID = organization.customTaskSectionID
        self.frequencyInDays = frequencyInDays
        self.recurrenceRule = recurrenceRule
        self.emoji = basics.routineEmoji
        self.taskDescription = RoutineTask.sanitizedDescription(basics.taskDescription)
        self.notes = RoutineTask.sanitizedNotes(basics.routineNotes)
        let sanitizedLinks = RoutineTask.sanitizedLinkItems(fromEditorText: basics.routineLink)
        self.link = sanitizedLinks.first?.url
        self.links = sanitizedLinks.map(\.url)
        self.linkItems = sanitizedLinks
        self.deadline = schedule.scheduleMode.taskType == .todo ? basics.deadline : nil
        self.isAllDay = basics.isAllDay
        self.routineDurationMode = schedule.scheduleMode.taskType == .todo ? .oneDay : basics.routineDurationMode
        let sanitizedChecklistItems = RoutineChecklistItem.sanitized(
            checklist.routineChecklistItems,
            for: schedule.scheduleMode
        )
        guard !schedule.scheduleMode.isRoutineModeRequiringChecklistItems
            || !sanitizedChecklistItems.isEmpty
        else { return nil }
        let availabilityDateBounds = RoutineTask.normalizedAvailabilityDateBounds(
            startDate: basics.availabilityStartDate,
            endDate: basics.availabilityEndDate,
            calendar: calendar
        )
        self.availabilityStartDate = schedule.scheduleMode.taskType == .todo ? availabilityDateBounds.startDate : nil
        self.availabilityEndDate = schedule.scheduleMode.taskType == .todo ? availabilityDateBounds.endDate : nil
        self.plannedDate = RoutineTaskPlanningSupport.supportsStoredPlanning(
                scheduleMode: schedule.scheduleMode,
                recurrenceRule: self.recurrenceRule,
                checklistItems: sanitizedChecklistItems,
                trackingCadenceEnabled: trackingCadenceEnabled
            )
            ? RoutineTask.effectivePlannedDate(
                plannedDate: basics.plannedDate,
                scheduleMode: schedule.scheduleMode,
                availabilityStartDate: availabilityDateBounds.startDate,
                availabilityEndDate: availabilityDateBounds.endDate,
                calendar: calendar
            )
            : nil
        self.reminderAt = schedule.scheduleMode.taskType == .todo ? basics.reminderAt : nil
        self.priority = AddRoutinePriorityMatrix.priority(
            importance: basics.importance,
            urgency: basics.urgency
        )
        self.importance = basics.importance
        self.urgency = basics.urgency
        self.pressure = basics.pressure
        self.thinkingNeeded = basics.thinkingNeeded
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
        self.steps = (schedule.scheduleMode.isStandardRoutineMode || schedule.scheduleMode == .oneOff || schedule.scheduleMode == .record)
            ? RoutineStep.sanitized(checklist.routineSteps)
            : []
        self.scheduleMode = schedule.scheduleMode
        self.checklistItems = sanitizedChecklistItems
        self.recurrenceTimeRangeRole = self.recurrenceRule.timeRange == nil
            ? .availability
            : recurrenceDraft.timeRangeRole
        self.attachments = basics.attachments
        self.color = basics.routineColor
        self.estimatedDurationMinutes = RoutineTask.sanitizedEstimatedDurationMinutes(basics.estimatedDurationMinutes)
        self.actualDurationMinutes = schedule.scheduleMode.taskType == .record
            ? RoutineTask.sanitizedActualDurationMinutes(basics.actualDurationMinutes)
            : nil
        self.storyPoints = RoutineTask.sanitizedStoryPoints(basics.storyPoints)
        self.focusModeEnabled = basics.focusModeEnabled
        self.trackingCadenceEnabled = trackingCadenceEnabled
        self.trackingNudgesEnabled = schedule.scheduleMode.usesRoutineCadence
            ? trackingCadenceEnabled && basics.trackingNudgesEnabled
            : true
        self.autoAssumeDailyDone = schedule.autoAssumeDailyDone
            && RoutineAssumedCompletion.isEligible(
                scheduleMode: self.scheduleMode,
                recurrenceRule: self.recurrenceRule,
                trackingCadenceEnabled: trackingCadenceEnabled,
                hasSequentialSteps: !self.steps.isEmpty,
                hasChecklistItems: !self.checklistItems.isEmpty
            )
        self.hidesAssumedDoneCalendarBlock = self.autoAssumeDailyDone
            && schedule.hidesAssumedDoneCalendarBlock
        self.autoAssumeDoneTimeOfDay = autoAssumeDailyDone ? schedule.autoAssumeDoneTimeOfDay : nil
    }

}

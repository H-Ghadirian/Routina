import Foundation

enum CreationDraftPersistence {
    static func load<T: Decodable>(
        _ type: T.Type,
        for kind: CreationDraftKind,
        client: CreationDraftClient = .live
    ) -> T? {
        guard let rawValue = client.load(kind),
              let data = rawValue.data(using: .utf8)
        else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(
        _ value: T,
        for kind: CreationDraftKind,
        client: CreationDraftClient = .live
    ) {
        guard let data = try? JSONEncoder().encode(value),
              let rawValue = String(data: data, encoding: .utf8)
        else {
            return
        }

        client.save(kind, rawValue)
    }

    static func clear(
        _ kind: CreationDraftKind,
        client: CreationDraftClient = .live
    ) {
        client.clear(kind)
    }
}

struct AddRoutineDraftSnapshot: Codable, Equatable {
    var routineName = ""
    var routineEmoji = "✨"
    var routineNotes = ""
    var routineLink = ""
    var deadline: Date?
    var plannedDate: Date?
    var isAllDay = false
    var routineDurationMode: RoutineDurationMode?
    var availabilityStartDate: Date?
    var availabilityEndDate: Date?
    var reminderAt: Date?
    var priority: RoutineTaskPriority = .medium
    var importance: RoutineTaskImportance = .level2
    var urgency: RoutineTaskUrgency = .level2
    var pressure: RoutineTaskPressure = .none
    var imageData: Data?
    var voiceNote: RoutineVoiceNote?
    var attachments: [AttachmentItem] = []
    var selectedPlaceIDs: [UUID] = []
    var routineColor: RoutineTaskColor = .none
    var estimatedDurationMinutes: Int?
    var actualDurationMinutes: Int?
    var storyPoints: Int?
    var focusModeEnabled = false
    var routineTags: [String] = []
    var routineGoals: [RoutineGoalSummary] = []
    var eventIDs: [UUID] = []
    var relationships: [RoutineTaskRelationship] = []
    var tagDraft = ""
    var goalDraft = ""
    var scheduleMode: RoutineScheduleMode = .oneOff
    var frequency: TaskFormFrequencyUnit = .day
    var frequencyValue = 1
    var recurrenceKind: RoutineRecurrenceRule.Kind = .intervalDays
    var recurrenceHasExplicitTime = false
    var recurrenceHasTimeRange = false
    var recurrenceTimeRangeRole: RoutineTimeRangeRole?
    var recurrenceTimeOfDay: RoutineTimeOfDay = .defaultValue
    var recurrenceTimeRangeStart: RoutineTimeOfDay = RoutineTimeRange.defaultValue.start
    var recurrenceTimeRangeEnd: RoutineTimeOfDay = RoutineTimeRange.defaultValue.end
    var recurrenceWeekday = 1
    var recurrenceDayOfMonth = 1
    var recurrenceWeekdays: [Int] = []
    var recurrenceDaysOfMonth: [Int] = []
    var autoAssumeDailyDone = false
    var autoAssumeDoneTimeOfDay: RoutineTimeOfDay = RoutineAssumedCompletion.defaultDoneTimeOfDay
    var routineSteps: [RoutineStep] = []
    var stepDraft = ""
    var routineChecklistItems: [RoutineChecklistItem] = []
    var checklistItemDraftTitle = ""
    var checklistItemDraftInterval = 3

    init() {}

    init(state: AddRoutineFeature.State) {
        let basics = state.basics
        let organization = state.organization
        let schedule = state.schedule
        let checklist = state.checklist

        routineName = basics.routineName
        routineEmoji = basics.routineEmoji
        routineNotes = basics.routineNotes
        routineLink = basics.routineLink
        deadline = basics.deadline
        plannedDate = RoutineTask.normalizedPlannedDate(basics.plannedDate)
        isAllDay = basics.isAllDay
        routineDurationMode = basics.routineDurationMode
        availabilityStartDate = basics.availabilityStartDate
        availabilityEndDate = basics.availabilityEndDate
        reminderAt = basics.reminderAt
        priority = basics.priority
        importance = basics.importance
        urgency = basics.urgency
        pressure = basics.pressure
        imageData = basics.imageData
        voiceNote = basics.voiceNote
        attachments = basics.attachments
        selectedPlaceIDs = RoutinePlaceIDStorage.sanitized(
            basics.selectedPlaceIDs.isEmpty ? basics.selectedPlaceID.map { [$0] } ?? [] : basics.selectedPlaceIDs
        )
        routineColor = basics.routineColor
        estimatedDurationMinutes = basics.estimatedDurationMinutes
        actualDurationMinutes = basics.actualDurationMinutes
        storyPoints = basics.storyPoints
        focusModeEnabled = basics.focusModeEnabled
        routineTags = organization.routineTags
        routineGoals = organization.routineGoals
        eventIDs = RoutineEventIDStorage.sanitized(organization.eventIDs)
        relationships = organization.relationships
        tagDraft = organization.tagDraft
        goalDraft = organization.goalDraft
        scheduleMode = schedule.scheduleMode
        frequency = schedule.frequency
        frequencyValue = schedule.frequencyValue
        recurrenceKind = schedule.recurrenceKind
        recurrenceHasExplicitTime = schedule.recurrenceHasExplicitTime
        recurrenceHasTimeRange = schedule.recurrenceHasTimeRange
        recurrenceTimeRangeRole = schedule.recurrenceTimeRangeRole
        recurrenceTimeOfDay = schedule.recurrenceTimeOfDay
        recurrenceTimeRangeStart = schedule.recurrenceTimeRangeStart
        recurrenceTimeRangeEnd = schedule.recurrenceTimeRangeEnd
        recurrenceWeekday = schedule.recurrenceWeekday
        recurrenceDayOfMonth = schedule.recurrenceDayOfMonth
        recurrenceWeekdays = schedule.recurrenceWeekdays
        recurrenceDaysOfMonth = schedule.recurrenceDaysOfMonth
        autoAssumeDailyDone = schedule.autoAssumeDailyDone
        autoAssumeDoneTimeOfDay = schedule.autoAssumeDoneTimeOfDay
        routineSteps = checklist.routineSteps
        stepDraft = checklist.stepDraft
        routineChecklistItems = checklist.routineChecklistItems
        checklistItemDraftTitle = checklist.checklistItemDraftTitle
        checklistItemDraftInterval = checklist.checklistItemDraftInterval
    }

    var isMeaningful: Bool {
        hasText(routineName)
            || routineEmoji != "✨"
            || hasText(routineNotes)
            || hasText(routineLink)
            || deadline != nil
            || plannedDate != nil
            || isAllDay
            || (routineDurationMode ?? .oneDay) != .oneDay
            || availabilityStartDate != nil
            || availabilityEndDate != nil
            || reminderAt != nil
            || priority != .medium
            || importance != .level2
            || urgency != .level2
            || pressure != .none
            || imageData?.isEmpty == false
            || voiceNote != nil
            || !attachments.isEmpty
            || !selectedPlaceIDs.isEmpty
            || routineColor != .none
            || estimatedDurationMinutes != nil
            || actualDurationMinutes != nil
            || storyPoints != nil
            || focusModeEnabled
            || !routineTags.isEmpty
            || !routineGoals.isEmpty
            || !eventIDs.isEmpty
            || !relationships.isEmpty
            || hasText(tagDraft)
            || hasText(goalDraft)
            || scheduleMode != .oneOff
            || frequency != .day
            || frequencyValue != 1
            || recurrenceKind != .intervalDays
            || recurrenceHasExplicitTime
            || recurrenceHasTimeRange
            || (recurrenceHasTimeRange && (recurrenceTimeRangeRole ?? .availability) != .availability)
            || recurrenceTimeOfDay != .defaultValue
            || recurrenceTimeRangeStart != RoutineTimeRange.defaultValue.start
            || recurrenceTimeRangeEnd != RoutineTimeRange.defaultValue.end
            || autoAssumeDailyDone
            || autoAssumeDoneTimeOfDay != RoutineAssumedCompletion.defaultDoneTimeOfDay
            || !routineSteps.isEmpty
            || hasText(stepDraft)
            || !routineChecklistItems.isEmpty
            || hasText(checklistItemDraftTitle)
            || checklistItemDraftInterval != 3
    }

    func persist(client: CreationDraftClient) {
        guard isMeaningful else {
            CreationDraftPersistence.clear(.task, client: client)
            return
        }

        CreationDraftPersistence.save(self, for: .task, client: client)
    }

    static func load(client: CreationDraftClient) -> AddRoutineDraftSnapshot? {
        CreationDraftPersistence.load(Self.self, for: .task, client: client)
    }

    func apply(to state: inout AddRoutineFeature.State) {
        state.basics.routineName = routineName
        state.basics.routineEmoji = RoutineTask.sanitizedEmoji(routineEmoji, fallback: state.basics.routineEmoji)
        state.basics.routineNotes = routineNotes
        state.basics.routineLink = routineLink
        state.basics.deadline = deadline
        state.basics.plannedDate = RoutineTask.normalizedPlannedDate(plannedDate)
        state.basics.isAllDay = isAllDay
        state.basics.routineDurationMode = scheduleMode.taskType == .todo
            ? .oneDay
            : (routineDurationMode ?? .oneDay)
        state.basics.availabilityStartDate = availabilityStartDate
        state.basics.availabilityEndDate = availabilityEndDate
        state.basics.reminderAt = reminderAt
        state.basics.priority = priority
        state.basics.importance = importance
        state.basics.urgency = urgency
        state.basics.pressure = pressure
        state.basics.imageData = imageData
        state.basics.voiceNote = voiceNote
        state.basics.attachments = attachments
        state.basics.selectedPlaceIDs = availableSelectedPlaceIDs(in: state)
        state.basics.selectedPlaceID = state.basics.selectedPlaceIDs.first
        state.basics.routineColor = routineColor
        state.basics.estimatedDurationMinutes = estimatedDurationMinutes
        state.basics.actualDurationMinutes = actualDurationMinutes
        state.basics.storyPoints = storyPoints
        state.basics.focusModeEnabled = focusModeEnabled
        state.organization.routineTags = RoutineTag.deduplicated(
            routineTags,
            preferredTags: state.organization.availableTags
        )
        state.organization.routineGoals = RoutineGoalSummary.sanitized(routineGoals)
        state.organization.eventIDs = availableEventIDs(in: state)
        state.organization.relationships = availableRelationships(in: state)
        state.organization.tagDraft = tagDraft
        state.organization.goalDraft = goalDraft
        state.schedule.scheduleMode = scheduleMode
        state.schedule.frequency = frequency
        state.schedule.frequencyValue = max(frequencyValue, 1)
        state.schedule.recurrenceKind = recurrenceKind
        state.schedule.recurrenceHasExplicitTime = recurrenceHasExplicitTime && !recurrenceHasTimeRange
        state.schedule.recurrenceHasTimeRange = recurrenceHasTimeRange
        state.schedule.recurrenceTimeRangeRole = recurrenceHasTimeRange
            ? (recurrenceTimeRangeRole ?? .availability)
            : .availability
        state.schedule.recurrenceTimeOfDay = recurrenceTimeOfDay
        state.schedule.recurrenceTimeRangeStart = recurrenceTimeRangeStart
        state.schedule.recurrenceTimeRangeEnd = recurrenceTimeRangeEnd
        state.schedule.recurrenceWeekday = min(max(recurrenceWeekday, 1), 7)
        state.schedule.recurrenceDayOfMonth = min(max(recurrenceDayOfMonth, 1), 31)
        state.schedule.recurrenceWeekdays = Array(Set(recurrenceWeekdays.map { min(max($0, 1), 7) })).sorted()
        state.schedule.recurrenceDaysOfMonth = Array(Set(recurrenceDaysOfMonth.map { min(max($0, 1), 31) })).sorted()
        if state.schedule.recurrenceWeekdays.isEmpty {
            state.schedule.recurrenceWeekdays = [state.schedule.recurrenceWeekday]
        }
        if state.schedule.recurrenceDaysOfMonth.isEmpty {
            state.schedule.recurrenceDaysOfMonth = [state.schedule.recurrenceDayOfMonth]
        }
        state.schedule.autoAssumeDailyDone = autoAssumeDailyDone
        state.schedule.autoAssumeDoneTimeOfDay = autoAssumeDoneTimeOfDay
        state.checklist.routineSteps = RoutineStep.sanitized(routineSteps)
        state.checklist.stepDraft = stepDraft
        state.checklist.routineChecklistItems = RoutineChecklistItem.sanitized(routineChecklistItems)
        state.checklist.checklistItemDraftTitle = checklistItemDraftTitle
        state.checklist.checklistItemDraftInterval = max(checklistItemDraftInterval, 1)
        AddRoutineValidationEditor.refreshNameValidation(state: &state)
    }

    func applied(to state: AddRoutineFeature.State) -> AddRoutineFeature.State {
        var restoredState = state
        apply(to: &restoredState)
        return restoredState
    }

    private func availableSelectedPlaceIDs(in state: AddRoutineFeature.State) -> [UUID] {
        let selectedIDs = RoutinePlaceIDStorage.sanitized(selectedPlaceIDs)
        let availableIDs = Set(state.organization.availablePlaces.map(\.id))
        guard !availableIDs.isEmpty else { return selectedIDs }
        return selectedIDs.filter { availableIDs.contains($0) }
    }

    private func availableRelationships(in state: AddRoutineFeature.State) -> [RoutineTaskRelationship] {
        let availableIDs = Set(state.organization.availableRelationshipTasks.map(\.id))
        guard !availableIDs.isEmpty else {
            return RoutineTaskRelationship.sanitized(relationships)
        }

        return RoutineTaskRelationship.sanitized(
            relationships.filter { availableIDs.contains($0.targetTaskID) }
        )
    }

    private func availableEventIDs(in state: AddRoutineFeature.State) -> [UUID] {
        let selectedIDs = RoutineEventIDStorage.sanitized(eventIDs)
        let availableIDs = Set(state.organization.availableEvents.map(\.id))
        guard !availableIDs.isEmpty else { return selectedIDs }
        return selectedIDs.filter { availableIDs.contains($0) }
    }

    private func hasText(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct GoalCreationDraftSnapshot: Codable, Equatable {
    var draft: GoalsFeature.GoalDraft

    init(draft: GoalsFeature.GoalDraft = GoalsFeature.GoalDraft()) {
        self.draft = draft
    }

    var isMeaningful: Bool {
        draft.id == nil
            && (RoutineGoal.cleanedTitle(draft.title) != nil
                || RoutineGoal.cleanedEmoji(draft.emoji) != nil
                || RoutineGoal.cleanedNotes(draft.notes) != nil
                || draft.targetDate != nil
                || !draft.tags.isEmpty
                || !draft.tagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || draft.color != .none
                || draft.parentGoalID != nil)
    }

    func persist(client: CreationDraftClient) {
        guard isMeaningful else {
            CreationDraftPersistence.clear(.goal, client: client)
            return
        }

        CreationDraftPersistence.save(self, for: .goal, client: client)
    }

    static func load(client: CreationDraftClient) -> GoalCreationDraftSnapshot? {
        CreationDraftPersistence.load(Self.self, for: .goal, client: client)
    }
}

struct RoutineNoteDraftSnapshot: Codable, Equatable {
    var title = ""
    var bodyText = ""
    var tags: [String] = []
    var tagDraft = ""
    var imageData: Data?
    var voiceNote: RoutineVoiceNote?
    var attachments: [AttachmentItem] = []

    var isMeaningful: Bool {
        RoutineNote.cleanedText(title) != nil
            || RoutineNote.cleanedText(bodyText) != nil
            || !tags.isEmpty
            || !tagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || imageData?.isEmpty == false
            || voiceNote != nil
            || !attachments.isEmpty
    }

    func persist() {
        guard isMeaningful else {
            CreationDraftPersistence.clear(.note)
            return
        }

        CreationDraftPersistence.save(self, for: .note)
    }

    static func load() -> Self? {
        CreationDraftPersistence.load(Self.self, for: .note)
    }
}

struct EmotionLogDraftSnapshot: Codable, Equatable {
    var valence = 0.25
    var arousal = -0.15
    var selectedFamilies: [EmotionFamily] = [.calm]
    var selectedLabels: [String] = [EmotionFamily.calm.defaultLabel]
    var intensity = 3.0
    var selectedBodyAreas: [EmotionBodyArea] = []
    var reflection = ""
    var linkedNoteID: UUID?
    var linkedGoalID: UUID?
    var linkedTaskID: UUID?
    var linkedPlaceID: UUID?
    var linkedSleepSessionID: UUID?

    var isMeaningful: Bool {
        valence != 0.25
            || arousal != -0.15
            || selectedFamilies != [.calm]
            || selectedLabels != [EmotionFamily.calm.defaultLabel]
            || intensity != 3.0
            || !selectedBodyAreas.isEmpty
            || EmotionLog.cleanedText(reflection) != nil
            || linkedNoteID != nil
            || linkedGoalID != nil
            || linkedTaskID != nil
            || linkedPlaceID != nil
            || linkedSleepSessionID != nil
    }

    func persist() {
        guard isMeaningful else {
            CreationDraftPersistence.clear(.emotion)
            return
        }

        CreationDraftPersistence.save(self, for: .emotion)
    }

    static func load() -> Self? {
        CreationDraftPersistence.load(Self.self, for: .emotion)
    }
}

struct RoutineEventDraftSnapshot: Codable, Equatable {
    var title = ""
    var notesText = ""
    var emoji = ""
    var isAllDay = true
    var startDate = Date()
    var endDate = Date().addingTimeInterval(60 * 60)
    var reminderAt: Date?
    var tags: [String] = []
    var tagDraft = ""

    func isMeaningful(comparedTo baseline: RoutineEventDraftSnapshot) -> Bool {
        RoutineEvent.cleanedText(title) != nil
            || RoutineEvent.cleanedText(notesText) != nil
            || RoutineEvent.cleanedText(emoji) != nil
            || isAllDay != baseline.isAllDay
            || startDate != baseline.startDate
            || endDate != baseline.endDate
            || reminderAt != baseline.reminderAt
            || !tags.isEmpty
            || !tagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func persist(comparedTo baseline: RoutineEventDraftSnapshot) {
        guard isMeaningful(comparedTo: baseline) else {
            CreationDraftPersistence.clear(.event)
            return
        }

        CreationDraftPersistence.save(self, for: .event)
    }

    static func load() -> Self? {
        CreationDraftPersistence.load(Self.self, for: .event)
    }
}

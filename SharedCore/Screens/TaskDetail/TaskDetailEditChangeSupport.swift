import Foundation

struct TaskDetailEditChangeRequest {
    let name: String
    let emoji: String
    let notes: String
    let link: String
    let estimatedDurationMinutes: Int?
    let storyPoints: Int?
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
    let color: RoutineTaskColor
    let imageData: Data?
    let voiceNote: RoutineVoiceNote?
    let editAttachments: [AttachmentItem]
    let taskAttachments: [AttachmentItem]
    let selectedPlaceID: UUID?
    let selectedPlaceIDs: [UUID]
    let tags: [String]
    let availableGoals: [RoutineGoalSummary]
    let goals: [RoutineGoalSummary]
    let eventIDs: [UUID]
    let relationships: [RoutineTaskRelationship]
    let tagDraft: String
    let goalDraft: String
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
    let recurrenceHasTimeRange: Bool
    let recurrenceTimeRangeRole: RoutineTimeRangeRole
    let recurrenceTimeOfDay: RoutineTimeOfDay
    let recurrenceTimeRangeStart: RoutineTimeOfDay
    let recurrenceTimeRangeEnd: RoutineTimeOfDay
    let recurrenceWeekday: Int
    let recurrenceWeekdays: [Int]
    let recurrenceDayOfMonth: Int
    let autoAssumeDailyDone: Bool
    let autoAssumeDoneTimeOfDay: RoutineTimeOfDay
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
        self.isAllDay = state.editIsAllDay
        self.routineDurationMode = state.editRoutineDurationMode
        self.availabilityStartDate = state.editAvailabilityStartDate
        self.availabilityEndDate = state.editAvailabilityEndDate
        self.plannedDate = state.editPlannedDate
        self.reminderAt = state.editScheduleMode == .oneOff ? state.editReminderAt : nil
        self.priority = state.editPriority
        self.importance = state.editImportance
        self.urgency = state.editUrgency
        self.color = state.editColor
        self.imageData = state.editImageData
        self.voiceNote = state.editVoiceNote
        self.editAttachments = state.editAttachments
        self.taskAttachments = state.taskAttachments
        self.selectedPlaceID = state.editSelectedPlaceID
        self.selectedPlaceIDs = state.editSelectedPlaceIDs
        self.tags = state.editRoutineTags
        self.availableGoals = state.availableGoals
        self.goals = state.editRoutineGoals
        self.eventIDs = state.editEventIDs
        self.relationships = state.editRelationships
        self.tagDraft = state.editTagDraft
        self.goalDraft = state.editGoalDraft
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
        self.recurrenceHasTimeRange = state.editRecurrenceHasTimeRange
        self.recurrenceTimeRangeRole = state.editRecurrenceTimeRangeRole
        self.recurrenceTimeOfDay = state.editRecurrenceTimeOfDay
        self.recurrenceTimeRangeStart = state.editRecurrenceTimeRangeStart
        self.recurrenceTimeRangeEnd = state.editRecurrenceTimeRangeEnd
        self.recurrenceWeekday = state.editRecurrenceWeekday
        self.recurrenceWeekdays = state.effectiveEditRecurrenceWeekdays
        self.recurrenceDayOfMonth = state.editRecurrenceDayOfMonth
        self.autoAssumeDailyDone = state.editAutoAssumeDailyDone
        self.autoAssumeDoneTimeOfDay = state.editAutoAssumeDoneTimeOfDay
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
        let currentLink = RoutineTask.linkEditorText(for: task.linkItems)
        let currentTags = RoutineTag.deduplicated(task.tags)
        let currentGoalIDs = task.goalIDs
        let currentEventIDs = task.eventIDs
        let currentRelationships = RoutineTaskRelationship.sanitized(task.relationships, ownerID: task.id)
        let currentDeadline = task.scheduleMode == .oneOff ? task.deadline : nil
        let candidateTags = RoutineTag.appending(request.tagDraft, to: request.tags)
        let candidateGoals = RoutineGoalSummary.appending(
            request.goalDraft,
            availableGoals: request.availableGoals,
            to: request.goals
        )
        let candidateGoalIDs = RoutineGoalSummary.sanitized(candidateGoals).map(\.id)
        let candidateRelationships = RoutineTaskRelationship.sanitized(request.relationships, ownerID: task.id)
        let currentSteps = RoutineStep.sanitized(task.steps)
        let candidateSteps = RoutineStep.normalizedTitle(request.stepDraft).map { title in
            request.steps + [RoutineStep(title: title)]
        } ?? request.steps
        let currentChecklistItems = RoutineChecklistItem.sanitized(task.checklistItems)
        let candidateChecklistItems = RoutineChecklistItem.normalizedTitle(request.checklistItemDraftTitle).map { title in
            request.checklistItems + [
                RoutineChecklistItem(
                    title: title,
                    intervalDays: request.scheduleMode.normalizedChecklistItemIntervalDays(
                        request.checklistItemDraftInterval
                    )
                )
            ]
        } ?? request.checklistItems
        let sanitizedCandidateChecklistItems = RoutineChecklistItem.sanitized(
            candidateChecklistItems,
            for: request.scheduleMode
        )

        return trimmedName != currentName
            || request.emoji != currentEmoji
            || request.notes != currentNotes
            || RoutineTask.linkEditorText(for: RoutineTask.sanitizedLinkItems(fromEditorText: request.link)) != currentLink
            || request.estimatedDurationMinutes != task.estimatedDurationMinutes
            || request.storyPoints != task.storyPoints
            || request.deadline != currentDeadline
            || request.isAllDay != task.isAllDay
            || normalizedRoutineDurationMode(for: request) != normalizedRoutineDurationMode(for: task)
            || request.availabilityStartDate != task.availabilityStartDate
            || request.availabilityEndDate != task.availabilityEndDate
            || request.plannedDate != task.plannedDate
            || request.reminderAt != task.reminderAt
            || request.priority != task.priority
            || request.importance != task.importance
            || request.urgency != task.urgency
            || request.color != task.color
            || request.imageData != task.imageData
            || request.voiceNote != task.voiceNote
            || request.editAttachments != request.taskAttachments
            || RoutinePlaceIDStorage.sanitized(
                request.selectedPlaceIDs.isEmpty ? request.selectedPlaceID.map { [$0] } ?? [] : request.selectedPlaceIDs
            ) != task.placeIDs
            || candidateTags != currentTags
            || candidateGoalIDs != currentGoalIDs
            || RoutineEventIDStorage.sanitized(request.eventIDs) != currentEventIDs
            || candidateRelationships != currentRelationships
            || request.scheduleMode != task.scheduleMode
            || RoutineStep.sanitized(candidateSteps) != currentSteps
            || sanitizedCandidateChecklistItems != currentChecklistItems
            || recurrenceRule(for: request) != task.recurrenceRule
            || recurrenceTimeRangeRole(for: request) != recurrenceTimeRangeRole(for: task)
            || request.autoAssumeDailyDone != task.autoAssumeDailyDone
            || normalizedAutoAssumeDoneTimeOfDay(for: request) != normalizedAutoAssumeDoneTimeOfDay(for: task)
            || request.focusModeEnabled != task.focusModeEnabled
            || request.pressure != task.pressure
    }

    private static func normalizedRoutineDurationMode(
        for request: TaskDetailEditChangeRequest
    ) -> RoutineDurationMode {
        request.scheduleMode == .oneOff ? .oneDay : request.routineDurationMode
    }

    private static func normalizedRoutineDurationMode(for task: RoutineTask) -> RoutineDurationMode {
        task.routineDurationMode
    }

    private static func normalizedAutoAssumeDoneTimeOfDay(
        for request: TaskDetailEditChangeRequest
    ) -> RoutineTimeOfDay? {
        request.autoAssumeDailyDone ? request.autoAssumeDoneTimeOfDay : nil
    }

    private static func normalizedAutoAssumeDoneTimeOfDay(
        for task: RoutineTask
    ) -> RoutineTimeOfDay? {
        task.autoAssumeDailyDone
            ? (task.autoAssumeDoneTimeOfDay ?? RoutineAssumedCompletion.defaultDoneTimeOfDay)
            : nil
    }

    private static func recurrenceRule(for request: TaskDetailEditChangeRequest) -> RoutineRecurrenceRule {
        let usesAvailabilityTiming = !request.isAllDay
        let timeRange = usesAvailabilityTiming && request.recurrenceHasTimeRange
            ? RoutineTimeRange(
                start: request.recurrenceTimeRangeStart,
                end: request.recurrenceTimeRangeEnd
            )
            : nil

        if request.scheduleMode == .oneOff {
            return .interval(
                days: 1,
                at: usesAvailabilityTiming && request.recurrenceHasExplicitTime ? request.recurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        }

        switch request.recurrenceKind {
        case .intervalDays:
            return .interval(
                days: request.frequencyValue * request.frequency.daysMultiplier,
                at: usesAvailabilityTiming && request.recurrenceHasExplicitTime ? request.recurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        case .dailyTime:
            if let timeRange {
                return .daily(in: timeRange)
            }
            return RoutineRecurrenceRule(
                kind: .dailyTime,
                timeOfDay: usesAvailabilityTiming && request.recurrenceHasExplicitTime ? request.recurrenceTimeOfDay : nil
            )
        case .weekly:
            return .weekly(
                on: effectiveRecurrenceWeekdays(for: request),
                at: usesAvailabilityTiming && request.recurrenceHasExplicitTime ? request.recurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        case .monthlyDay:
            return .monthly(
                on: request.recurrenceDayOfMonth,
                at: usesAvailabilityTiming && request.recurrenceHasExplicitTime ? request.recurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        }
    }

    private static func recurrenceTimeRangeRole(for request: TaskDetailEditChangeRequest) -> RoutineTimeRangeRole {
        recurrenceRule(for: request).timeRange == nil ? .availability : request.recurrenceTimeRangeRole
    }

    private static func recurrenceTimeRangeRole(for task: RoutineTask) -> RoutineTimeRangeRole {
        task.recurrenceRule.timeRange == nil ? .availability : task.recurrenceTimeRangeRole
    }

    private static func effectiveRecurrenceWeekdays(for request: TaskDetailEditChangeRequest) -> [Int] {
        let selectedWeekdays = Array(Set(request.recurrenceWeekdays.map { min(max($0, 1), 7) })).sorted()
        return selectedWeekdays.isEmpty ? [min(max(request.recurrenceWeekday, 1), 7)] : selectedWeekdays
    }
}

enum TaskFormReminderLeadTime: Int, CaseIterable, Identifiable {
    case atEventTime = 0
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case oneDay = 1_440

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .atEventTime:
            return "At event time"
        case .fiveMinutes:
            return "5 minutes before"
        case .fifteenMinutes:
            return "15 minutes before"
        case .thirtyMinutes:
            return "30 minutes before"
        case .oneHour:
            return "1 hour before"
        case .twoHours:
            return "2 hours before"
        case .oneDay:
            return "1 day before"
        }
    }

    static func matchedLeadMinutes(
        eventDate: Date?,
        reminderAt: Date?
    ) -> Int? {
        guard let eventDate, let reminderAt else { return nil }
        let leadMinutes = Int((eventDate.timeIntervalSince(reminderAt) / 60).rounded())
        return allCases.first { abs($0.rawValue - leadMinutes) <= 1 }?.rawValue
    }

    static func reminderDate(
        eventDate: Date,
        leadMinutes: Int
    ) -> Date {
        eventDate.addingTimeInterval(-Double(leadMinutes) * 60)
    }

    static func eventDate(
        scheduleMode: RoutineScheduleMode,
        deadline: Date?,
        recurrenceRule: RoutineRecurrenceRule,
        referenceDate: Date,
        calendar: Calendar
    ) -> Date? {
        if scheduleMode == .oneOff {
            return deadline
        }

        guard scheduleMode.scheduleBehavior == .fixed,
              !scheduleMode.isChecklistDrivenMode,
              let timeOfDay = recurrenceRule.timeRange?.start ?? recurrenceRule.timeOfDay else {
            return nil
        }

        switch recurrenceRule.kind {
        case .intervalDays:
            return nil

        case .dailyTime:
            return nextDailyOccurrence(
                after: referenceDate,
                timeOfDay: timeOfDay,
                calendar: calendar
            )

        case .weekly:
            return nextWeeklyOccurrence(
                after: referenceDate,
                weekday: recurrenceRule.weekday ?? calendar.firstWeekday,
                timeOfDay: timeOfDay,
                calendar: calendar
            )

        case .monthlyDay:
            return nextMonthlyOccurrence(
                after: referenceDate,
                dayOfMonth: recurrenceRule.dayOfMonth ?? 1,
                timeOfDay: timeOfDay,
                calendar: calendar
            )
        }
    }

    private static func nextDailyOccurrence(
        after referenceDate: Date,
        timeOfDay: RoutineTimeOfDay,
        calendar: Calendar
    ) -> Date {
        let candidate = timeOfDay.date(on: referenceDate, calendar: calendar)
        if candidate >= referenceDate {
            return candidate
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
        return timeOfDay.date(on: tomorrow, calendar: calendar)
    }

    private static func nextWeeklyOccurrence(
        after referenceDate: Date,
        weekday: Int,
        timeOfDay: RoutineTimeOfDay,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.weekday = min(max(weekday, 1), 7)
        components.hour = timeOfDay.hour
        components.minute = timeOfDay.minute

        return calendar.nextDate(
            after: referenceDate.addingTimeInterval(-1),
            matching: components,
            matchingPolicy: .nextTimePreservingSmallerComponents,
            repeatedTimePolicy: .first,
            direction: .forward
        ) ?? nextDailyOccurrence(after: referenceDate, timeOfDay: timeOfDay, calendar: calendar)
    }

    private static func nextMonthlyOccurrence(
        after referenceDate: Date,
        dayOfMonth: Int,
        timeOfDay: RoutineTimeOfDay,
        calendar: Calendar
    ) -> Date {
        let resolvedDay = min(max(dayOfMonth, 1), 31)
        let monthAnchor = calendar.date(
            from: calendar.dateComponents([.year, .month], from: referenceDate)
        ) ?? referenceDate
        var currentMonth = monthAnchor

        while true {
            let dayCount = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 31
            let safeDay = min(resolvedDay, dayCount)
            var components = calendar.dateComponents([.year, .month], from: currentMonth)
            components.day = safeDay
            components.hour = timeOfDay.hour
            components.minute = timeOfDay.minute

            if let candidate = calendar.date(from: components), candidate >= referenceDate {
                return candidate
            }

            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
}

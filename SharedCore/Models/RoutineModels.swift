import Foundation
import SwiftData

@Model
final class RoutineTask {
    var id: UUID = UUID()
    var name: String?
    var emoji: String?
    var taskDescription: String?
    var notes: String?
    var link: String?
    var linksStorage: String = ""
    var deadline: Date?
    var plannedDate: Date?
    var customTaskSectionIDRawValue: String?
    var isAllDay: Bool = false
    var routineDurationModeRawValue: String = RoutineDurationMode.oneDay.rawValue
    var availabilityStartDate: Date?
    var availabilityEndDate: Date?
    var reminderAt: Date?
    var priorityRawValue: String = RoutineTaskPriority.none.rawValue
    var importanceRawValue: String = RoutineTaskImportance.level2.rawValue
    var urgencyRawValue: String = RoutineTaskUrgency.level2.rawValue
    var pressureRawValue: String = RoutineTaskPressure.none.rawValue
    var pressureUpdatedAt: Date?
    var thinkingNeededRawValue: String = RoutineTaskThinkingNeeded.none.rawValue
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var voiceNoteData: Data?
    var voiceNoteDurationSeconds: Double?
    var voiceNoteCreatedAt: Date?
    var placeID: UUID?
    var placeIDsStorage: String = ""
    var destinationAddress: String?
    var destinationLatitude: Double?
    var destinationLongitude: Double?
    var tagsStorage: String = ""
    var flagsStorage: String = ""
    var stepsStorage: String = ""
    var checklistItemsStorage: String = ""
    var completedChecklistItemIDsStorage: String = ""
    var completedChecklistProgressStartedAt: Date?
    var relationshipsStorage: String = ""
    var goalIDsStorage: String = ""
    var eventIDsStorage: String = ""
    var scheduleModeRawValue: String = RoutineScheduleMode.fixedInterval.rawValue
    var recurrenceStorageVersion: Int16 = 0
    var recurrenceKindRawValue: String = RoutineRecurrenceRule.Kind.intervalDays.rawValue
    var recurrenceTimeOfDayHour: Int?
    var recurrenceTimeOfDayMinute: Int?
    var recurrenceTimeRangeStartHour: Int?
    var recurrenceTimeRangeStartMinute: Int?
    var recurrenceTimeRangeEndHour: Int?
    var recurrenceTimeRangeEndMinute: Int?
    var recurrenceTimeRangeRoleRawValue: String = RoutineTimeRangeRole.availability.rawValue
    var recurrenceWeekday: Int?
    var recurrenceDayOfMonth: Int?
    // Legacy JSON storage retained only so existing stores can be backfilled into the typed recurrence columns.
    var recurrenceRuleStorage: String = ""
    var interval: Int16 = 1
    var lastDone: Date?
    var lastSatisfiedScheduledOccurrenceAt: Date?
    var canceledAt: Date?
    var scheduleAnchor: Date?
    var pausedAt: Date?
    /// Nil represents an indefinite pause. A non-nil value restores the task's
    /// active state as soon as this instant is reached.
    var pauseUntil: Date?
    var snoozedUntil: Date?
    var pinnedAt: Date?
    var manualSectionOrderStorage: String = ""
    /// Per-metric manual tie-break order used only by the Mac task-ranking workspace.
    var taskRankingOrderStorage: String = ""
    /// Optional, synchronized due-date targets used only to derive Task Ladder's Now values.
    var temporalWeightRuleStorage: String = ""
    var completedStepCount: Int16 = 0
    var sequenceStartedAt: Date?
    var colorRawValue: String = RoutineTaskColor.none.rawValue
    var createdAt: Date?
    var todoStateRawValue: String?
    var activityStateRawValue: String = RoutineActivityState.idle.rawValue
    var ongoingSince: Date?
    var autoAssumeDailyDone: Bool = false
    var hidesAssumedDoneCalendarBlock: Bool = false
    var autoAssumeDoneTimeOfDayHour: Int?
    var autoAssumeDoneTimeOfDayMinute: Int?
    var estimatedDurationMinutes: Int?
    var actualDurationMinutes: Int?
    var storyPoints: Int?
    /// A learned, task-choice-only tie-break. It never changes the visible task metadata.
    var taskChoiceTieBreakScore: Double = 0
    /// The number of persisted task-choice comparisons this task has participated in.
    var taskChoiceComparisonCount: Int16 = 0
    var focusModeEnabled: Bool = false
    var cadenceEnabled: Bool = true
    var autoPauseAfterCompletion: Bool = false
    var nudgesEnabled: Bool = true
    var showsTaskDetailHeatmap: Bool = false
    var showsTaskDetailHistory: Bool = false
    var isTaskDetailCalendarExpanded: Bool = false
    var hasExplicitImportance: Bool = false
    var hasExplicitUrgency: Bool = false
    var commentsStorage: String = ""
    var changeLogStorage: String = ""

    init(
        id: UUID = UUID(),
        name: String? = nil,
        emoji: String? = nil,
        taskDescription: String? = nil,
        notes: String? = nil,
        link: String? = nil,
        links: [String] = [],
        deadline: Date? = nil,
        plannedDate: Date? = nil,
        customTaskSectionID: UUID? = nil,
        isAllDay: Bool = false,
        routineDurationMode: RoutineDurationMode = .oneDay,
        availabilityStartDate: Date? = nil,
        availabilityEndDate: Date? = nil,
        reminderAt: Date? = nil,
        priority: RoutineTaskPriority = .none,
        importance: RoutineTaskImportance = .level2,
        urgency: RoutineTaskUrgency = .level2,
        pressure: RoutineTaskPressure = .none,
        temporalWeightRule: RoutineTaskTemporalWeightRule? = nil,
        taskLadderEntryWindow: RoutineTaskLadderEntryWindow = .throughoutCycle,
        pressureUpdatedAt: Date? = nil,
        thinkingNeeded: RoutineTaskThinkingNeeded = .none,
        imageData: Data? = nil,
        voiceNoteData: Data? = nil,
        voiceNoteDurationSeconds: Double? = nil,
        voiceNoteCreatedAt: Date? = nil,
        placeID: UUID? = nil,
        placeIDs: [UUID] = [],
        destinationAddress: String? = nil,
        destinationLatitude: Double? = nil,
        destinationLongitude: Double? = nil,
        tags: [String] = [],
        flags: [String] = [],
        goalIDs: [UUID] = [],
        eventIDs: [UUID] = [],
        relationships: [RoutineTaskRelationship] = [],
        steps: [RoutineStep] = [],
        checklistItems: [RoutineChecklistItem] = [],
        scheduleMode: RoutineScheduleMode? = nil,
        interval: Int16 = 1,
        recurrenceRule: RoutineRecurrenceRule? = nil,
        recurrenceTimeRangeRole: RoutineTimeRangeRole = .availability,
        lastDone: Date? = nil,
        lastSatisfiedScheduledOccurrenceAt: Date? = nil,
        canceledAt: Date? = nil,
        scheduleAnchor: Date? = nil,
        pausedAt: Date? = nil,
        pauseUntil: Date? = nil,
        snoozedUntil: Date? = nil,
        pinnedAt: Date? = nil,
        completedStepCount: Int16 = 0,
        sequenceStartedAt: Date? = nil,
        color: RoutineTaskColor = .none,
        createdAt: Date? = Date(),
        todoStateRawValue: String? = nil,
        activityStateRawValue: String? = nil,
        ongoingSince: Date? = nil,
        autoAssumeDailyDone: Bool = false,
        hidesAssumedDoneCalendarBlock: Bool = false,
        autoAssumeDoneTimeOfDay: RoutineTimeOfDay? = nil,
        estimatedDurationMinutes: Int? = nil,
        actualDurationMinutes: Int? = nil,
        storyPoints: Int? = nil,
        taskChoiceTieBreakScore: Double = 0,
        taskChoiceComparisonCount: Int16 = 0,
        focusModeEnabled: Bool = false,
        cadenceEnabled: Bool = true,
        autoPauseAfterCompletion: Bool = false,
        nudgesEnabled: Bool = true,
        showsTaskDetailHeatmap: Bool = false,
        showsTaskDetailHistory: Bool = false,
        isTaskDetailCalendarExpanded: Bool = false,
        hasExplicitImportance: Bool = false,
        hasExplicitUrgency: Bool = false,
        comments: [RoutineTaskComment] = []
    ) {
        let resolvedScheduleMode = scheduleMode ?? (checklistItems.isEmpty ? .fixedInterval : .derivedFromChecklist)
        let resolvedCadenceEnabled = resolvedScheduleMode.taskType == .todo ? true : cadenceEnabled
        let inputRecurrenceRule =
            resolvedCadenceEnabled
            ? (recurrenceRule ?? RoutineRecurrenceRule.interval(days: max(Int(interval), 1)))
            : .interval(days: 1)
        let resolvedRecurrenceRule: RoutineRecurrenceRule
        switch resolvedScheduleMode.taskType {
        case .routine:
            resolvedRecurrenceRule = inputRecurrenceRule
        case .todo:
            resolvedRecurrenceRule = RoutineRecurrenceRule.interval(
                days: 1,
                at: inputRecurrenceRule.timeOfDay,
                timeRange: inputRecurrenceRule.timeRange
            )
        }
        let resolvedPlannedDate = Self.effectivePlannedDate(
            plannedDate: plannedDate,
            scheduleMode: resolvedScheduleMode,
            availabilityStartDate: availabilityStartDate,
            availabilityEndDate: availabilityEndDate
        )

        initializeIdentity(id, name, emoji, taskDescription, notes, link, links)
        initializePlanning(deadline, resolvedPlannedDate, customTaskSectionID, isAllDay, routineDurationMode, resolvedScheduleMode)
        initializeAvailability(availabilityStartDate, availabilityEndDate, reminderAt, resolvedScheduleMode)
        initializePriorities(priority, importance, urgency, pressure, pressureUpdatedAt, thinkingNeeded)
        initializeMedia(imageData, voiceNoteData, voiceNoteDurationSeconds, voiceNoteCreatedAt)
        initializePlaces(placeID, placeIDs, destinationAddress, destinationLatitude, destinationLongitude)
        initializeLabels(tags, flags, goalIDs, eventIDs)
        initializeStructure(relationships, steps, checklistItems, id, resolvedScheduleMode)
        initializeRecurrence(resolvedRecurrenceRule, recurrenceTimeRangeRole, resolvedScheduleMode, resolvedCadenceEnabled)
        initializeCompletion(
            lastDone, lastSatisfiedScheduledOccurrenceAt, canceledAt, scheduleAnchor, resolvedScheduleMode, resolvedCadenceEnabled)
        initializeAvailabilityState(pausedAt, pauseUntil, snoozedUntil, pinnedAt)
        initializeRanking(
            temporalWeightRule, taskLadderEntryWindow, resolvedRecurrenceRule, resolvedScheduleMode, resolvedCadenceEnabled, deadline)
        initializeProgress(completedStepCount, sequenceStartedAt, color, createdAt)
        initializeActivity(todoStateRawValue, activityStateRawValue, ongoingSince)
        initializeAssumptions(autoAssumeDailyDone, hidesAssumedDoneCalendarBlock, autoAssumeDoneTimeOfDay)
        initializeMetrics(estimatedDurationMinutes, actualDurationMinutes, storyPoints, taskChoiceTieBreakScore, taskChoiceComparisonCount)
        initializeBehavior(focusModeEnabled, resolvedCadenceEnabled, autoPauseAfterCompletion, nudgesEnabled, resolvedScheduleMode)
        initializeDetailPreferences(
            showsTaskDetailHeatmap,
            showsTaskDetailHistory,
            isTaskDetailCalendarExpanded,
            hasExplicitImportance,
            hasExplicitUrgency,
            comments
        )
        initializeChangeLog(createdAt, relationships, id)
        normalizeInitialProgress()
    }
}

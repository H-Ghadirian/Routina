import ComposableArchitecture
import Foundation

struct AddRoutineBasicsState: Equatable {
    var routineName: String = ""
    var routineEmoji: String = "✨"
    var taskDescription: String = ""
    var routineNotes: String = ""
    var routineLink: String = ""
    var deadline: Date?
    var isAllDay: Bool = false
    var routineDurationMode: RoutineDurationMode = .oneDay
    var availabilityStartDate: Date?
    var availabilityEndDate: Date?
    var plannedDate: Date?
    var reminderAt: Date?
    var priority: RoutineTaskPriority = .medium
    var importance: RoutineTaskImportance = .level2
    var urgency: RoutineTaskUrgency = .level2
    var pressure: RoutineTaskPressure = .none
    var temporalWeightRule: RoutineTaskTemporalWeightRule?
    var taskLadderEntryWindow: RoutineTaskLadderEntryWindow = .throughoutCycle
    var thinkingNeeded: RoutineTaskThinkingNeeded = .none
    var imageData: Data?
    var voiceNote: RoutineVoiceNote?
    var attachments: [AttachmentItem] = []
    var selectedPlaceID: UUID?
    var selectedPlaceIDs: [UUID] = []
    var destinationAddress: String = ""
    var destinationLatitude: Double?
    var destinationLongitude: Double?
    var routineColor: RoutineTaskColor = .none
    var estimatedDurationMinutes: Int?
    var actualDurationMinutes: Int?
    var storyPoints: Int?
    var focusModeEnabled: Bool = false
    var cadenceEnabled: Bool = true
    var autoPauseAfterCompletion: Bool = false
    var nudgesEnabled: Bool = true
    var taskLadderGroupEnabled: Bool = false
}

struct AddRoutineOrganizationState: Equatable {
    var customTaskSectionID: UUID?
    var routineTags: [String] = []
    var routineFlags: [String] = []
    var routineGoals: [RoutineGoalSummary] = []
    var eventIDs: [UUID] = []
    var relationships: [RoutineTaskRelationship] = []
    var availableTags: [String] = []
    var availableFlags: [String] = []
    var flagRules: [RoutineFlagRule] = []
    var availableTagSummaries: [RoutineTagSummary] = []
    var availableGoals: [RoutineGoalSummary] = []
    var availableEvents: [RoutineEventLinkCandidate] = []
    var relatedTagRules: [RoutineRelatedTagRule] = []
    var tagCounterDisplayMode: TagCounterDisplayMode = .defaultValue
    var availableRelationshipTasks: [RoutineTaskRelationshipCandidate] = []
    var tagDraft: String = ""
    var flagDraft: String = ""
    var goalDraft: String = ""
    var existingRoutineNames: [String] = []
    var availablePlaces: [RoutinePlaceSummary] = []
    var nameValidationMessage: String?
    var flagSelectionValidationMessage: String?
}

struct AddRoutineScheduleState: Equatable {
    var scheduleMode: RoutineScheduleMode = .oneOff
    var frequency: AddRoutineFeature.Frequency = .day
    var frequencyValue: Int = 1
    var recurrenceDraft: RoutineRecurrenceDraft = RoutineRecurrenceDraft(cadence: .none)
    var recurrenceDraftIsAuthoritative: Bool = false
    var recurrenceEditorMode: RoutineRecurrenceEditorMode = .simple
    var advancedRecurrenceRule: RoutineAdvancedRecurrenceRule = RoutineAdvancedRecurrenceRule()
    var recurrenceKind: RoutineRecurrenceRule.Kind = .intervalDays
    var recurrenceHasExplicitTime: Bool = false
    var recurrenceHasTimeRange: Bool = false
    var recurrenceTimeRangeRole: RoutineTimeRangeRole = .availability
    var recurrenceTimeOfDay: RoutineTimeOfDay = .defaultValue
    var recurrenceTimeRangeStart: RoutineTimeOfDay = RoutineTimeRange.defaultValue.start
    var recurrenceTimeRangeEnd: RoutineTimeOfDay = RoutineTimeRange.defaultValue.end
    var recurrenceWeekday: Int = Calendar.current.component(.weekday, from: Date())
    var recurrenceDayOfMonth: Int = Calendar.current.component(.day, from: Date())
    var recurrenceWeekdays: [Int] = []
    var recurrenceDaysOfMonth: [Int] = []
    var autoAssumeDailyDone: Bool = false
    var hidesAssumedDoneCalendarBlock: Bool = false
    var autoAssumeDoneTimeOfDay: RoutineTimeOfDay = RoutineAssumedCompletion.defaultDoneTimeOfDay
}

struct AddRoutineChecklistState: Equatable {
    var routineSteps: [RoutineStep] = []
    var stepDraft: String = ""
    var routineChecklistItems: [RoutineChecklistItem] = []
    var checklistItemDraftTitle: String = ""
    var checklistItemDraftInterval: Int = 3
    var checklistValidationMessage: String?
}

@ObservableState
struct AddRoutineFeatureState: Equatable {
    var basics = AddRoutineBasicsState()
    var organization = AddRoutineOrganizationState()
    var schedule = AddRoutineScheduleState()
    var checklist = AddRoutineChecklistState()
    var isSaving = false

    init(
        basics: AddRoutineBasicsState = AddRoutineBasicsState(),
        organization: AddRoutineOrganizationState = AddRoutineOrganizationState(),
        schedule: AddRoutineScheduleState = AddRoutineScheduleState(),
        checklist: AddRoutineChecklistState = AddRoutineChecklistState()
    ) {
        self.basics = basics
        self.organization = organization
        self.schedule = schedule
        self.checklist = checklist
        synchronizeRecurrenceDraftFromLegacy()
    }

    var taskType: RoutineTaskType {
        schedule.scheduleMode.taskType
    }

    var hasDeadline: Bool {
        basics.deadline != nil
    }

    var trimmedRoutineName: String {
        RoutineTask.trimmedName(basics.routineName) ?? ""
    }

    var candidateChecklistItems: [RoutineChecklistItem] {
        if let pendingItem = RoutineChecklistItem.normalizedTitle(checklist.checklistItemDraftTitle).map({
            RoutineChecklistItem(
                title: $0,
                intervalDays: schedule.scheduleMode.normalizedChecklistItemIntervalDays(
                    checklist.checklistItemDraftInterval
                )
            )
        }) {
            return RoutineChecklistItem.sanitized(
                checklist.routineChecklistItems + [pendingItem],
                for: schedule.scheduleMode
            )
        }
        return RoutineChecklistItem.sanitized(checklist.routineChecklistItems, for: schedule.scheduleMode)
    }

    var isSaveDisabled: Bool {
        isSaving
            || trimmedRoutineName.isEmpty
            || organization.nameValidationMessage != nil
            || candidateRecurrenceDraft.validationIssue != nil
    }

    var requiresChecklistItems: Bool {
        schedule.scheduleMode.isRoutineModeRequiringChecklistItems
    }

    var candidateRecurrenceRule: RoutineRecurrenceRule {
        candidateRecurrenceDraft.resolvedRecurrenceRule()
            ?? legacyCandidateRecurrenceRule
    }

    var candidateRecurrenceDraft: RoutineRecurrenceDraft {
        recurrenceDraftForPersistence()
    }

    var autoAssumeDoneUnavailableReason: String? {
        candidateRecurrenceDraft.validationIssue == nil
            ? RoutineAssumedCompletion.unavailableReason(
                scheduleMode: schedule.scheduleMode,
                recurrenceRule: candidateRecurrenceRule,
                recurrenceTimeRangeRole: schedule.recurrenceTimeRangeRole,
                availabilityStartDate: basics.availabilityStartDate,
                availabilityEndDate: basics.availabilityEndDate,
                isAllDay: basics.isAllDay,
                cadenceEnabled: schedule.scheduleMode.taskType == .todo
                    ? true
                    : basics.cadenceEnabled,
                hasSequentialSteps: !checklist.routineSteps.isEmpty,
                hasChecklistItems: !candidateChecklistItems.isEmpty
            )
            : "Fix the recurrence before using this Flag."
    }

    var autoAssumeDoneEnabledByFlag: Bool {
        RoutineFlagRules.enablesAutoAssumeDone(
            flags: organization.routineFlags,
            rules: organization.flagRules
        ) && autoAssumeDoneUnavailableReason == nil
    }

    func recurrenceDraftForPersistence(
        calendar: Calendar = .current
    ) -> RoutineRecurrenceDraft {
        schedule.recurrenceDraftIsAuthoritative
            ? schedule.recurrenceDraft
            : legacyRecurrenceDraft(calendar: calendar)
    }

    mutating func synchronizeRecurrenceDraftFromLegacy() {
        schedule.recurrenceDraftIsAuthoritative = false
    }

    private var legacyCandidateRecurrenceRule: RoutineRecurrenceRule {
        let cadenceEnabled = schedule.scheduleMode.taskType == .todo
            ? true
            : basics.cadenceEnabled
        let fallbackInterval = !schedule.scheduleMode.usesRoutineCadence || !cadenceEnabled
            ? 1
            : TaskFormRecurrenceConstraints.effectiveIntervalDays(
                value: schedule.frequencyValue,
                unit: schedule.frequency,
                scheduleMode: schedule.scheduleMode,
                routineDurationMode: basics.routineDurationMode,
                recurrenceKind: schedule.recurrenceKind
            )
        let usesAvailabilityTiming = !basics.isAllDay
        let timeRange = usesAvailabilityTiming ? schedule.recurrenceTimeRange : nil

        switch schedule.scheduleMode.taskType {
        case .todo:
            return .interval(
                days: 1,
                at: usesAvailabilityTiming && schedule.recurrenceHasExplicitTime ? schedule.recurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        case .routine:
            break
        }

        guard cadenceEnabled else { return .interval(days: 1) }

        guard !schedule.scheduleMode.isChecklistDrivenMode else {
            return .interval(days: max(fallbackInterval, 1))
        }

        if schedule.recurrenceEditorMode == .advanced {
            return .advanced(
                schedule.advancedRecurrenceRule,
                timeRange: timeRange
            )
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
                on: schedule.effectiveRecurrenceWeekdays,
                at: usesAvailabilityTiming && schedule.recurrenceHasExplicitTime ? schedule.recurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        case .monthlyDay:
            return .monthly(
                on: schedule.effectiveRecurrenceDaysOfMonth,
                at: usesAvailabilityTiming && schedule.recurrenceHasExplicitTime ? schedule.recurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        }
    }

    private func legacyRecurrenceDraft(
        calendar: Calendar
    ) -> RoutineRecurrenceDraft {
        let cadenceOverride: RoutineRecurrenceDraft.Cadence?
        if !schedule.scheduleMode.usesRoutineCadence {
            cadenceOverride = RoutineRecurrenceDraft.Cadence.none
        } else if schedule.scheduleMode.taskType != .todo,
                  !basics.cadenceEnabled {
            cadenceOverride = basics.autoPauseAfterCompletion
                ? .manual
                : RoutineRecurrenceDraft.Cadence.none
        } else if schedule.scheduleMode.isChecklistDrivenMode {
            cadenceOverride = .itemRunout
        } else {
            cadenceOverride = nil
        }

        let recurrenceRule = legacyCandidateRecurrenceRule
        let draft = RoutineRecurrenceDraft(
            recurrenceRule: recurrenceRule,
            cadence: cadenceOverride,
            timeRangeRole: schedule.recurrenceTimeRangeRole,
            calendar: calendar
        )
        return draft
    }

    var canAutoAssumeDailyDone: Bool {
        candidateRecurrenceDraft.validationIssue == nil
            && RoutineAssumedCompletion.canEnable(
            scheduleMode: schedule.scheduleMode,
            recurrenceRule: candidateRecurrenceRule,
            recurrenceTimeRangeRole: schedule.recurrenceTimeRangeRole,
            availabilityStartDate: basics.availabilityStartDate,
            availabilityEndDate: basics.availabilityEndDate,
            isAllDay: basics.isAllDay,
            cadenceEnabled: schedule.scheduleMode.taskType == .todo
                ? true
                : basics.cadenceEnabled,
            hasSequentialSteps: !checklist.routineSteps.isEmpty,
            hasChecklistItems: !checklist.routineChecklistItems.isEmpty
            )
    }
}

extension AddRoutineScheduleState {
    var effectiveRecurrenceWeekdays: [Int] {
        recurrenceWeekdays.isEmpty ? [recurrenceWeekday] : recurrenceWeekdays
    }

    var effectiveRecurrenceDaysOfMonth: [Int] {
        recurrenceDaysOfMonth.isEmpty ? [recurrenceDayOfMonth] : recurrenceDaysOfMonth
    }

    var recurrenceTimeRange: RoutineTimeRange? {
        guard recurrenceHasTimeRange else { return nil }
        return RoutineTimeRange(
            start: recurrenceTimeRangeStart,
            end: recurrenceTimeRangeEnd
        )
    }
}

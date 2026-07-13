import ComposableArchitecture
import Foundation

struct AddRoutineBasicsState: Equatable {
    var routineName: String = ""
    var routineEmoji: String = "✨"
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
    var imageData: Data?
    var voiceNote: RoutineVoiceNote?
    var attachments: [AttachmentItem] = []
    var selectedPlaceID: UUID?
    var selectedPlaceIDs: [UUID] = []
    var routineColor: RoutineTaskColor = .none
    var estimatedDurationMinutes: Int?
    var actualDurationMinutes: Int?
    var storyPoints: Int?
    var focusModeEnabled: Bool = false
}

struct AddRoutineOrganizationState: Equatable {
    var routineTags: [String] = []
    var routineGoals: [RoutineGoalSummary] = []
    var eventIDs: [UUID] = []
    var relationships: [RoutineTaskRelationship] = []
    var availableTags: [String] = []
    var availableTagSummaries: [RoutineTagSummary] = []
    var availableGoals: [RoutineGoalSummary] = []
    var availableEvents: [RoutineEventLinkCandidate] = []
    var relatedTagRules: [RoutineRelatedTagRule] = []
    var tagCounterDisplayMode: TagCounterDisplayMode = .defaultValue
    var availableRelationshipTasks: [RoutineTaskRelationshipCandidate] = []
    var tagDraft: String = ""
    var goalDraft: String = ""
    var existingRoutineNames: [String] = []
    var availablePlaces: [RoutinePlaceSummary] = []
    var nameValidationMessage: String?
}

struct AddRoutineScheduleState: Equatable {
    var scheduleMode: RoutineScheduleMode = .oneOff
    var frequency: AddRoutineFeature.Frequency = .day
    var frequencyValue: Int = 1
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
        trimmedRoutineName.isEmpty
            || organization.nameValidationMessage != nil
    }

    var requiresChecklistItems: Bool {
        schedule.scheduleMode.isRoutineModeRequiringChecklistItems
    }

    var candidateRecurrenceRule: RoutineRecurrenceRule {
        let fallbackInterval = schedule.scheduleMode.taskType != .routine
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
        case .routine:
            break
        case .todo:
            return .interval(
                days: 1,
                at: usesAvailabilityTiming && schedule.recurrenceHasExplicitTime ? schedule.recurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        case .record:
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

    var canAutoAssumeDailyDone: Bool {
        RoutineAssumedCompletion.isEligible(
            scheduleMode: schedule.scheduleMode,
            recurrenceRule: candidateRecurrenceRule,
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

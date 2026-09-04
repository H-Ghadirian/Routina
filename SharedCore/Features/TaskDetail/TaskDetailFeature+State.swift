import ComposableArchitecture
import Foundation

extension TaskDetailFeature {
    struct ChecklistItemsCache: Equatable {
        var storage: String = ""
        var items: [RoutineChecklistItem] = []

        static func == (_ lhs: ChecklistItemsCache, _ rhs: ChecklistItemsCache) -> Bool {
            true
        }
    }

    struct PendingManualCompletion: Equatable {
        var completedAt: Date
        var referenceDate: Date
        var previousTodoStateTitle: String?
        var targets: [RoutineTaskResolvedRelationship]
        var selectedTargetIDs: [UUID] = []
    }

    @ObservableState
    struct State: Equatable {
        var task: RoutineTask
        var taskRefreshID: UInt64 = 0
        @ObservationStateIgnored var checklistItemsCache = ChecklistItemsCache()
        var logs: [RoutineLog] = []
        var pendingLocalCompletionDates: [Date] = []
        var pendingLocalRemovalDates: [Date] = []
        var selectedDate: Date?
        var selectedOccurrenceDate: Date?
        var daysSinceLastRoutine: Int = 0
        var overdueDays: Int = 0
        var isDoneToday: Bool = false
        var isAssumedDoneToday: Bool = false
        var isEditSheetPresented: Bool = false
        var isAddDetailChooserPresented: Bool = false
        var editRoutineName: String = ""
        var editCustomTaskSectionID: UUID?
        var editRoutineEmoji: String = "✨"
        var editTaskDescription: String = ""
        var editRoutineNotes: String = ""
        var detailCommentDraft: String = ""
        var editingDetailCommentID: UUID?
        var editingDetailCommentDraft: String = ""
        var editRoutineLink: String = ""
        var editDeadline: Date?
        var editIsAllDay: Bool = false
        var editRoutineDurationMode: RoutineDurationMode = .oneDay
        var editAvailabilityStartDate: Date?
        var editAvailabilityEndDate: Date?
        var editPlannedDate: Date?
        var editReminderAt: Date?
        var editPriority: RoutineTaskPriority = .none
        var editImportance: RoutineTaskImportance = .level2
        var editUrgency: RoutineTaskUrgency = .level2
        var editPressure: RoutineTaskPressure = .none
        var editTemporalWeightRule: RoutineTaskTemporalWeightRule?
        var editTaskLadderEntryWindow: RoutineTaskLadderEntryWindow = .throughoutCycle
        var editThinkingNeeded: RoutineTaskThinkingNeeded = .none
        var editImageData: Data?
        var editVoiceNote: RoutineVoiceNote?
        var taskAttachments: [AttachmentItem] = []
        var editAttachments: [AttachmentItem] = []
        var editRoutineTags: [String] = []
        var editRoutineFlags: [String] = []
        var editRoutineGoals: [RoutineGoalSummary] = []
        var editEventIDs: [UUID] = []
        var editRelationships: [RoutineTaskRelationship] = []
        var editTagDraft: String = ""
        var editFlagDraft: String = ""
        var editGoalDraft: String = ""
        var editFlagSelectionValidationMessage: String?
        var editScheduleMode: RoutineScheduleMode = .fixedInterval
        var editRoutineSteps: [RoutineStep] = []
        var editStepDraft: String = ""
        var editRoutineChecklistItems: [RoutineChecklistItem] = []
        var editChecklistItemDraftTitle: String = ""
        var editChecklistItemDraftInterval: Int = 3
        var editChecklistValidationMessage: String?
        var availablePlaces: [RoutinePlaceSummary] = []
        var availableTags: [String] = []
        var availableFlags: [String] = []
        var flagRules: [RoutineFlagRule] = []
        var availableTagSummaries: [RoutineTagSummary] = []
        var availableGoals: [RoutineGoalSummary] = []
        var availableEvents: [RoutineEventLinkCandidate] = []
        var relatedTagRules: [RoutineRelatedTagRule] = []
        var availableRelationshipTasks: [RoutineTaskRelationshipCandidate] = []
        var editAvailableRelationshipTasks: [RoutineTaskRelationshipCandidate] = []
        /// Home provides this context from its loaded task snapshot before selecting a detail.
        /// Standalone detail presentations leave this `false` and load their own context.
        var hasPreloadedEditContext = false
        var tagCounterDisplayMode: TagCounterDisplayMode = .defaultValue
        var editSelectedPlaceID: UUID?
        var editSelectedPlaceIDs: [UUID] = []
        var editDestinationAddress: String = ""
        var editDestinationCoordinate: LocationCoordinate?
        var editFrequency: EditFrequency = .day
        var editFrequencyValue: Int = 1
        var editRecurrenceDraft: RoutineRecurrenceDraft = RoutineRecurrenceDraft(cadence: .none)
        var editRecurrenceDraftIsAuthoritative: Bool = false
        var editRecurrenceEditorMode: RoutineRecurrenceEditorMode = .simple
        var editAdvancedRecurrenceRule: RoutineAdvancedRecurrenceRule = RoutineAdvancedRecurrenceRule()
        var editRecurrenceKind: RoutineRecurrenceRule.Kind = .intervalDays
        var editRecurrenceHasExplicitTime: Bool = false
        var editRecurrenceHasTimeRange: Bool = false
        var editRecurrenceTimeRangeRole: RoutineTimeRangeRole = .availability
        var editRecurrenceTimeOfDay: RoutineTimeOfDay = .defaultValue
        var editRecurrenceTimeRangeStart: RoutineTimeOfDay = RoutineTimeRange.defaultValue.start
        var editRecurrenceTimeRangeEnd: RoutineTimeOfDay = RoutineTimeRange.defaultValue.end
        var editRecurrenceWeekday: Int = Calendar.current.component(.weekday, from: Date())
        var editRecurrenceWeekdays: [Int] = []
        var editRecurrenceDayOfMonth: Int = Calendar.current.component(.day, from: Date())
        var editRecurrenceDaysOfMonth: [Int] = []
        var editAutoAssumeDailyDone: Bool = false
        var editHidesAssumedDoneCalendarBlock: Bool = false
        var editAutoAssumeDoneTimeOfDay: RoutineTimeOfDay = RoutineAssumedCompletion.defaultDoneTimeOfDay
        var editEstimatedDurationMinutes: Int?
        var editActualDurationMinutes: Int?
        var editStoryPoints: Int?
        var editFocusModeEnabled: Bool = false
        var editCadenceEnabled: Bool = true
        var editAutoPauseAfterCompletion: Bool = false
        var editNudgesEnabled: Bool = true
        var taskLadderGroupHasChildren: Bool = false
        var editTaskLadderGroupEnabled: Bool = false
        var isDeleteConfirmationPresented: Bool = false
        var isUndoCompletionConfirmationPresented: Bool = false
        var isManualCompletionConfirmationPresented: Bool = false
        var pendingManualCompletion: PendingManualCompletion?
        var pendingLogRemovalTimestamp: Date?
        var shouldDismissAfterDelete: Bool = false
        var addLinkedTaskRelationshipKind: RoutineTaskRelationshipKind = .related
        var editColor: RoutineTaskColor = .none
        var isBlockedStateConfirmationPresented: Bool = false
        var hasLoadedNotificationStatus: Bool = false
        var appNotificationsEnabled: Bool = true
        var systemNotificationsAuthorized: Bool = true

        var candidateRecurrenceRule: RoutineRecurrenceRule {
            candidateRecurrenceDraft.resolvedRecurrenceRule()
                ?? legacyCandidateRecurrenceRule
        }

        var candidateRecurrenceDraft: RoutineRecurrenceDraft {
            recurrenceDraftForPersistence()
        }

        func recurrenceDraftForPersistence(
            calendar: Calendar = .current
        ) -> RoutineRecurrenceDraft {
            editRecurrenceDraftIsAuthoritative
                ? editRecurrenceDraft
                : legacyRecurrenceDraft(calendar: calendar)
        }

        mutating func synchronizeRecurrenceDraftFromLegacy() {
            editRecurrenceDraftIsAuthoritative = false
        }

        private var legacyCandidateRecurrenceRule: RoutineRecurrenceRule {
            let fallbackInterval =
                !editScheduleMode.usesRoutineCadence
                ? 1
                : TaskFormRecurrenceConstraints.effectiveIntervalDays(
                    value: editFrequencyValue,
                    unit: editFrequency,
                    scheduleMode: editScheduleMode,
                    routineDurationMode: editRoutineDurationMode,
                    recurrenceKind: editRecurrenceKind
                )
            let usesAvailabilityTiming = !editIsAllDay
            let timeRange = usesAvailabilityTiming ? editRecurrenceTimeRange : nil

            if !editScheduleMode.usesRoutineCadence {
                return .interval(
                    days: 1,
                    at: usesAvailabilityTiming && editRecurrenceHasExplicitTime ? editRecurrenceTimeOfDay : nil,
                    timeRange: timeRange
                )
            }

            guard !editScheduleMode.isChecklistDrivenMode else {
                return .interval(days: max(fallbackInterval, 1))
            }

            if editRecurrenceEditorMode == .advanced {
                return .advanced(
                    editAdvancedRecurrenceRule,
                    timeRange: timeRange
                )
            }

            switch editRecurrenceKind {
            case .intervalDays:
                return .interval(
                    days: max(fallbackInterval, 1),
                    at: usesAvailabilityTiming && editRecurrenceHasExplicitTime ? editRecurrenceTimeOfDay : nil,
                    timeRange: timeRange
                )
            case .dailyTime:
                if let timeRange {
                    return .daily(in: timeRange)
                }
                return RoutineRecurrenceRule(
                    kind: .dailyTime,
                    timeOfDay: usesAvailabilityTiming && editRecurrenceHasExplicitTime ? editRecurrenceTimeOfDay : nil
                )
            case .weekly:
                return .weekly(
                    on: effectiveEditRecurrenceWeekdays,
                    at: usesAvailabilityTiming && editRecurrenceHasExplicitTime ? editRecurrenceTimeOfDay : nil,
                    timeRange: timeRange
                )
            case .monthlyDay:
                return .monthly(
                    on: effectiveEditRecurrenceDaysOfMonth,
                    at: usesAvailabilityTiming && editRecurrenceHasExplicitTime ? editRecurrenceTimeOfDay : nil,
                    timeRange: timeRange
                )
            }
        }

        private func legacyRecurrenceDraft(
            calendar: Calendar
        ) -> RoutineRecurrenceDraft {
            let cadenceOverride: RoutineRecurrenceDraft.Cadence?
            let isCadenceDisabled = editScheduleMode.taskType != .todo && !editCadenceEnabled
            if !editScheduleMode.usesRoutineCadence {
                cadenceOverride = RoutineRecurrenceDraft.Cadence.none
            } else if isCadenceDisabled {
                cadenceOverride =
                    editAutoPauseAfterCompletion
                    ? .manual
                    : RoutineRecurrenceDraft.Cadence.none
            } else if editScheduleMode.isChecklistDrivenMode {
                cadenceOverride = .itemRunout
            } else {
                cadenceOverride = nil
            }

            let recurrenceRule = legacyCandidateRecurrenceRule
            let draft = RoutineRecurrenceDraft(
                recurrenceRule: recurrenceRule,
                cadence: cadenceOverride,
                timeRangeRole: editRecurrenceTimeRangeRole,
                calendar: calendar
            )
            return draft
        }

        var effectiveEditRecurrenceWeekdays: [Int] {
            let selectedWeekdays = Array(Set(editRecurrenceWeekdays.map { min(max($0, 1), 7) })).sorted()
            return selectedWeekdays.isEmpty ? [min(max(editRecurrenceWeekday, 1), 7)] : selectedWeekdays
        }

        var effectiveEditRecurrenceDaysOfMonth: [Int] {
            let selectedDays = Array(Set(editRecurrenceDaysOfMonth.map { min(max($0, 1), 31) })).sorted()
            return selectedDays.isEmpty ? [min(max(editRecurrenceDayOfMonth, 1), 31)] : selectedDays
        }

        var editRecurrenceTimeRange: RoutineTimeRange? {
            guard editRecurrenceHasTimeRange else { return nil }
            return RoutineTimeRange(
                start: editRecurrenceTimeRangeStart,
                end: editRecurrenceTimeRangeEnd
            )
        }

        var canAutoAssumeDailyDone: Bool {
            candidateRecurrenceDraft.validationIssue == nil
                && RoutineAssumedCompletion.canEnable(
                    scheduleMode: editScheduleMode,
                    recurrenceRule: candidateRecurrenceRule,
                    recurrenceTimeRangeRole: editRecurrenceTimeRangeRole,
                    availabilityStartDate: editAvailabilityStartDate,
                    availabilityEndDate: editAvailabilityEndDate,
                    isAllDay: editIsAllDay,
                    cadenceEnabled: editScheduleMode.taskType == .todo
                        ? true
                        : editCadenceEnabled,
                    hasSequentialSteps: !editRoutineSteps.isEmpty,
                    hasChecklistItems: !editRoutineChecklistItems.isEmpty
                )
        }

        var autoAssumeDoneUnavailableReason: String? {
            candidateRecurrenceDraft.validationIssue == nil
                ? RoutineAssumedCompletion.unavailableReason(
                    scheduleMode: editScheduleMode,
                    recurrenceRule: candidateRecurrenceRule,
                    recurrenceTimeRangeRole: editRecurrenceTimeRangeRole,
                    availabilityStartDate: editAvailabilityStartDate,
                    availabilityEndDate: editAvailabilityEndDate,
                    isAllDay: editIsAllDay,
                    cadenceEnabled: editScheduleMode.taskType == .todo
                        ? true
                        : editCadenceEnabled,
                    hasSequentialSteps: !editRoutineSteps.isEmpty,
                    hasChecklistItems: !editRoutineChecklistItems.isEmpty
                )
                : "Fix the recurrence before using this Flag."
        }

        var autoAssumeDoneEnabledByFlag: Bool {
            RoutineFlagRules.enablesAutoAssumeDone(
                flags: editRoutineFlags,
                rules: flagRules
            ) && autoAssumeDoneUnavailableReason == nil
        }

        var canAddDetailComment: Bool {
            RoutineTaskComment.sanitizedBody(detailCommentDraft) != nil
        }

        var canSaveEditingDetailComment: Bool {
            guard let editingDetailCommentID,
                let comment = task.comments.first(where: { $0.id == editingDetailCommentID }),
                let body = RoutineTaskComment.sanitizedBody(editingDetailCommentDraft)
            else {
                return false
            }
            return body != comment.body
        }

        var taskGoalSummaries: [RoutineGoalSummary] {
            let resolvedGoals = RoutineGoalSummary.summaries(
                for: task.goalIDs,
                in: availableGoals
            )
            if !resolvedGoals.isEmpty || task.goalIDs.isEmpty {
                return resolvedGoals
            }
            return RoutineGoalSummary.summaries(
                for: task.goalIDs,
                in: editRoutineGoals
            )
        }

        var taskEventCandidates: [RoutineEventLinkCandidate] {
            RoutineEventLinkCandidate.selectedCandidates(
                for: task.eventIDs,
                in: availableEvents
            )
        }
    }
}

import Foundation

struct TaskDetailEditSaveRequest: Equatable {
    var taskID: UUID
    var name: String
    var emoji: String
    var notes: String?
    var link: String?
    var links: [String]
    var linkItems: [RoutineTaskLink]
    var deadline: Date?
    var isAllDay: Bool
    var routineDurationMode: RoutineDurationMode
    var availabilityStartDate: Date?
    var availabilityEndDate: Date?
    var plannedDate: Date?
    var reminderAt: Date?
    var priority: RoutineTaskPriority
    var importance: RoutineTaskImportance
    var urgency: RoutineTaskUrgency
    var pressure: RoutineTaskPressure
    var imageData: Data?
    var voiceNote: RoutineVoiceNote?
    var attachments: [AttachmentItem]
    var placeID: UUID?
    var placeIDs: [UUID]
    var tags: [String]
    var goals: [RoutineGoalSummary]
    var eventIDs: [UUID]
    var relationships: [RoutineTaskRelationship]
    var steps: [RoutineStep]
    var checklistItems: [RoutineChecklistItem]
    var scheduleMode: RoutineScheduleMode
    var recurrenceRule: RoutineRecurrenceRule
    var color: RoutineTaskColor
    var autoAssumeDailyDone: Bool
    var estimatedDurationMinutes: Int?
    var actualDurationMinutes: Int?
    var storyPoints: Int?
    var focusModeEnabled: Bool
}

struct TaskDetailEditSaveRequestBuilder {
    let now: () -> Date
    let calendar: Calendar
    let matrixPriority: (RoutineTaskImportance, RoutineTaskUrgency) -> RoutineTaskPriority

    func build(state: inout TaskDetailFeature.State) -> TaskDetailEditSaveRequest? {
        state.editRoutineTags = RoutineTag.appending(
            state.editTagDraft,
            to: state.editRoutineTags,
            availableTags: state.availableTags
        )
        state.editTagDraft = ""
        state.editRoutineGoals = RoutineGoalSummary.appending(
            state.editGoalDraft,
            availableGoals: state.availableGoals,
            to: state.editRoutineGoals
        )
        state.editGoalDraft = ""
        state.editRoutineSteps = appendStep(from: state.editStepDraft, to: state.editRoutineSteps)
        state.editStepDraft = ""
        state.editRoutineChecklistItems = appendChecklistItem(
            from: state.editChecklistItemDraftTitle,
            intervalDays: state.editChecklistItemDraftInterval,
            createdAt: now(),
            to: state.editRoutineChecklistItems
        )
        state.editChecklistItemDraftTitle = ""
        state.editChecklistItemDraftInterval = 3

        let trimmedName = state.editRoutineName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let scheduleMode = effectiveScheduleMode(for: state)
        state.editChecklistValidationMessage = AddRoutineChecklistValidator.validationMessage(
            scheduleMode: scheduleMode,
            checklistItems: state.editRoutineChecklistItems,
            checklistItemDraftTitle: state.editChecklistItemDraftTitle
        )
        guard state.editChecklistValidationMessage == nil else {
            return nil
        }

        state.isEditSheetPresented = false

        let frequencyInterval = scheduleMode == .oneOff
            ? 1
            : TaskFormRecurrenceConstraints.effectiveIntervalDays(
                value: state.editFrequencyValue,
                unit: state.editFrequency,
                scheduleMode: scheduleMode,
                routineDurationMode: state.editRoutineDurationMode,
                recurrenceKind: state.editRecurrenceKind
            )
        let recurrenceRule = selectedRecurrenceRule(
            for: state,
            scheduleMode: scheduleMode,
            fallbackInterval: frequencyInterval
        )

        let sanitizedLinks = RoutineTask.sanitizedLinkItems(fromEditorText: state.editRoutineLink)

        let availabilityDateBounds = RoutineTask.normalizedAvailabilityDateBounds(
            startDate: state.editAvailabilityStartDate,
            endDate: state.editAvailabilityEndDate,
            calendar: calendar
        )
        let sanitizedChecklistItems = RoutineChecklistItem.sanitized(state.editRoutineChecklistItems)

        return TaskDetailEditSaveRequest(
            taskID: state.task.id,
            name: trimmedName,
            emoji: state.editRoutineEmoji,
            notes: RoutineTask.sanitizedNotes(state.editRoutineNotes),
            link: sanitizedLinks.first?.url,
            links: sanitizedLinks.map(\.url),
            linkItems: sanitizedLinks,
            deadline: scheduleMode == .oneOff ? state.editDeadline : nil,
            isAllDay: state.editIsAllDay,
            routineDurationMode: scheduleMode == .oneOff ? .oneDay : state.editRoutineDurationMode,
            availabilityStartDate: scheduleMode == .oneOff ? availabilityDateBounds.startDate : nil,
            availabilityEndDate: scheduleMode == .oneOff ? availabilityDateBounds.endDate : nil,
            plannedDate: RoutineTaskDailyRoutineSupport.isDailyRoutineForTaskList(
                scheduleMode: scheduleMode,
                recurrenceRule: recurrenceRule,
                checklistItems: sanitizedChecklistItems
            )
                ? nil
                : RoutineTask.normalizedPlannedDate(state.editPlannedDate, calendar: calendar),
            reminderAt: scheduleMode == .oneOff ? state.editReminderAt : nil,
            priority: matrixPriority(state.editImportance, state.editUrgency),
            importance: state.editImportance,
            urgency: state.editUrgency,
            pressure: state.editPressure,
            imageData: state.editImageData,
            voiceNote: state.editVoiceNote,
            attachments: state.editAttachments,
            placeID: state.editSelectedPlaceIDs.first,
            placeIDs: state.editSelectedPlaceIDs,
            tags: RoutineTag.deduplicated(state.editRoutineTags),
            goals: state.editRoutineGoals,
            eventIDs: RoutineEventIDStorage.sanitized(state.editEventIDs),
            relationships: state.editRelationships,
            steps: (scheduleMode.isStandardRoutineMode || scheduleMode == .oneOff)
                ? state.editRoutineSteps
                : [],
            checklistItems: sanitizedChecklistItems,
            scheduleMode: scheduleMode,
            recurrenceRule: recurrenceRule,
            color: state.editColor,
            autoAssumeDailyDone: state.editAutoAssumeDailyDone,
            estimatedDurationMinutes: state.editEstimatedDurationMinutes,
            actualDurationMinutes: state.editActualDurationMinutes,
            storyPoints: state.editStoryPoints,
            focusModeEnabled: state.editFocusModeEnabled
        )
    }

    private func selectedRecurrenceRule(
        for state: TaskDetailFeature.State,
        scheduleMode: RoutineScheduleMode,
        fallbackInterval: Int
    ) -> RoutineRecurrenceRule {
        let usesAvailabilityTiming = !state.editIsAllDay
        let timeRange = usesAvailabilityTiming ? state.editRecurrenceTimeRange : nil

        guard scheduleMode != .oneOff else {
            return .interval(
                days: 1,
                at: usesAvailabilityTiming && state.editRecurrenceHasExplicitTime ? state.editRecurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        }

        guard !scheduleMode.isChecklistDrivenMode else {
            return .interval(days: max(fallbackInterval, 1))
        }

        switch state.editRecurrenceKind {
        case .intervalDays:
            return .interval(
                days: max(fallbackInterval, 1),
                at: usesAvailabilityTiming && state.editRecurrenceHasExplicitTime ? state.editRecurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        case .dailyTime:
            if let timeRange {
                return .daily(in: timeRange)
            }
            return RoutineRecurrenceRule(
                kind: .dailyTime,
                timeOfDay: usesAvailabilityTiming && state.editRecurrenceHasExplicitTime ? state.editRecurrenceTimeOfDay : nil
            )
        case .weekly:
            return .weekly(
                on: state.editRecurrenceWeekday,
                at: usesAvailabilityTiming && state.editRecurrenceHasExplicitTime ? state.editRecurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        case .monthlyDay:
            return .monthly(
                on: state.editRecurrenceDayOfMonth,
                at: usesAvailabilityTiming && state.editRecurrenceHasExplicitTime ? state.editRecurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        }
    }

    private func appendStep(
        from draft: String,
        to currentSteps: [RoutineStep]
    ) -> [RoutineStep] {
        guard let title = RoutineStep.normalizedTitle(draft) else { return currentSteps }
        return currentSteps + [RoutineStep(title: title)]
    }

    private func appendChecklistItem(
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

    private func scheduleModeRequiresChecklistItems(_ scheduleMode: RoutineScheduleMode) -> Bool {
        scheduleMode.isRoutineModeRequiringChecklistItems
    }

    private func effectiveScheduleMode(for state: TaskDetailFeature.State) -> RoutineScheduleMode {
        guard scheduleModeRequiresChecklistItems(state.editScheduleMode),
              state.editRoutineChecklistItems.isEmpty,
              !state.task.checklistItems.isEmpty else {
            return state.editScheduleMode
        }
        return RoutineScheduleMode.routineMode(
            behavior: state.editScheduleMode.scheduleBehavior,
            format: .standard
        )
    }
}

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
    var recurrenceTimeRangeRole: RoutineTimeRangeRole
    var color: RoutineTaskColor
    var autoAssumeDailyDone: Bool
    var autoAssumeDoneTimeOfDay: RoutineTimeOfDay?
    var estimatedDurationMinutes: Int?
    var actualDurationMinutes: Int?
    var storyPoints: Int?
    var focusModeEnabled: Bool
    var trackingCadenceEnabled: Bool
    var trackingNudgesEnabled: Bool
}

struct TaskDetailEditSaveRequestBuilder {
    let now: () -> Date
    let calendar: Calendar
    let matrixPriority: (RoutineTaskImportance, RoutineTaskUrgency) -> RoutineTaskPriority

    func build(state: inout TaskDetailFeature.State) -> TaskDetailEditSaveRequest? {
        let hadChecklistDraft = RoutineChecklistItem.normalizedTitle(
            state.editChecklistItemDraftTitle
        ) != nil

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
            intervalDays: state.editScheduleMode.normalizedChecklistItemIntervalDays(state.editChecklistItemDraftInterval),
            createdAt: now(),
            to: state.editRoutineChecklistItems
        )
        state.editChecklistItemDraftTitle = ""
        if hadChecklistDraft {
            state.editChecklistItemDraftInterval = state.editScheduleMode.storesChecklistItemIntervals ? 3 : 1
        }

        let trimmedName = state.editRoutineName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let candidateChecklistItems = RoutineChecklistItem.sanitized(state.editRoutineChecklistItems)
        let scheduleMode = effectiveScheduleMode(for: state, checklistItems: candidateChecklistItems)
        let sanitizedChecklistItems = RoutineChecklistItem.sanitized(candidateChecklistItems, for: scheduleMode)
        state.editRoutineChecklistItems = sanitizedChecklistItems
        state.editChecklistValidationMessage = AddRoutineChecklistValidator.validationMessage(
            scheduleMode: scheduleMode,
            checklistItems: sanitizedChecklistItems,
            checklistItemDraftTitle: state.editChecklistItemDraftTitle
        )
        guard state.editChecklistValidationMessage == nil else {
            return nil
        }

        state.isEditSheetPresented = false

        let trackingCadenceEnabled = scheduleMode.taskType == .record
            ? state.editTrackingCadenceEnabled
            : true
        let frequencyInterval = !scheduleMode.usesRoutineCadence || !trackingCadenceEnabled
            ? 1
            : TaskFormRecurrenceConstraints.effectiveIntervalDays(
                value: state.editFrequencyValue,
                unit: state.editFrequency,
                scheduleMode: scheduleMode,
                routineDurationMode: state.editRoutineDurationMode,
                recurrenceKind: state.editRecurrenceKind
            )
        let recurrenceRule = trackingCadenceEnabled
            ? selectedRecurrenceRule(
                for: state,
                scheduleMode: scheduleMode,
                fallbackInterval: frequencyInterval
            )
            : .interval(days: 1)

        let sanitizedLinks = RoutineTask.sanitizedLinkItems(fromEditorText: state.editRoutineLink)

        let availabilityDateBounds = RoutineTask.normalizedAvailabilityDateBounds(
            startDate: state.editAvailabilityStartDate,
            endDate: state.editAvailabilityEndDate,
            calendar: calendar
        )

        return TaskDetailEditSaveRequest(
            taskID: state.task.id,
            name: trimmedName,
            emoji: state.editRoutineEmoji,
            notes: RoutineTask.sanitizedNotes(state.editRoutineNotes),
            link: sanitizedLinks.first?.url,
            links: sanitizedLinks.map(\.url),
            linkItems: sanitizedLinks,
            deadline: scheduleMode.taskType == .todo ? state.editDeadline : nil,
            isAllDay: state.editIsAllDay,
            routineDurationMode: scheduleMode.taskType == .todo ? .oneDay : state.editRoutineDurationMode,
            availabilityStartDate: scheduleMode.taskType == .todo ? availabilityDateBounds.startDate : nil,
            availabilityEndDate: scheduleMode.taskType == .todo ? availabilityDateBounds.endDate : nil,
            plannedDate: !trackingCadenceEnabled || RoutineTaskDailyRoutineSupport.isDailyRoutineForTaskList(
                    scheduleMode: scheduleMode,
                    recurrenceRule: recurrenceRule,
                    checklistItems: sanitizedChecklistItems
                )
                ? nil
                : RoutineTask.normalizedPlannedDate(state.editPlannedDate, calendar: calendar),
            reminderAt: scheduleMode.taskType == .todo ? state.editReminderAt : nil,
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
            steps: (scheduleMode.isStandardRoutineMode || scheduleMode == .oneOff || scheduleMode == .record)
                ? state.editRoutineSteps
                : [],
            checklistItems: sanitizedChecklistItems,
            scheduleMode: scheduleMode,
            recurrenceRule: recurrenceRule,
            recurrenceTimeRangeRole: recurrenceRule.timeRange == nil
                ? .availability
                : state.editRecurrenceTimeRangeRole,
            color: state.editColor,
            autoAssumeDailyDone: state.editAutoAssumeDailyDone,
            autoAssumeDoneTimeOfDay: state.editAutoAssumeDailyDone
                ? state.editAutoAssumeDoneTimeOfDay
                : nil,
            estimatedDurationMinutes: state.editEstimatedDurationMinutes,
            actualDurationMinutes: state.editActualDurationMinutes,
            storyPoints: state.editStoryPoints,
            focusModeEnabled: state.editFocusModeEnabled,
            trackingCadenceEnabled: trackingCadenceEnabled,
            trackingNudgesEnabled: scheduleMode.taskType == .record
                ? trackingCadenceEnabled && state.editTrackingNudgesEnabled
                : true
        )
    }

    private func selectedRecurrenceRule(
        for state: TaskDetailFeature.State,
        scheduleMode: RoutineScheduleMode,
        fallbackInterval: Int
    ) -> RoutineRecurrenceRule {
        let usesAvailabilityTiming = !state.editIsAllDay
        let timeRange = usesAvailabilityTiming ? state.editRecurrenceTimeRange : nil

        switch scheduleMode.taskType {
        case .todo:
            return .interval(
                days: 1,
                at: usesAvailabilityTiming && state.editRecurrenceHasExplicitTime ? state.editRecurrenceTimeOfDay : nil,
                timeRange: timeRange
            )
        case .routine, .record:
            break
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
                on: state.effectiveEditRecurrenceWeekdays,
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

    private func effectiveScheduleMode(
        for state: TaskDetailFeature.State,
        checklistItems: [RoutineChecklistItem]
    ) -> RoutineScheduleMode {
        TaskDetailRoutineChecklistModeNormalizer.effectiveScheduleMode(
            currentMode: state.editScheduleMode,
            existingChecklistItems: state.task.checklistItems,
            candidateChecklistItems: checklistItems,
            candidateSteps: state.editRoutineSteps
        )
    }
}

extension TaskDetailFeature {
    func applyEditSaveRequest(
        _ request: TaskDetailEditSaveRequest,
        to state: inout State
    ) {
        let previousScheduleMode = state.task.scheduleMode
        let previousRecurrenceRule = state.task.recurrenceRule
        let previousRollingScheduleAnchor = state.task.scheduleAnchor ?? state.task.lastDone
        let previousCreatedAt = state.task.createdAt
        let updatedTask = state.task.detachedCopy()

        updatedTask.name = request.name
        updatedTask.emoji = request.emoji
        updatedTask.notes = CalendarTaskImportSupport.notesPreservingCalendarMarkers(
            visibleNotes: request.notes,
            existingNotes: updatedTask.notes
        )
        updatedTask.linkItems = request.linkItems.isEmpty
            ? (
                request.links.isEmpty
                    ? request.link.map { [RoutineTaskLink(title: nil, url: $0)] } ?? []
                    : request.links.map { RoutineTaskLink(title: nil, url: $0) }
            )
            : request.linkItems
        updatedTask.reminderAt = request.reminderAt
        updatedTask.priority = request.priority
        updatedTask.importance = request.importance
        updatedTask.urgency = request.urgency
        updatedTask.pressure = request.pressure
        updatedTask.color = request.color
        updatedTask.imageData = request.imageData
        updatedTask.voiceNote = request.voiceNote
        updatedTask.placeIDs = RoutinePlaceIDStorage.sanitized(
            request.placeIDs.isEmpty ? request.placeID.map { [$0] } ?? [] : request.placeIDs
        )
        updatedTask.tags = request.tags
        updatedTask.goalIDs = RoutineGoalIDStorage.sanitized(request.goals.map(\.id))
        updatedTask.eventIDs = RoutineEventIDStorage.sanitized(request.eventIDs)
        updatedTask.replaceRelationships(request.relationships)
        updatedTask.replaceSteps(request.steps)
        updatedTask.scheduleMode = request.scheduleMode
        updatedTask.deadline = request.scheduleMode.taskType == .todo ? request.deadline : nil
        updatedTask.isAllDay = request.isAllDay
        updatedTask.routineDurationMode = request.scheduleMode.taskType == .todo
            ? .oneDay
            : request.routineDurationMode
        updatedTask.availabilityStartDate = request.scheduleMode.taskType == .todo
            ? request.availabilityStartDate
            : nil
        updatedTask.availabilityEndDate = request.scheduleMode.taskType == .todo
            ? request.availabilityEndDate
            : nil
        updatedTask.plannedDate = RoutineTask.normalizedPlannedDate(request.plannedDate, calendar: calendar)
        updatedTask.recurrenceRule = request.recurrenceRule
        updatedTask.recurrenceTimeRangeRole = request.recurrenceRule.timeRange == nil
            ? .availability
            : request.recurrenceTimeRangeRole
        updatedTask.replaceChecklistItems(request.checklistItems)
        if !updatedTask.usesOngoingLifecycle {
            updatedTask.activityState = .idle
            updatedTask.ongoingSince = nil
        }
        updatedTask.autoAssumeDailyDone = request.autoAssumeDailyDone
            && RoutineAssumedCompletion.isEligible(
                scheduleMode: request.scheduleMode,
                recurrenceRule: request.recurrenceRule,
                trackingCadenceEnabled: request.trackingCadenceEnabled,
                hasSequentialSteps: !request.steps.isEmpty,
                hasChecklistItems: !request.checklistItems.isEmpty
            )
        updatedTask.autoAssumeDoneTimeOfDay = updatedTask.autoAssumeDailyDone
            ? (request.autoAssumeDoneTimeOfDay ?? RoutineAssumedCompletion.defaultDoneTimeOfDay)
            : nil
        updatedTask.estimatedDurationMinutes = RoutineTask.sanitizedEstimatedDurationMinutes(
            request.estimatedDurationMinutes
        )
        updatedTask.actualDurationMinutes = request.scheduleMode.taskType == .todo
            || request.scheduleMode.taskType == .record
            ? RoutineTask.sanitizedActualDurationMinutes(request.actualDurationMinutes)
            : nil
        updatedTask.storyPoints = RoutineTask.sanitizedStoryPoints(request.storyPoints)
        updatedTask.focusModeEnabled = request.focusModeEnabled
        updatedTask.trackingCadenceEnabled = request.scheduleMode.taskType == .record
            ? request.trackingCadenceEnabled
            : true
        updatedTask.trackingNudgesEnabled = request.scheduleMode.taskType == .record
            ? request.trackingCadenceEnabled && request.trackingNudgesEnabled
            : true

        if !request.scheduleMode.usesRoutineCadence || !updatedTask.trackingCadenceEnabled {
            updatedTask.scheduleAnchor = updatedTask.lastDone
            updatedTask.interval = 1
        } else if previousScheduleMode != request.scheduleMode || previousRecurrenceRule != request.recurrenceRule {
            updatedTask.interval = Int16(clamping: request.recurrenceRule.approximateIntervalDays)
            if previousScheduleMode != .oneOff,
               previousRecurrenceRule.kind == .intervalDays,
               request.recurrenceRule.kind == .intervalDays,
               let previousRollingScheduleAnchor {
                updatedTask.scheduleAnchor = previousRollingScheduleAnchor
            } else {
                updatedTask.scheduleAnchor = now
            }
        } else if updatedTask.scheduleAnchor == nil, let existingAnchor = updatedTask.lastDone ?? updatedTask.createdAt {
            updatedTask.interval = Int16(clamping: request.recurrenceRule.approximateIntervalDays)
            updatedTask.scheduleAnchor = existingAnchor
        } else {
            updatedTask.interval = Int16(clamping: request.recurrenceRule.approximateIntervalDays)
        }

        updatedTask.createdAt = previousCreatedAt
        state.task = updatedTask
        state.taskAttachments = request.attachments
        state.editAttachments = request.attachments
        updateDerivedState(&state)
    }
}

enum TaskDetailRoutineChecklistModeNormalizer {
    static func effectiveScheduleMode(
        currentMode: RoutineScheduleMode,
        existingChecklistItems: [RoutineChecklistItem],
        candidateChecklistItems: [RoutineChecklistItem],
        candidateSteps: [RoutineStep]
    ) -> RoutineScheduleMode {
        if currentMode.usesRoutineCadence,
           currentMode.routineFormat == .standard,
           existingChecklistItems.isEmpty,
           !candidateChecklistItems.isEmpty,
           candidateSteps.isEmpty {
            if currentMode.taskType == .record {
                return .recordChecklist
            }
            return RoutineScheduleMode.routineMode(
                behavior: currentMode.scheduleBehavior,
                format: .checklist
            )
        }

        if currentMode.isRoutineModeRequiringChecklistItems,
           candidateChecklistItems.isEmpty,
           !existingChecklistItems.isEmpty {
            if currentMode.taskType == .record {
                return .record
            }
            return RoutineScheduleMode.routineMode(
                behavior: currentMode.scheduleBehavior,
                format: .standard
            )
        }

        return currentMode
    }
}

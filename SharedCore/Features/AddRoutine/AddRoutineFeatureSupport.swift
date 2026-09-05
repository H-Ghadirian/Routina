import Foundation

extension AddRoutineFeature {
    func scheduleMutationHandler() -> AddRoutineScheduleMutationHandler {
        AddRoutineScheduleMutationHandler(now: { now })
    }

    func organizationMutationHandler() -> AddRoutineOrganizationMutationHandler {
        AddRoutineOrganizationMutationHandler()
    }

    func supportsPlanning(_ state: State) -> Bool {
        RoutineTaskPlanningSupport.supportsStoredPlanning(
            scheduleMode: state.schedule.scheduleMode,
            recurrenceRule: state.candidateRecurrenceRule,
            checklistItems: state.candidateChecklistItems,
            cadenceEnabled: state.schedule.scheduleMode.taskType == .todo
                ? true
                : state.basics.cadenceEnabled
        )
    }

    func enforcePlanningRules(state: inout State) {
        if !supportsPlanning(state) {
            state.basics.plannedDate = nil
            return
        }
        guard state.schedule.scheduleMode == .oneOff,
            let availabilityStartDate = state.basics.availabilityStartDate,
            state.basics.availabilityEndDate == nil
        else { return }
        state.basics.plannedDate = calendar.startOfDay(for: availabilityStartDate)
    }

    func enforceRecurrenceConstraints(state: inout State) {
        if state.basics.routineDurationMode == .multiDay,
            state.schedule.recurrenceKind == .dailyTime
        {
            state.schedule.recurrenceKind = .intervalDays
        }
        state.schedule.frequencyValue = TaskFormRecurrenceConstraints.clampedFrequencyValue(
            state.schedule.frequencyValue,
            scheduleMode: state.schedule.scheduleMode,
            routineDurationMode: state.basics.routineDurationMode,
            recurrenceKind: state.schedule.recurrenceKind,
            frequencyUnit: state.schedule.frequency
        )
    }

    func sanitizeTemporalWeightRule(state: inout State) {
        guard let rule = state.basics.temporalWeightRule else { return }
        guard
            RoutineTaskTemporalWeightResolver.supportsTemporalWeight(
                scheduleMode: state.schedule.scheduleMode,
                cadenceEnabled: state.schedule.scheduleMode.taskType == .todo
                    ? true
                    : state.basics.cadenceEnabled
            )
        else {
            state.basics.temporalWeightRule = nil
            return
        }
        state.basics.temporalWeightRule = rule.sanitized(
            baseImportance: state.basics.importance,
            baseUrgency: state.basics.urgency,
            basePressure: state.basics.pressure,
            maximumBeforeDueDays: state.candidateRecurrenceDraft.maximumTemporalWeightBeforeDueDays
        )
    }

    func sanitizeTaskLadderEntryWindow(state: inout State) {
        state.basics.taskLadderEntryWindow = RoutineTaskLadderEntryResolver.sanitizedWindow(
            state.basics.taskLadderEntryWindow,
            scheduleMode: state.schedule.scheduleMode,
            cadenceEnabled: state.schedule.scheduleMode.taskType == .todo
                ? true
                : state.basics.cadenceEnabled,
            hasDeadline: state.basics.deadline != nil,
            maximumBeforeDueDays: state.schedule.scheduleMode.taskType == .todo
                ? nil
                : state.candidateRecurrenceDraft.maximumTemporalWeightBeforeDueDays
        )
    }

    func addDraftFlag(state: inout State) {
        let flags = RoutineFlag.parseDraft(state.organization.flagDraft)
        state.organization.flagDraft = ""
        for flag in flags {
            toggleFlagSelection(flag, state: &state)
        }
    }

    func toggleFlagSelection(_ flag: String, state: inout State) {
        if RoutineFlag.contains(flag, in: state.organization.routineFlags) {
            organizationMutationHandler().removeFlag(flag, state: &state)
            state.organization.flagSelectionValidationMessage = nil
            return
        }

        if RoutineFlagRules.contains(.autoAssumeDone, for: flag, in: state.organization.flagRules),
            let reason = state.autoAssumeDoneUnavailableReason
        {
            state.organization.flagSelectionValidationMessage =
                "\(flag) was not added. \(reason) \(RoutineAssumedCompletion.flagRuleAvailabilitySummary)"
            return
        }
        organizationMutationHandler().toggleFlagSelection(flag, state: &state)
        state.organization.flagSelectionValidationMessage = nil
    }

    func scheduleCreationDraftAutosave(for state: State) {
        let snapshot = AddRoutineDraftSnapshot(state: state)
        creationDraftClient.scheduleSave(.task) {
            guard snapshot.isMeaningful else { return .clear }
            guard let rawValue = CreationDraftPersistence.encodedRawValue(snapshot) else {
                return .none
            }
            return .save(rawValue)
        }
    }

    func applyQuickAddDraftFromName(state: inout State) {
        guard
            let draft = RoutinaQuickAddParser.parse(
                state.basics.routineName,
                referenceDate: now,
                calendar: calendar,
                includingPlaces: SharedDefaults.app[.appSettingPlacesEnabled]
            ),
            draft.hasDetectedMetadata
        else {
            return
        }

        AddRoutineValidationEditor.setRoutineName(draft.name, state: &state)

        if !draft.linkItems.isEmpty {
            AddRoutineBasicsEditor.setLink(
                RoutineTask.linkEditorText(for: draft.linkItems),
                basics: &state.basics
            )
        }

        if draft.hasDetectedSchedule {
            applyQuickAddSchedule(from: draft, state: &state)
        }

        state.organization.routineTags = RoutineTag.merging(
            draft.tags,
            into: state.organization.routineTags,
            availableTags: state.organization.availableTags
        )

        if SharedDefaults.app[.appSettingPlacesEnabled],
            let placeID = matchingPlaceID(
                named: draft.placeName,
                in: state.organization.availablePlaces
            )
        {
            AddRoutineFormEditor.setSelectedPlace(placeID, basics: &state.basics)
        }

        if draft.hasExplicitPriority {
            state.basics.importance = draft.importance
            state.basics.urgency = draft.urgency
            state.basics.priority = AddRoutinePriorityMatrix.priority(
                importance: draft.importance,
                urgency: draft.urgency
            )
        }

        if let estimatedDurationMinutes = draft.estimatedDurationMinutes {
            AddRoutineBasicsEditor.setEstimatedDurationMinutes(
                estimatedDurationMinutes,
                basics: &state.basics
            )
            state.basics.focusModeEnabled = draft.focusModeEnabled
        }
    }

    func applyQuickAddSchedule(
        from draft: RoutinaQuickAddDraft,
        state: inout State
    ) {
        scheduleMutationHandler().setScheduleMode(draft.scheduleMode, state: &state)
        applyFrequency(days: draft.frequencyInDays, state: &state)

        if draft.scheduleMode == .oneOff {
            state.basics.deadline = draft.deadline
            state.basics.reminderAt = draft.reminderAt
            state.basics.availabilityStartDate = draft.availabilityStartDate
            state.basics.availabilityEndDate = draft.availabilityEndDate
            applyTimeConstraint(from: draft.recurrenceRule, state: &state)
            enforcePlanningRules(state: &state)
            return
        }

        state.basics.deadline = nil
        state.basics.reminderAt = nil
        state.basics.availabilityStartDate = nil
        state.basics.availabilityEndDate = nil

        let recurrenceRule = draft.recurrenceRule
        if let advanced = recurrenceRule.advanced {
            scheduleMutationHandler().setRecurrenceEditorMode(.advanced, state: &state)
            scheduleMutationHandler().setAdvancedRecurrenceRule(advanced, state: &state)
            applyTimeConstraint(from: recurrenceRule, state: &state)
            return
        }
        scheduleMutationHandler().setRecurrenceEditorMode(.simple, state: &state)
        scheduleMutationHandler().setRecurrenceKind(recurrenceRule.kind, state: &state)

        switch recurrenceRule.kind {
        case .intervalDays:
            applyTimeConstraint(from: recurrenceRule, state: &state)
        case .dailyTime:
            applyTimeConstraint(from: recurrenceRule, state: &state)
        case .weekly:
            scheduleMutationHandler().setRecurrenceWeekdays(
                recurrenceRule.resolvedWeekdays(calendar: calendar),
                state: &state
            )
            applyTimeConstraint(from: recurrenceRule, state: &state)
        case .monthlyDay:
            scheduleMutationHandler().setRecurrenceDaysOfMonth(
                recurrenceRule.resolvedDaysOfMonth(calendar: calendar),
                state: &state
            )
            applyTimeConstraint(from: recurrenceRule, state: &state)
        }
    }

    func applyFrequency(days: Int, state: inout State) {
        let safeDays = max(days, 1)
        if safeDays.isMultiple(of: 30) {
            scheduleMutationHandler().setFrequency(.month, state: &state)
            scheduleMutationHandler().setFrequencyValue(max(safeDays / 30, 1), state: &state)
        } else if safeDays.isMultiple(of: 7) {
            scheduleMutationHandler().setFrequency(.week, state: &state)
            scheduleMutationHandler().setFrequencyValue(max(safeDays / 7, 1), state: &state)
        } else {
            scheduleMutationHandler().setFrequency(.day, state: &state)
            scheduleMutationHandler().setFrequencyValue(safeDays, state: &state)
        }
    }

    func applyTimeConstraint(
        from recurrenceRule: RoutineRecurrenceRule,
        state: inout State
    ) {
        if let timeRange = recurrenceRule.timeRange {
            scheduleMutationHandler().setRecurrenceHasTimeRange(true, state: &state)
            scheduleMutationHandler().setRecurrenceTimeRangeStart(timeRange.start, state: &state)
            scheduleMutationHandler().setRecurrenceTimeRangeEnd(timeRange.end, state: &state)
        } else if let timeOfDay = recurrenceRule.timeOfDay {
            scheduleMutationHandler().setRecurrenceHasExplicitTime(true, state: &state)
            scheduleMutationHandler().setRecurrenceTimeOfDay(timeOfDay, state: &state)
        } else {
            scheduleMutationHandler().setRecurrenceHasExplicitTime(false, state: &state)
            scheduleMutationHandler().setRecurrenceHasTimeRange(false, state: &state)
        }
    }

    func reminderEventDate(for state: State) -> Date? {
        TaskFormReminderLeadTime.eventDate(
            scheduleMode: state.schedule.scheduleMode,
            deadline: state.basics.deadline,
            recurrenceRule: state.candidateRecurrenceRule,
            availabilityStartDate: state.basics.availabilityStartDate,
            availabilityEndDate: state.basics.availabilityEndDate,
            referenceDate: now,
            calendar: calendar
        )
    }

    func matchingPlaceID(
        named placeName: String?,
        in places: [RoutinePlaceSummary]
    ) -> UUID? {
        guard
            let placeName,
            let normalizedName = RoutinePlace.normalizedName(placeName)
        else {
            return nil
        }

        return places.first { place in
            RoutinePlace.normalizedName(place.name) == normalizedName
        }?.id
    }
}

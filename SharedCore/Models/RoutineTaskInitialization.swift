import Foundation

extension RoutineTask {
    func initializeIdentity(
        _ id: UUID,
        _ name: String?,
        _ emoji: String?,
        _ taskDescription: String?,
        _ notes: String?,
        _ link: String?,
        _ links: [String]
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.taskDescription = Self.sanitizedDescription(taskDescription)
        self.notes = Self.sanitizedNotes(notes)
        let sanitizedLinks = RoutineTaskLinkStorage.sanitizedItems(
            links.isEmpty
                ? link.map { [RoutineTaskLink(title: nil, url: $0)] } ?? []
                : links.map { RoutineTaskLink(title: nil, url: $0) }
        )
        self.link = sanitizedLinks.first?.url
        linksStorage = RoutineTaskLinkStorage.serializeItems(sanitizedLinks)
    }

    func initializePlanning(
        _ deadline: Date?,
        _ plannedDate: Date?,
        _ customTaskSectionID: UUID?,
        _ isAllDay: Bool,
        _ routineDurationMode: RoutineDurationMode,
        _ scheduleMode: RoutineScheduleMode
    ) {
        self.deadline = scheduleMode == .oneOff ? deadline : nil
        self.plannedDate = plannedDate
        customTaskSectionIDRawValue = customTaskSectionID?.uuidString.lowercased()
        self.isAllDay = isAllDay
        routineDurationModeRawValue =
            scheduleMode.taskType == .todo
            ? RoutineDurationMode.oneDay.rawValue
            : routineDurationMode.rawValue
    }

    func initializeAvailability(
        _ startDate: Date?,
        _ endDate: Date?,
        _ reminderAt: Date?,
        _ scheduleMode: RoutineScheduleMode
    ) {
        availabilityStartDate = scheduleMode == .oneOff ? startDate : nil
        availabilityEndDate = scheduleMode == .oneOff ? endDate : nil
        self.reminderAt = reminderAt
    }

    func initializePriorities(
        _ priority: RoutineTaskPriority,
        _ importance: RoutineTaskImportance,
        _ urgency: RoutineTaskUrgency,
        _ pressure: RoutineTaskPressure,
        _ pressureUpdatedAt: Date?,
        _ thinkingNeeded: RoutineTaskThinkingNeeded
    ) {
        priorityRawValue = priority.rawValue
        importanceRawValue = importance.rawValue
        urgencyRawValue = urgency.rawValue
        pressureRawValue = pressure.rawValue
        self.pressureUpdatedAt = pressure == .none ? nil : pressureUpdatedAt
        thinkingNeededRawValue = thinkingNeeded.rawValue
    }

    func initializeMedia(
        _ imageData: Data?,
        _ voiceNoteData: Data?,
        _ voiceNoteDurationSeconds: Double?,
        _ voiceNoteCreatedAt: Date?
    ) {
        self.imageData = imageData
        let sanitizedVoiceNote = RoutineVoiceNote(
            data: voiceNoteData,
            durationSeconds: voiceNoteDurationSeconds,
            createdAt: voiceNoteCreatedAt
        )
        self.voiceNoteData = sanitizedVoiceNote?.data
        self.voiceNoteDurationSeconds = sanitizedVoiceNote?.durationSeconds
        self.voiceNoteCreatedAt = sanitizedVoiceNote?.createdAt
    }

    func initializePlaces(
        _ placeID: UUID?,
        _ placeIDs: [UUID],
        _ destinationAddress: String?,
        _ destinationLatitude: Double?,
        _ destinationLongitude: Double?
    ) {
        let resolvedPlaceIDs = RoutinePlaceIDStorage.sanitized(
            placeIDs.isEmpty ? placeID.map { [$0] } ?? [] : placeIDs
        )
        self.placeID = resolvedPlaceIDs.first
        placeIDsStorage = RoutinePlaceIDStorage.serialize(resolvedPlaceIDs)
        self.destinationAddress = Self.sanitizedDestinationAddress(destinationAddress)
        if let coordinate = Self.sanitizedDestinationCoordinate(
            latitude: destinationLatitude,
            longitude: destinationLongitude
        ) {
            self.destinationLatitude = coordinate.latitude
            self.destinationLongitude = coordinate.longitude
        } else {
            self.destinationLatitude = nil
            self.destinationLongitude = nil
        }
    }

    func initializeLabels(
        _ tags: [String],
        _ flags: [String],
        _ goalIDs: [UUID],
        _ eventIDs: [UUID]
    ) {
        tagsStorage = RoutineTag.serialize(tags)
        flagsStorage = RoutineFlag.serialize(flags)
        goalIDsStorage = RoutineGoalIDStorage.serialize(goalIDs)
        eventIDsStorage = RoutineEventIDStorage.serialize(eventIDs)
    }

    func initializeStructure(
        _ relationships: [RoutineTaskRelationship],
        _ steps: [RoutineStep],
        _ checklistItems: [RoutineChecklistItem],
        _ id: UUID,
        _ scheduleMode: RoutineScheduleMode
    ) {
        relationshipsStorage = RoutineTaskRelationshipStorage.serialize(relationships, ownerID: id)
        stepsStorage = RoutineStepStorage.serialize(steps)
        scheduleModeRawValue = scheduleMode.rawValue
        checklistItemsStorage = RoutineChecklistItemStorage.serialize(
            RoutineChecklistItem.sanitized(checklistItems, for: scheduleMode)
        )
    }

    func initializeRecurrence(
        _ recurrenceRule: RoutineRecurrenceRule,
        _ timeRangeRole: RoutineTimeRangeRole,
        _ scheduleMode: RoutineScheduleMode,
        _ cadenceEnabled: Bool
    ) {
        storeRecurrenceRuleInColumns(recurrenceRule)
        recurrenceTimeRangeRole = recurrenceRule.timeRange == nil ? .availability : timeRangeRole
        interval = Int16(
            clamping: scheduleMode.usesRoutineCadence && cadenceEnabled
                ? recurrenceRule.approximateIntervalDays
                : 1
        )
    }

    func initializeCompletion(
        _ lastDone: Date?,
        _ lastSatisfiedScheduledOccurrenceAt: Date?,
        _ canceledAt: Date?,
        _ scheduleAnchor: Date?,
        _ scheduleMode: RoutineScheduleMode,
        _ cadenceEnabled: Bool
    ) {
        self.lastDone = lastDone
        self.lastSatisfiedScheduledOccurrenceAt = lastSatisfiedScheduledOccurrenceAt
        self.canceledAt = scheduleMode == .oneOff ? canceledAt : nil
        self.scheduleAnchor =
            scheduleMode == .oneOff || !cadenceEnabled
            ? lastDone
            : (scheduleAnchor ?? lastDone)
    }

    func initializeAvailabilityState(
        _ pausedAt: Date?,
        _ pauseUntil: Date?,
        _ snoozedUntil: Date?,
        _ pinnedAt: Date?
    ) {
        self.pausedAt = pausedAt
        self.pauseUntil = pauseUntil
        self.snoozedUntil = snoozedUntil
        self.pinnedAt = pinnedAt
    }

    func initializeRanking(
        _ temporalWeightRule: RoutineTaskTemporalWeightRule?,
        _ entryWindow: RoutineTaskLadderEntryWindow,
        _ recurrenceRule: RoutineRecurrenceRule,
        _ scheduleMode: RoutineScheduleMode,
        _ cadenceEnabled: Bool,
        _ deadline: Date?
    ) {
        manualSectionOrderStorage = ""
        taskRankingOrderStorage = ""
        let maximumBeforeDueDays = RoutineTaskTemporalWeightResolver.maximumBeforeDueDays(
            for: recurrenceRule
        )
        let sanitizedEntryWindow = RoutineTaskLadderEntryResolver.sanitizedWindow(
            entryWindow,
            scheduleMode: scheduleMode,
            cadenceEnabled: cadenceEnabled,
            hasDeadline: scheduleMode == .oneOff && deadline != nil,
            maximumBeforeDueDays: scheduleMode.taskType == .todo ? nil : maximumBeforeDueDays
        )
        temporalWeightRuleStorage = RoutineTaskLadderConfigurationStorage.serialize(
            RoutineTaskLadderConfiguration(
                temporalWeightRule: RoutineTaskTemporalWeightResolver.sanitizedRule(
                    temporalWeightRule,
                    scheduleMode: scheduleMode,
                    cadenceEnabled: cadenceEnabled,
                    importance: importance,
                    urgency: urgency,
                    pressure: pressure,
                    maximumBeforeDueDays: maximumBeforeDueDays
                ),
                entryLeadDays: sanitizedEntryWindow.storageLeadDays
            )
        )
    }

    func initializeProgress(
        _ completedStepCount: Int16,
        _ sequenceStartedAt: Date?,
        _ color: RoutineTaskColor,
        _ createdAt: Date?
    ) {
        self.completedStepCount = Int16(max(Int(completedStepCount), 0))
        self.sequenceStartedAt = sequenceStartedAt
        colorRawValue = color.rawValue
        self.createdAt = createdAt
    }

    func initializeActivity(
        _ todoStateRawValue: String?,
        _ activityStateRawValue: String?,
        _ ongoingSince: Date?
    ) {
        self.todoStateRawValue = todoStateRawValue
        self.activityStateRawValue =
            RoutineActivityState(
                rawValue: activityStateRawValue ?? ""
            )?.rawValue ?? RoutineActivityState.idle.rawValue
        self.ongoingSince = ongoingSince
    }

    func initializeAssumptions(
        _ autoAssumeDailyDone: Bool,
        _ hidesAssumedDoneCalendarBlock: Bool,
        _ autoAssumeDoneTimeOfDay: RoutineTimeOfDay?
    ) {
        self.autoAssumeDailyDone = autoAssumeDailyDone
        self.hidesAssumedDoneCalendarBlock = autoAssumeDailyDone && hidesAssumedDoneCalendarBlock
        self.autoAssumeDoneTimeOfDay = autoAssumeDailyDone ? autoAssumeDoneTimeOfDay : nil
    }

    func initializeMetrics(
        _ estimatedDurationMinutes: Int?,
        _ actualDurationMinutes: Int?,
        _ storyPoints: Int?,
        _ taskChoiceTieBreakScore: Double,
        _ taskChoiceComparisonCount: Int16
    ) {
        self.estimatedDurationMinutes = Self.sanitizedEstimatedDurationMinutes(estimatedDurationMinutes)
        self.actualDurationMinutes = Self.sanitizedActualDurationMinutes(actualDurationMinutes)
        self.storyPoints = Self.sanitizedStoryPoints(storyPoints)
        self.taskChoiceTieBreakScore =
            taskChoiceTieBreakScore.isFinite
            ? max(taskChoiceTieBreakScore, 0)
            : 0
        self.taskChoiceComparisonCount = max(taskChoiceComparisonCount, 0)
    }

    func initializeBehavior(
        _ focusModeEnabled: Bool,
        _ cadenceEnabled: Bool,
        _ autoPauseAfterCompletion: Bool,
        _ nudgesEnabled: Bool,
        _ scheduleMode: RoutineScheduleMode
    ) {
        self.focusModeEnabled = focusModeEnabled
        self.cadenceEnabled = cadenceEnabled
        self.autoPauseAfterCompletion =
            scheduleMode.taskType != .todo
            && !cadenceEnabled
            && autoPauseAfterCompletion
        self.nudgesEnabled =
            scheduleMode.usesRoutineCadence
            ? cadenceEnabled && nudgesEnabled
            : true
    }

    func initializeDetailPreferences(
        _ showsTaskDetailHeatmap: Bool,
        _ showsTaskDetailHistory: Bool,
        _ isTaskDetailCalendarExpanded: Bool,
        _ hasExplicitImportance: Bool,
        _ hasExplicitUrgency: Bool,
        _ comments: [RoutineTaskComment]
    ) {
        self.showsTaskDetailHeatmap = showsTaskDetailHeatmap
        self.showsTaskDetailHistory = showsTaskDetailHistory
        self.isTaskDetailCalendarExpanded = isTaskDetailCalendarExpanded
        self.hasExplicitImportance = hasExplicitImportance
        self.hasExplicitUrgency = hasExplicitUrgency
        commentsStorage = RoutineTaskCommentStorage.serialize(comments)
    }

    func initializeChangeLog(
        _ createdAt: Date?,
        _ relationships: [RoutineTaskRelationship],
        _ id: UUID
    ) {
        var initialChanges = [
            RoutineTaskChangeLogEntry(
                timestamp: createdAt ?? Date(),
                kind: .created
            )
        ]
        initialChanges.append(
            contentsOf: RoutineTaskRelationship.sanitized(relationships, ownerID: id).map {
                RoutineTaskChangeLogEntry(
                    timestamp: createdAt ?? Date(),
                    kind: .linkedTaskAdded,
                    relatedTaskID: $0.targetTaskID,
                    relationshipKind: $0.kind
                )
            }
        )
        changeLogStorage = RoutineTaskChangeLogStorage.serialize(initialChanges)
    }

    func normalizeInitialProgress() {
        if steps.isEmpty || Int(completedStepCount) > steps.count {
            resetStepProgress()
        }
        sanitizeChecklistProgress()
    }
}

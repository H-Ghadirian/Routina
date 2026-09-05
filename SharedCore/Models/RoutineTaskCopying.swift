import Foundation

extension RoutineTask {
    func detachedCopy() -> RoutineTask {
        let copy = RoutineTask(
            id: id,
            name: name,
            emoji: emoji,
            taskDescription: taskDescription,
            notes: notes,
            link: link,
            links: links,
            deadline: deadline,
            plannedDate: plannedDate,
            customTaskSectionID: customTaskSectionID,
            isAllDay: isAllDay,
            routineDurationMode: routineDurationMode,
            availabilityStartDate: availabilityStartDate,
            availabilityEndDate: availabilityEndDate,
            reminderAt: reminderAt,
            priority: priority,
            importance: importance,
            urgency: urgency,
            pressure: pressure,
            pressureUpdatedAt: pressureUpdatedAt,
            thinkingNeeded: thinkingNeeded,
            imageData: imageData,
            voiceNoteData: voiceNoteData,
            voiceNoteDurationSeconds: voiceNoteDurationSeconds,
            voiceNoteCreatedAt: voiceNoteCreatedAt,
            placeID: placeID,
            placeIDs: placeIDs,
            destinationAddress: destinationAddress,
            destinationLatitude: destinationLatitude,
            destinationLongitude: destinationLongitude,
            tags: tags,
            flags: flags,
            goalIDs: goalIDs,
            eventIDs: eventIDs,
            relationships: relationships,
            steps: steps,
            checklistItems: checklistItems,
            scheduleMode: scheduleMode,
            interval: interval,
            recurrenceRule: recurrenceRule,
            recurrenceTimeRangeRole: recurrenceTimeRangeRole,
            lastDone: lastDone,
            lastSatisfiedScheduledOccurrenceAt: lastSatisfiedScheduledOccurrenceAt,
            canceledAt: canceledAt,
            scheduleAnchor: scheduleAnchor,
            pausedAt: pausedAt,
            pauseUntil: pauseUntil,
            snoozedUntil: snoozedUntil,
            pinnedAt: pinnedAt,
            completedStepCount: completedStepCount,
            sequenceStartedAt: sequenceStartedAt,
            color: color,
            createdAt: createdAt,
            todoStateRawValue: todoStateRawValue,
            activityStateRawValue: activityStateRawValue,
            ongoingSince: ongoingSince,
            autoAssumeDailyDone: autoAssumeDailyDone,
            hidesAssumedDoneCalendarBlock: hidesAssumedDoneCalendarBlock,
            autoAssumeDoneTimeOfDay: autoAssumeDoneTimeOfDay,
            estimatedDurationMinutes: estimatedDurationMinutes,
            actualDurationMinutes: actualDurationMinutes,
            storyPoints: storyPoints,
            taskChoiceTieBreakScore: taskChoiceTieBreakScore,
            taskChoiceComparisonCount: taskChoiceComparisonCount,
            focusModeEnabled: focusModeEnabled,
            cadenceEnabled: cadenceEnabled,
            autoPauseAfterCompletion: autoPauseAfterCompletion,
            nudgesEnabled: nudgesEnabled,
            showsTaskDetailHeatmap: showsTaskDetailHeatmap,
            showsTaskDetailHistory: showsTaskDetailHistory,
            isTaskDetailCalendarExpanded: isTaskDetailCalendarExpanded,
            hasExplicitImportance: hasExplicitImportance,
            hasExplicitUrgency: hasExplicitUrgency,
            comments: comments
        )
        copyDetachedState(to: copy)
        return copy
    }

    private func copyDetachedState(to copy: RoutineTask) {
        copy.completedChecklistItemIDsStorage = completedChecklistItemIDsStorage
        copy.completedChecklistProgressStartedAt = completedChecklistProgressStartedAt
        copy.manualSectionOrderStorage = manualSectionOrderStorage
        copy.taskRankingOrderStorage = taskRankingOrderStorage
        copy.temporalWeightRuleStorage = temporalWeightRuleStorage
        copy.linkItems = linkItems
        copy.commentsStorage = commentsStorage
        copy.changeLogStorage = changeLogStorage
        copy.scheduleAnchor = scheduleAnchor
    }

    func appendChangeLogEntry(_ entry: RoutineTaskChangeLogEntry) {
        changeLogEntries = [entry] + changeLogEntries
    }
}

extension RoutineTask: Equatable {
    static func == (lhs: RoutineTask, rhs: RoutineTask) -> Bool {
        lhs.id == rhs.id
    }
}

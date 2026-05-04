import Foundation

struct TaskDetailEditSaveRequest: Equatable {
    var taskID: UUID
    var name: String
    var emoji: String
    var notes: String?
    var link: String?
    var deadline: Date?
    var reminderAt: Date?
    var priority: RoutineTaskPriority
    var importance: RoutineTaskImportance
    var urgency: RoutineTaskUrgency
    var pressure: RoutineTaskPressure
    var imageData: Data?
    var attachments: [AttachmentItem]
    var placeID: UUID?
    var tags: [String]
    var goals: [RoutineGoalSummary]
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
    let matrixPriority: (RoutineTaskImportance, RoutineTaskUrgency) -> RoutineTaskPriority

    func build(state: inout TaskDetailFeature.State) -> TaskDetailEditSaveRequest? {
        state.editRoutineTags = RoutineTag.appending(state.editTagDraft, to: state.editRoutineTags)
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
        guard !scheduleModeRequiresChecklistItems(state.editScheduleMode) || !state.editRoutineChecklistItems.isEmpty else {
            return nil
        }

        state.isEditSheetPresented = false

        let frequencyInterval = state.editScheduleMode == .oneOff
            ? 1
            : state.editFrequencyValue * state.editFrequency.daysMultiplier
        let recurrenceRule = selectedRecurrenceRule(
            for: state,
            fallbackInterval: frequencyInterval
        )

        return TaskDetailEditSaveRequest(
            taskID: state.task.id,
            name: trimmedName,
            emoji: state.editRoutineEmoji,
            notes: RoutineTask.sanitizedNotes(state.editRoutineNotes),
            link: RoutineTask.sanitizedLink(state.editRoutineLink),
            deadline: state.editScheduleMode == .oneOff ? state.editDeadline : nil,
            reminderAt: state.editReminderAt,
            priority: matrixPriority(state.editImportance, state.editUrgency),
            importance: state.editImportance,
            urgency: state.editUrgency,
            pressure: state.editPressure,
            imageData: state.editImageData,
            attachments: state.editAttachments,
            placeID: state.editSelectedPlaceID,
            tags: state.editRoutineTags,
            goals: state.editRoutineGoals,
            relationships: state.editRelationships,
            steps: (state.editScheduleMode == .fixedInterval || state.editScheduleMode == .oneOff)
                ? state.editRoutineSteps
                : [],
            checklistItems: (state.editScheduleMode == .fixedInterval || state.editScheduleMode == .oneOff)
                ? []
                : state.editRoutineChecklistItems,
            scheduleMode: state.editScheduleMode,
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
        fallbackInterval: Int
    ) -> RoutineRecurrenceRule {
        guard state.editScheduleMode != .oneOff else {
            return .interval(days: 1)
        }

        guard state.editScheduleMode != .softInterval else {
            return .interval(days: max(fallbackInterval, 1))
        }

        guard state.editScheduleMode != .derivedFromChecklist else {
            return .interval(days: max(fallbackInterval, 1))
        }

        switch state.editRecurrenceKind {
        case .intervalDays:
            return .interval(days: max(fallbackInterval, 1))
        case .dailyTime:
            return .daily(at: state.editRecurrenceTimeOfDay)
        case .weekly:
            return .weekly(
                on: state.editRecurrenceWeekday,
                at: state.editRecurrenceHasExplicitTime ? state.editRecurrenceTimeOfDay : nil
            )
        case .monthlyDay:
            return .monthly(
                on: state.editRecurrenceDayOfMonth,
                at: state.editRecurrenceHasExplicitTime ? state.editRecurrenceTimeOfDay : nil
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
        scheduleMode == .fixedIntervalChecklist || scheduleMode == .derivedFromChecklist
    }
}

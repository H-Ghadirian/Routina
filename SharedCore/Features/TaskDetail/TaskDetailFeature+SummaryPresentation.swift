import Foundation

extension TaskDetailFeature.State {
    var summaryStatusTitle: String {
        summaryStatusTitle(daysUntilDueIfActive: daysUntilDueIfActive)
    }

    func summaryStatusTitle(daysUntilDueIfActive: Int?) -> String {
        let overdueDays = self.overdueDays
        let daysSinceLastRoutine = self.daysSinceLastRoutine
        let isDoneToday = self.isDoneToday

        if let title = pausedOrSnoozedSummaryStatusTitle() {
            return title
        }
        if let title = ongoingSummaryStatusTitle() {
            return title
        }
        if task.isOneOffTask {
            return oneOffSummaryStatusTitle(isDoneToday: isDoneToday)
        }
        if isChecklistCompletionFromStoredItems {
            return checklistCompletionSummaryStatusTitle(
                daysUntilDueIfActive: daysUntilDueIfActive,
                overdueDays: overdueDays,
                daysSinceLastRoutine: daysSinceLastRoutine,
                isDoneToday: isDoneToday
            )
        }
        if isChecklistDrivenFromStoredItems {
            return checklistDrivenSummaryStatusTitle(
                daysUntilDueIfActive: daysUntilDueIfActive,
                overdueDays: overdueDays,
                daysSinceLastRoutine: daysSinceLastRoutine,
                isDoneToday: isDoneToday
            )
        }
        if task.isSoftIntervalRoutine {
            return softIntervalSummaryStatusTitle(
                daysSinceLastRoutine: daysSinceLastRoutine,
                isDoneToday: isDoneToday
            )
        }
        return routineSummaryStatusTitle(
            daysUntilDueIfActive: daysUntilDueIfActive,
            overdueDays: overdueDays,
            daysSinceLastRoutine: daysSinceLastRoutine,
            isDoneToday: isDoneToday
        )
    }

    private func pausedOrSnoozedSummaryStatusTitle() -> String? {
        if let snoozedUntil = task.isSnoozed() ? task.snoozedUntil : nil {
            return "Not today. Back on \(snoozedUntil.formatted(date: .abbreviated, time: .omitted))"
        }
        guard task.isPaused(), let pausedAt = task.pausedAt else { return nil }
        if let pauseUntil = task.pauseUntil {
            return "Paused until \(pauseUntil.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Paused since \(pausedAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private func ongoingSummaryStatusTitle() -> String? {
        guard task.usesOngoingLifecycle && task.isOngoing else { return nil }
        if let ongoingSince = task.ongoingSince {
            let prefix = task.isMultiDayRoutine ? "In progress" : "Ongoing"
            return "\(prefix) since \(ongoingSince.formatted(date: .abbreviated, time: .omitted))"
        }
        return task.isMultiDayRoutine ? "In progress" : "Ongoing"
    }

    private func oneOffSummaryStatusTitle(isDoneToday: Bool) -> String {
        if task.isInProgress {
            return "Step \(task.completedSteps + 1) of \(task.totalSteps) in progress"
        }
        if let canceledAt = task.canceledAt {
            if Calendar.current.isDateInToday(canceledAt) {
                return "Canceled today"
            }
            return "Canceled on \(canceledAt.formatted(date: .abbreviated, time: .omitted))"
        }
        if let lastDone = task.lastDone {
            if isDoneToday {
                return "Completed today"
            }
            return "Completed on \(lastDone.formatted(date: .abbreviated, time: .omitted))"
        }
        return "To do"
    }

    private func checklistCompletionSummaryStatusTitle(
        daysUntilDueIfActive: Int?,
        overdueDays: Int,
        daysSinceLastRoutine: Int,
        isDoneToday: Bool
    ) -> String {
        if isDoneToday {
            return "Done today"
        }
        if isAssumedDoneToday {
            return "Assumed done today"
        }
        if isChecklistInProgress(referenceDate: resolvedSelectedDate) {
            return "Checklist \(completedChecklistItemCount(referenceDate: resolvedSelectedDate)) of \(totalChecklistItemCount) in progress"
        }
        if missedExactTimedOccurrenceDate != nil {
            return "Missed"
        }
        if overdueDays > 0 {
            return "Overdue by \(overdueDays) \(Self.dayWord(overdueDays))"
        }
        guard let daysUntilDue = daysUntilDueIfActive else {
            return "\(daysSinceLastRoutine) \(Self.dayWord(daysSinceLastRoutine)) since last done"
        }
        if daysUntilDue == 0 {
            return "Due today"
        }
        if daysUntilDue > 0 {
            return "Due in \(daysUntilDue) \(Self.dayWord(daysUntilDue))"
        }
        return "Overdue by \(-daysUntilDue) \(Self.dayWord(-daysUntilDue))"
    }

    private func checklistDrivenSummaryStatusTitle(
        daysUntilDueIfActive: Int?,
        overdueDays: Int,
        daysSinceLastRoutine: Int,
        isDoneToday: Bool
    ) -> String {
        if overdueDays > 0 {
            return "Overdue by \(overdueDays) \(Self.dayWord(overdueDays))"
        }
        if let daysUntilDue = daysUntilDueIfActive {
            if daysUntilDue == 0 {
                return "Due today"
            }
            if daysUntilDue > 0 {
                return "Due in \(daysUntilDue) \(Self.dayWord(daysUntilDue))"
            }
        }
        if isDoneToday {
            return "Updated today"
        }
        return "\(daysSinceLastRoutine) \(Self.dayWord(daysSinceLastRoutine)) since last update"
    }

    private func softIntervalSummaryStatusTitle(
        daysSinceLastRoutine: Int,
        isDoneToday: Bool
    ) -> String {
        if isDoneToday {
            return "Done today"
        }
        guard latestRecordedCompletion != nil else { return "Ready whenever" }
        if daysSinceLastRoutine == 1 {
            return "1 day since last time"
        }
        if daysSinceLastRoutine < 14 {
            return "\(daysSinceLastRoutine) days since last time"
        }
        if daysSinceLastRoutine < 60 {
            let weeks = max(daysSinceLastRoutine / 7, 1)
            return weeks == 1 ? "1 week since last time" : "\(weeks) weeks since last time"
        }
        let months = max(daysSinceLastRoutine / 30, 1)
        return months == 1 ? "1 month since last time" : "\(months) months since last time"
    }

    private func routineSummaryStatusTitle(
        daysUntilDueIfActive: Int?,
        overdueDays: Int,
        daysSinceLastRoutine: Int,
        isDoneToday: Bool
    ) -> String {
        if task.isInProgress {
            return "Step \(task.completedSteps + 1) of \(task.totalSteps) in progress"
        }
        if isDoneToday {
            return "Done today"
        }
        if isAssumedDoneToday {
            return "Assumed done today"
        }
        if missedOccurrenceReviewPresentation != nil {
            return "Needs review"
        }
        if overdueDays > 0 {
            return "Overdue by \(overdueDays) \(Self.dayWord(overdueDays))"
        }
        guard let daysUntilDue = daysUntilDueIfActive else {
            return "\(daysSinceLastRoutine) \(Self.dayWord(daysSinceLastRoutine)) since last done"
        }
        if daysUntilDue == 0 {
            return "Due today"
        }
        if daysUntilDue > 0 {
            return "Due in \(daysUntilDue) \(Self.dayWord(daysUntilDue))"
        }
        return "Overdue by \(-daysUntilDue) \(Self.dayWord(-daysUntilDue))"
    }

    var completionButtonTitle: String {
        TaskDetailCompletionButtonTitlePresentation(
            task: task,
            selectedDate: resolvedSelectedDate,
            isSelectedDateTerminal: isSelectedDateTerminal,
            isSelectedDateInFuture: isSelectedDateInFuture,
            isSelectedDateAssumedDone: isSelectedDateAssumedDone,
            completionTargetDate: completionTargetDate,
            isChecklistDriven: isChecklistDrivenFromStoredItems,
            isChecklistCompletionRoutine: isChecklistCompletionFromStoredItems,
            blocksManualCompletionForIncompleteChecklist: blocksManualCompletionForIncompleteChecklist,
            dueChecklistItems: dueChecklistItems(referenceDate: resolvedSelectedDate),
            hasUnresolvedMissedExactTimedOccurrence: missedExactTimedOccurrenceDate != nil
        ).title
    }

    var createdAtBadgeValue: String? {
        guard let created = task.createdAt else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let createdDay = calendar.startOfDay(for: created)
        let days = calendar.dateComponents([.day], from: createdDay, to: today).day ?? 0
        let dateText = created.formatted(date: .abbreviated, time: .omitted)
        if days == 0 {
            return "\(dateText) · Today"
        }
        return "\(dateText) · \(days) \(Self.dayWord(days)) ago"
    }

    /// Days until the task is due, or nil if the task is archived for now.
    var daysUntilDueIfActive: Int? {
        guard !task.isArchived() else { return nil }
        guard !task.isSoftIntervalRoutine else { return nil }
        guard task.isOneOffTask || task.usesEffectiveRoutineCadence else { return nil }
        return RoutineDateMath.daysUntilDue(for: task, referenceDate: Date())
    }

    static func dayWord(_ count: Int) -> String {
        abs(count) == 1 ? "day" : "days"
    }
}

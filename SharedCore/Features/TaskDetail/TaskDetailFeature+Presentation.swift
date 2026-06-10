import Foundation

// Derived, view-facing state computed from `TaskDetailFeature.State`.
// Keep pure (no SwiftUI types) so these can be exercised from tests and used
// by any platform view via `store.<property>` dynamic member lookup.
extension TaskDetailFeature.State {
    /// Resolves the optional `selectedDate` to a concrete start-of-day value.
    var resolvedSelectedDate: Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: selectedDate ?? Date())
    }

    var selectedScheduledOccurrenceDate: Date? {
        RoutineDateMath.scheduledOccurrence(
            for: task,
            on: resolvedSelectedDate,
            calendar: .current
        )
    }

    var completionTargetDate: Date? {
        RoutineDateMath.completionTargetDate(
            for: task,
            selectedDay: resolvedSelectedDate,
            referenceDate: Date(),
            calendar: .current
        )
    }

    var missedExactTimedOccurrenceDate: Date? {
        RoutineDateMath.unresolvedMissedExactTimedOccurrenceDate(
            for: task,
            referenceDate: Date(),
            logs: logs
        )
    }

    var isSelectedDateDone: Bool {
        let calendar = Calendar.current
        let day = resolvedSelectedDate
        if RoutineDateMath.usesExactTimedOccurrenceTracking(for: task) {
            guard let occurrence = selectedScheduledOccurrenceDate else { return false }
            return logs.contains {
                guard let timestamp = $0.timestamp else { return false }
                return $0.kind == .completed && calendar.isDate(timestamp, inSameDayAs: occurrence)
            }
            || task.lastDone.map { calendar.isDate($0, inSameDayAs: occurrence) } == true
        }
        return logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            return $0.kind == .completed && calendar.isDate(timestamp, inSameDayAs: day)
        }
        || task.lastDone.map { calendar.isDate($0, inSameDayAs: day) } == true
    }

    var isSelectedDateCanceled: Bool {
        let calendar = Calendar.current
        let day = resolvedSelectedDate
        if RoutineDateMath.usesExactTimedOccurrenceTracking(for: task) {
            guard let occurrence = selectedScheduledOccurrenceDate else { return false }
            return logs.contains {
                guard let timestamp = $0.timestamp else { return false }
                return $0.kind == .canceled && calendar.isDate(timestamp, inSameDayAs: occurrence)
            }
            || task.canceledAt.map { calendar.isDate($0, inSameDayAs: occurrence) } == true
        }
        return logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            return $0.kind == .canceled && calendar.isDate(timestamp, inSameDayAs: day)
        }
        || task.canceledAt.map { calendar.isDate($0, inSameDayAs: day) } == true
    }

    var isSelectedDateTerminal: Bool {
        isSelectedDateDone || isSelectedDateCanceled
    }

    var isSelectedDateAssumedDone: Bool {
        !isSelectedDateTerminal && RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: resolvedSelectedDate,
            logs: logs
        )
    }

    var pastAssumedDates: [Date] {
        RoutineAssumedCompletion.pastAssumedDates(for: task, logs: logs)
    }

    var confirmableAssumedDates: [Date] {
        RoutineAssumedCompletion.assumedDates(for: task, logs: logs)
    }

    var shouldUseBulkConfirmAsPrimaryAction: Bool {
        !task.isArchived()
            && Calendar.current.isDateInToday(resolvedSelectedDate)
            && isSelectedDateAssumedDone
            && !pastAssumedDates.isEmpty
    }

    var shouldShowBulkConfirmAssumedDays: Bool {
        !task.isArchived() && !pastAssumedDates.isEmpty && !shouldUseBulkConfirmAsPrimaryAction
    }

    var bulkConfirmAssumedDaysTitle: String {
        let count = confirmableAssumedDates.count
        return count == 1 ? "Confirm 1 assumed day" : "Confirm \(count) assumed days"
    }

    var completedLogCount: Int {
        logs.filter { $0.kind == .completed }.count
    }

    var canceledLogCount: Int {
        logs.filter { $0.kind == .canceled }.count
    }

    var checklistDueItemCount: Int {
        task.dueChecklistItems(referenceDate: Date()).count
    }

    var isSelectedDateInFuture: Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: resolvedSelectedDate) > calendar.startOfDay(for: Date())
    }

    var isStepRoutineOffToday: Bool {
        task.hasSequentialSteps && !Calendar.current.isDateInToday(resolvedSelectedDate)
    }

    var linkedPlaceSummary: RoutinePlaceSummary? {
        guard let placeID = task.placeIDs.first else { return nil }
        return availablePlaces.first(where: { $0.id == placeID })
    }

    var resolvedRelationships: [RoutineTaskResolvedRelationship] {
        RoutineTask.resolvedRelationships(for: task, within: availableRelationshipTasks)
    }

    var groupedResolvedRelationships: [(kind: RoutineTaskRelationshipKind, items: [RoutineTaskResolvedRelationship])] {
        let grouped = Dictionary(grouping: resolvedRelationships, by: \.kind)
        return RoutineTaskRelationshipKind.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { kind in
                guard let items = grouped[kind], !items.isEmpty else { return nil }
                return (kind: kind, items: items)
            }
    }

    var blockingRelationships: [RoutineTaskResolvedRelationship] {
        resolvedRelationships.filter { $0.kind == .blockedBy }
    }

    /// True when at least one `.blockedBy` relationship target is not yet done/canceled.
    var hasActiveRelationshipBlocker: Bool {
        blockingRelationships.contains { rel in
            rel.status != .doneToday && rel.status != .completedOneOff && rel.status != .canceledOneOff
        }
    }

    var blockerSummaryText: String {
        if hasActiveRelationshipBlocker {
            let count = blockingRelationships.filter { rel in
                rel.status != .doneToday && rel.status != .completedOneOff && rel.status != .canceledOneOff
            }.count
            if count == 1, let blocker = blockingRelationships.first(where: { rel in
                rel.status != .doneToday && rel.status != .completedOneOff && rel.status != .canceledOneOff
            }) {
                return "Blocked by \"\(blocker.taskName)\". Complete that task first."
            }
            return "Blocked by \(count) incomplete tasks. Complete them first."
        }
        let count = blockingRelationships.count
        if count == 1, let blocker = blockingRelationships.first {
            return "Blocked by \(blocker.taskName). You can still mark this done, but it may be worth checking that task first."
        }
        return "Blocked by \(count) tasks. You can still mark this done, but it may be worth checking them first."
    }

    var canUndoSelectedDate: Bool {
        !task.isChecklistDriven && isSelectedDateTerminal
    }

    var completionButtonAction: TaskDetailFeature.Action {
        if canUndoSelectedDate {
            return .requestUndoSelectedDateCompletion
        }
        if task.isSoftIntervalRoutine && task.isOngoing {
            return .finishOngoingTapped
        }
        if shouldUseBulkConfirmAsPrimaryAction {
            return .confirmAssumedPastDays
        }
        return .markAsDone
    }

    var completionButtonSystemImage: String? {
        canUndoSelectedDate ? "arrow.uturn.backward" : nil
    }

    var isCompletionButtonDisabled: Bool {
        guard !canUndoSelectedDate else { return false }
        if task.isSoftIntervalRoutine && task.isOngoing {
            return false
        }
        if task.isCompletedOneOff || task.isCanceledOneOff {
            return true
        }
        if task.isOneOffTask && hasActiveRelationshipBlocker {
            return true
        }
        if task.blocksManualCompletionForIncompleteChecklist {
            return true
        }
        if task.isChecklistCompletionRoutine {
            return true
        }
        if task.isChecklistDriven {
            return task.isArchived()
                || !Calendar.current.isDateInToday(resolvedSelectedDate)
                || checklistDueItemCount == 0
        }
        if RoutineDateMath.usesExactTimedOccurrenceTracking(for: task) {
            guard let completionTargetDate else { return true }
            return task.isArchived() || completionTargetDate > Date() || isStepRoutineOffToday
        }
        return isSelectedDateInFuture || task.isArchived() || isStepRoutineOffToday
    }

    /// Due date resolved from the task (one-off deadline or next recurrence).
    var resolvedDueDate: Date? {
        if task.isSoftIntervalRoutine {
            return nil
        }
        if task.isOneOffTask {
            return task.deadline ?? task.availabilityStartDate
        }
        return RoutineDateMath.upcomingDueDate(for: task, referenceDate: Date())
    }

    /// Soft routines use a threshold date instead of a hard overdue date.
    var resolvedSoftDueDate: Date? {
        RoutineDateMath.softIntervalThresholdDate(for: task)
    }

    var dueDateMetadataText: String? {
        TaskDetailDateMetadataPresentation.dueDateMetadataText(
            dueDate: resolvedDueDate,
            isOneOffTask: task.isOneOffTask,
            usesExplicitTimeOfDay: task.recurrenceRule.usesTimeConstraint
        )
    }

    var reminderMetadataText: String? {
        guard task.isOneOffTask else { return nil }
        return TaskDetailDateMetadataPresentation.reminderMetadataText(reminderAt: task.reminderAt)
    }

    var notificationDisabledWarningText: String? {
        TaskDetailNotificationWarningPresentation.warningText(
            hasLoadedNotificationStatus: hasLoadedNotificationStatus,
            expectsClockTimeNotification: expectsClockTimeNotification,
            appNotificationsEnabled: appNotificationsEnabled,
            systemNotificationsAuthorized: systemNotificationsAuthorized
        )
    }

    var notificationDisabledWarningActionTitle: String? {
        TaskDetailNotificationWarningPresentation.actionTitle(
            warningText: notificationDisabledWarningText,
            appNotificationsEnabled: appNotificationsEnabled
        )
    }

    var expectsClockTimeNotification: Bool {
        if task.isOneOffTask, task.reminderAt != nil {
            return NotificationCoordinator.shouldScheduleNotification(for: task, referenceDate: Date())
        }
        if task.isOneOffTask {
            return NotificationCoordinator.shouldScheduleNotification(for: task, referenceDate: Date())
        }
        guard task.recurrenceRule.usesTimeConstraint else { return false }
        return NotificationCoordinator.shouldScheduleNotification(for: task, referenceDate: Date())
    }

    var shouldShowSelectedDateMetadata: Bool {
        TaskDetailDateMetadataPresentation.shouldShowSelectedDateMetadata(
            selectedDate: resolvedSelectedDate,
            task: task
        )
    }

    var selectedDateMetadataText: String {
        TaskDetailDateMetadataPresentation.selectedDateMetadataText(selectedDate: resolvedSelectedDate)
    }

    var cancelTodoButtonTitle: String {
        TaskDetailDateMetadataPresentation.cancelTodoButtonTitle(selectedDate: resolvedSelectedDate)
    }

    var isCancelTodoButtonDisabled: Bool {
        task.isArchived() || task.isCompletedOneOff || task.isCanceledOneOff || isSelectedDateInFuture
    }

    var routineEmoji: String {
        CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "✨"
    }

    var frequencyText: String {
        if task.isOneOffTask {
            return "One-off todo"
        }
        if task.isChecklistDriven {
            return "Checklist-driven"
        }
        return task.recurrenceRule.displayText()
    }

    var stepProgressText: String {
        guard task.hasSequentialSteps else { return "" }
        if task.isInProgress {
            return "Step \(task.completedSteps + 1) of \(task.totalSteps)"
        }
        return "\(task.totalSteps) sequential \(task.totalSteps == 1 ? "step" : "steps")"
    }

    var checklistProgressText: String {
        if task.isChecklistCompletionRoutine && isDoneToday && !task.isChecklistInProgress {
            return "All items completed today"
        }
        let completed = task.completedChecklistItemCount
        let total = max(task.totalChecklistItemCount, 1)
        return "\(completed) of \(total) items completed"
    }

    var completedLogCountText: String {
        completedLogCount == 1 ? "1 completion" : "\(completedLogCount) completions"
    }

    var canceledLogCountText: String {
        canceledLogCount == 1 ? "1 cancel" : "\(canceledLogCount) cancels"
    }

    func priorityMetadataText(priorityLabel: String) -> String {
        "\(priorityLabel) • \(task.importance.title) importance • \(task.urgency.title) urgency"
    }

    // MARK: - Summary status title

    var summaryStatusTitle: String {
        let pausedAt = task.pausedAt
        let snoozedUntil = task.isSnoozed() ? task.snoozedUntil : nil
        let overdueDays = self.overdueDays
        let daysSinceLastRoutine = self.daysSinceLastRoutine
        let isDoneToday = self.isDoneToday

        if let snoozedUntil {
            return "Not today. Back on \(snoozedUntil.formatted(date: .abbreviated, time: .omitted))"
        }
        if let pausedAt {
            return "Paused since \(pausedAt.formatted(date: .abbreviated, time: .omitted))"
        }
        if task.isSoftIntervalRoutine && task.isOngoing {
            if let ongoingSince = task.ongoingSince {
                return "Ongoing since \(ongoingSince.formatted(date: .abbreviated, time: .omitted))"
            }
            return "Ongoing"
        }
        if task.isOneOffTask {
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
        if task.isChecklistCompletionRoutine {
            if task.isChecklistInProgress {
                return "Checklist \(task.completedChecklistItemCount) of \(task.totalChecklistItemCount) in progress"
            }
            if isDoneToday {
                return "Done today"
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
        if task.isChecklistDriven {
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
        if task.isSoftIntervalRoutine {
            if isDoneToday {
                return "Done today"
            }
            guard task.lastDone != nil else { return "Ready whenever" }
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
        if task.isInProgress {
            return "Step \(task.completedSteps + 1) of \(task.totalSteps) in progress"
        }
        if isDoneToday {
            return "Done today"
        }
        if isAssumedDoneToday {
            return "Assumed done today"
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

    // MARK: - Completion button title

    var completionButtonTitle: String {
        TaskDetailCompletionButtonTitlePresentation(
            task: task,
            selectedDate: resolvedSelectedDate,
            isSelectedDateTerminal: isSelectedDateTerminal,
            isSelectedDateInFuture: isSelectedDateInFuture,
            shouldUseBulkConfirmAsPrimaryAction: shouldUseBulkConfirmAsPrimaryAction,
            bulkConfirmAssumedDaysTitle: bulkConfirmAssumedDaysTitle,
            isSelectedDateAssumedDone: isSelectedDateAssumedDone,
            completionTargetDate: completionTargetDate,
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

    // MARK: - Helpers

    /// Days until the task is due, or nil if the task is archived for now.
    var daysUntilDueIfActive: Int? {
        guard !task.isArchived() else { return nil }
        guard !task.isSoftIntervalRoutine else { return nil }
        return RoutineDateMath.daysUntilDue(for: task, referenceDate: Date())
    }

    static func dayWord(_ count: Int) -> String {
        abs(count) == 1 ? "day" : "days"
    }

    func isChecklistItemMarkedDone(_ item: RoutineChecklistItem) -> Bool {
        if task.isChecklistCompletionRoutine && isDoneToday && !task.isChecklistInProgress {
            return true
        }
        return task.isChecklistItemCompleted(item.id)
    }
}

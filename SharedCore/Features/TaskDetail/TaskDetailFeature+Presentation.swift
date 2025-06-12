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

    var isSelectedDateDone: Bool {
        let calendar = Calendar.current
        let day = resolvedSelectedDate
        return logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            return $0.kind == .completed && calendar.isDate(timestamp, inSameDayAs: day)
        }
        || task.lastDone.map { calendar.isDate($0, inSameDayAs: day) } == true
    }

    var isSelectedDateCanceled: Bool {
        let calendar = Calendar.current
        let day = resolvedSelectedDate
        return logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            return $0.kind == .canceled && calendar.isDate(timestamp, inSameDayAs: day)
        }
        || task.canceledAt.map { calendar.isDate($0, inSameDayAs: day) } == true
    }

    var isSelectedDateTerminal: Bool {
        isSelectedDateDone || isSelectedDateCanceled
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
        guard let placeID = task.placeID else { return nil }
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

    var blockerSummaryText: String {
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
        canUndoSelectedDate ? .undoSelectedDateCompletion : .markAsDone
    }

    var completionButtonSystemImage: String? {
        canUndoSelectedDate ? "arrow.uturn.backward" : nil
    }

    var isCompletionButtonDisabled: Bool {
        guard !canUndoSelectedDate else { return false }
        if task.isCompletedOneOff || task.isCanceledOneOff {
            return true
        }
        if task.isChecklistCompletionRoutine {
            return true
        }
        if task.isChecklistDriven {
            return task.isPaused
                || !Calendar.current.isDateInToday(resolvedSelectedDate)
                || checklistDueItemCount == 0
        }
        return isSelectedDateInFuture || task.isPaused || isStepRoutineOffToday
    }

    /// Due date resolved from the task (one-off deadline or next recurrence).
    var resolvedDueDate: Date? {
        if task.isOneOffTask {
            return task.deadline
        }
        return RoutineDateMath.dueDate(for: task, referenceDate: Date())
    }

    var dueDateMetadataText: String? {
        guard let dueDate = resolvedDueDate, !Calendar.current.isDateInToday(dueDate) else {
            return nil
        }
        return dueDate.formatted(date: .abbreviated, time: .omitted)
    }

    var shouldShowSelectedDateMetadata: Bool {
        !Calendar.current.isDateInToday(resolvedSelectedDate)
            && !task.isCompletedOneOff
            && !task.isCanceledOneOff
    }

    var selectedDateMetadataText: String {
        if Calendar.current.isDateInToday(resolvedSelectedDate) {
            return "Today"
        }
        return resolvedSelectedDate.formatted(date: .abbreviated, time: .omitted)
    }

    var cancelTodoButtonTitle: String {
        if Calendar.current.isDateInToday(resolvedSelectedDate) {
            return "Cancel todo"
        }
        return "Cancel for \(resolvedSelectedDate.formatted(date: .abbreviated, time: .omitted))"
    }

    var isCancelTodoButtonDisabled: Bool {
        task.isPaused || task.isCompletedOneOff || task.isCanceledOneOff || isSelectedDateInFuture
    }

    var routineEmoji: String {
        task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨"
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
        if isDoneToday && !task.isChecklistInProgress {
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
        let overdueDays = self.overdueDays
        let daysSinceLastRoutine = self.daysSinceLastRoutine
        let isDoneToday = self.isDoneToday

        if let pausedAt {
            return "Paused since \(pausedAt.formatted(date: .abbreviated, time: .omitted))"
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
        if task.isInProgress {
            return "Step \(task.completedSteps + 1) of \(task.totalSteps) in progress"
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

    // MARK: - Completion button title

    var completionButtonTitle: String {
        let selectedDate = resolvedSelectedDate
        let isDone = isSelectedDateTerminal
        let isFuture = isSelectedDateInFuture
        let isPaused = task.isPaused

        if !task.isChecklistDriven && isDone {
            return "Undo"
        }
        if task.isCanceledOneOff {
            return "Select the canceled date to undo"
        }
        if task.isCompletedOneOff {
            return "Select the completion date to undo"
        }
        if isPaused {
            return "Resume the routine to mark dates done"
        }
        if task.isOneOffTask {
            if Calendar.current.isDateInToday(selectedDate) {
                return "Done"
            }
            return "Done for \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
        }
        if task.isChecklistCompletionRoutine && !Calendar.current.isDateInToday(selectedDate) {
            return "Checklist progress can only be updated today"
        }
        if task.isChecklistCompletionRoutine {
            return "Complete checklist items below"
        }
        if task.isChecklistDriven && !Calendar.current.isDateInToday(selectedDate) {
            return "Checklist routines can only be updated today"
        }
        if task.isChecklistDriven {
            let dueItems = task.dueChecklistItems(referenceDate: Date())
            if dueItems.isEmpty {
                return "No due items right now"
            }
            if dueItems.count == 1, let title = dueItems.first?.title {
                return "Buy: \(title)"
            }
            return "Buy \(dueItems.count) due items"
        }
        if task.hasSequentialSteps && !Calendar.current.isDateInToday(selectedDate) {
            return "Step routines can only be progressed today"
        }
        if isFuture {
            return "Future dates can't be marked done"
        }
        if let nextStepTitle = task.nextStepTitle {
            return "Complete: \(nextStepTitle)"
        }
        if Calendar.current.isDateInToday(selectedDate) {
            return "Done"
        }
        return "Done for \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
    }

    // MARK: - Helpers

    /// Days until the task is due, or nil if the task is paused.
    var daysUntilDueIfActive: Int? {
        guard !task.isPaused else { return nil }
        return RoutineDateMath.daysUntilDue(for: task, referenceDate: Date())
    }

    static func dayWord(_ count: Int) -> String {
        abs(count) == 1 ? "day" : "days"
    }

    func isChecklistItemMarkedDone(_ item: RoutineChecklistItem) -> Bool {
        guard task.isChecklistCompletionRoutine else { return false }
        if isDoneToday && !task.isChecklistInProgress {
            return true
        }
        return task.isChecklistItemCompleted(item.id)
    }
}

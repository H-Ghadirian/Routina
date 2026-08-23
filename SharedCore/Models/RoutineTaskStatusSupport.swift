import Foundation

extension RoutineTask {
    var isPaused: Bool {
        isPaused(referenceDate: Date())
    }

    /// A pause applies from its start until its optional expiry instant. Keeping
    /// the expiry as data instead of requiring a background wake makes the task
    /// become active consistently on every device as soon as it is observed.
    func isPaused(referenceDate: Date = Date()) -> Bool {
        guard let pausedAt, referenceDate >= pausedAt else { return false }
        guard let pauseUntil else { return true }
        return referenceDate < pauseUntil
    }

    func isSnoozed(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let snoozedUntil else { return false }
        return calendar.startOfDay(for: referenceDate) < calendar.startOfDay(for: snoozedUntil)
    }

    func isArchived(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        isPaused(referenceDate: referenceDate)
            || isSnoozed(referenceDate: referenceDate, calendar: calendar)
    }

    var isPinned: Bool {
        pinnedAt != nil
    }

    var activityState: RoutineActivityState {
        get { RoutineActivityState(rawValue: activityStateRawValue) ?? .idle }
        set { activityStateRawValue = newValue.rawValue }
    }

    var isOngoing: Bool {
        activityState == .ongoing
    }

    /// Workflow state for one-off todos only. Nil for routines.
    /// Behavioral fields (pausedAt, lastDone) take precedence over the stored label
    /// so legacy tasks without todoStateRawValue are handled correctly.
    var todoState: TodoState? {
        guard isOneOffTask else { return nil }
        if isPaused { return .paused }
        if lastDone != nil || canceledAt != nil { return .done }
        if let raw = todoStateRawValue { return TodoState(rawValue: raw) ?? .ready }
        return .ready
    }

    var isOneOffTask: Bool {
        scheduleMode == .oneOff
    }

    var isRoutineTask: Bool {
        scheduleMode.taskType == .routine
    }

    var isCompletedOneOff: Bool {
        isOneOffTask && lastDone != nil && canceledAt == nil && !isInProgress
    }

    var isCanceledOneOff: Bool {
        isOneOffTask && canceledAt != nil
    }

    func startOngoing(at startedAt: Date) {
        guard !isOneOffTask else { return }
        guard !isArchived(referenceDate: startedAt, calendar: .current) else { return }
        activityState = .ongoing
        ongoingSince = startedAt
    }

    func cancelOneOff(at canceledAt: Date) -> Bool {
        guard isOneOffTask, !isArchived(), !isCompletedOneOff, !isCanceledOneOff else { return false }
        lastDone = nil
        lastSatisfiedScheduledOccurrenceAt = nil
        self.canceledAt = canceledAt
        scheduleAnchor = nil
        resetStepProgress()
        resetChecklistProgress()
        return true
    }

    func removeCanceledState() {
        canceledAt = nil
    }
}

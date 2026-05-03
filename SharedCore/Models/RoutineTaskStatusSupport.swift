import Foundation

extension RoutineTask {
    var isPaused: Bool {
        pausedAt != nil
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
        isPaused || isSnoozed(referenceDate: referenceDate, calendar: calendar)
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
        if pausedAt != nil { return .paused }
        if lastDone != nil || canceledAt != nil { return .done }
        if let raw = todoStateRawValue { return TodoState(rawValue: raw) ?? .ready }
        return .ready
    }

    var isOneOffTask: Bool {
        scheduleMode == .oneOff
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

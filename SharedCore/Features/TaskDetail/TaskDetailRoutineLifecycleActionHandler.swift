import ComposableArchitecture
import Foundation

struct TaskDetailRoutineLifecycleActionHandler {
    typealias State = TaskDetailFeature.State
    typealias Action = TaskDetailFeature.Action

    var now: () -> Date
    var calendar: Calendar
    var refreshTaskView: (inout State) -> Void
    var updateDerivedState: (inout State) -> Void
    var upsertLocalLog: (Date, inout State) -> Void
    var persistPause: (UUID, Date) -> Effect<Action>
    var persistNotToday: (UUID, Date) -> Effect<Action>
    var persistResume: (UUID, Date) -> Effect<Action>
    var persistStartOngoing: (UUID, Date) -> Effect<Action>
    var persistFinishOngoing: (UUID, Date) -> Effect<Action>

    func pauseTapped(state: inout State) -> Effect<Action> {
        guard !state.task.isOneOffTask else { return .none }
        guard !state.task.isArchived(referenceDate: now(), calendar: calendar) else { return .none }
        let pauseDate = now()
        if state.task.scheduleAnchor == nil {
            state.task.scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(
                for: state.task,
                referenceDate: pauseDate
            )
        }
        state.task.pausedAt = pauseDate
        refreshTaskView(&state)
        updateDerivedState(&state)
        return persistPause(state.task.id, pauseDate)
    }

    func notTodayTapped(state: inout State) -> Effect<Action> {
        guard !state.task.isOneOffTask else { return .none }
        guard !state.task.isArchived(referenceDate: now(), calendar: calendar) else { return .none }
        let tomorrowStart = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now())
        ) ?? now()
        state.task.snoozedUntil = tomorrowStart
        refreshTaskView(&state)
        updateDerivedState(&state)
        return persistNotToday(state.task.id, tomorrowStart)
    }

    func resumeTapped(state: inout State) -> Effect<Action> {
        guard !state.task.isOneOffTask else { return .none }
        guard state.task.isArchived(referenceDate: now(), calendar: calendar) else { return .none }
        let resumeDate = now()
        if let pausedAt = state.task.pausedAt, state.task.isChecklistDriven {
            state.task.shiftChecklistItems(by: max(resumeDate.timeIntervalSince(pausedAt), 0))
        }
        state.task.scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(
            for: state.task,
            resumedAt: resumeDate
        )
        state.task.pausedAt = nil
        state.task.snoozedUntil = nil
        refreshTaskView(&state)
        updateDerivedState(&state)
        return persistResume(state.task.id, resumeDate)
    }

    func startOngoingTapped(state: inout State) -> Effect<Action> {
        guard state.task.usesOngoingLifecycle else { return .none }
        guard !state.task.isArchived(referenceDate: now(), calendar: calendar) else { return .none }
        guard !state.task.isOngoing else { return .none }
        let startedAt = lifecycleActionDate(for: state)
        state.task.startOngoing(at: startedAt)
        state.task.appendChangeLogEntry(
            RoutineTaskChangeLogEntry(
                timestamp: startedAt,
                kind: .ongoingStarted,
                newValue: RoutineTaskMultiDaySpanDateStorage.encode(startedAt)
            )
        )
        refreshTaskView(&state)
        updateDerivedState(&state)
        return persistStartOngoing(state.task.id, startedAt)
    }

    func finishOngoingTapped(state: inout State) -> Effect<Action> {
        guard state.task.usesOngoingLifecycle else { return .none }
        guard state.task.isOngoing else { return .none }
        let finishedAt = lifecycleActionDate(for: state)
        let startedAt = state.task.ongoingSince
        guard canFinishOngoing(startedAt: startedAt, finishedAt: finishedAt) else { return .none }
        state.task.finishOngoing(at: finishedAt)
        state.task.appendChangeLogEntry(
            RoutineTaskChangeLogEntry(
                timestamp: finishedAt,
                kind: .ongoingStopped,
                previousValue: startedAt.map(RoutineTaskMultiDaySpanDateStorage.encode),
                newValue: RoutineTaskMultiDaySpanDateStorage.encode(finishedAt)
            )
        )
        refreshTaskView(&state)
        upsertLocalLog(finishedAt, &state)
        updateDerivedState(&state)
        return persistFinishOngoing(state.task.id, finishedAt)
    }

    private func lifecycleActionDate(for state: State) -> Date {
        guard let selectedDate = state.selectedDate else { return now() }
        return calendar.startOfDay(for: selectedDate)
    }

    private func canFinishOngoing(startedAt: Date?, finishedAt: Date) -> Bool {
        guard let startedAt else { return true }
        return calendar.startOfDay(for: finishedAt) >= calendar.startOfDay(for: startedAt)
    }
}

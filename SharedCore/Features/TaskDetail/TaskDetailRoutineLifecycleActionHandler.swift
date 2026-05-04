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
        guard state.task.isSoftIntervalRoutine else { return .none }
        guard !state.task.isArchived(referenceDate: now(), calendar: calendar) else { return .none }
        guard !state.task.isOngoing else { return .none }
        let startedAt = now()
        state.task.startOngoing(at: startedAt)
        refreshTaskView(&state)
        updateDerivedState(&state)
        return persistStartOngoing(state.task.id, startedAt)
    }

    func finishOngoingTapped(state: inout State) -> Effect<Action> {
        guard state.task.isSoftIntervalRoutine else { return .none }
        guard state.task.isOngoing else { return .none }
        let finishedAt = now()
        state.task.finishOngoing(at: finishedAt)
        refreshTaskView(&state)
        upsertLocalLog(finishedAt, &state)
        updateDerivedState(&state)
        return persistFinishOngoing(state.task.id, finishedAt)
    }
}

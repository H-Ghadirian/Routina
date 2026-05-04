import ComposableArchitecture
import Foundation

struct TaskDetailCompletionLogActionHandler {
    typealias State = TaskDetailFeature.State
    typealias Action = TaskDetailFeature.Action

    var now: () -> Date
    var calendar: Calendar
    var resolvedSelectedDay: (Date?) -> Date
    var removePendingLocalCompletion: (Date, inout State) -> Void
    var removeCompletion: (Date, inout State) -> Void
    var removeLogEntryLocally: (Date, inout State) -> Void
    var logsPreservingPendingLocalCompletions: ([RoutineLog], inout State) -> [RoutineLog]
    var upsertLocalLog: (Date, inout State) -> Void
    var refreshTaskView: (inout State) -> Void
    var updateDerivedState: (inout State) -> Void
    var persistUndoCompletion: (UUID, Date) -> Effect<Action>
    var persistRemoveLogEntry: (UUID, Date) -> Effect<Action>
    var persistLogDuration: (UUID, UUID, Int?, Int?) -> Effect<Action>
    var persistTaskDuration: (UUID, Int?, Int?) -> Effect<Action>
    var persistConfirmAssumedPastDays: (UUID, [Date]) -> Effect<Action>

    func undoSelectedDateCompletion(state: inout State) -> Effect<Action> {
        if state.task.isChecklistDriven {
            return .none
        }
        let selectedDay = resolvedSelectedDay(state.selectedDate)
        removePendingLocalCompletion(selectedDay, &state)
        removeCompletion(selectedDay, &state)
        refreshTaskView(&state)
        updateDerivedState(&state)
        return persistUndoCompletion(state.task.id, selectedDay)
    }

    func removeLogEntry(_ timestamp: Date, state: inout State) -> Effect<Action> {
        removePendingLocalCompletion(timestamp, &state)
        removeLogEntryLocally(timestamp, &state)
        refreshTaskView(&state)
        updateDerivedState(&state)
        return persistRemoveLogEntry(state.task.id, timestamp)
    }

    func updateLogDuration(
        logID: UUID,
        durationMinutes: Int?,
        state: inout State
    ) -> Effect<Action> {
        let sanitizedDuration = RoutineLog.sanitizedActualDurationMinutes(durationMinutes)
        let previousDuration = state.logs.first(where: { $0.id == logID })?.actualDurationMinutes
        if let index = state.logs.firstIndex(where: { $0.id == logID }) {
            state.logs[index].actualDurationMinutes = sanitizedDuration
        }
        return persistLogDuration(
            state.task.id,
            logID,
            previousDuration,
            sanitizedDuration
        )
    }

    func updateTaskDuration(_ durationMinutes: Int?, state: inout State) -> Effect<Action> {
        let sanitizedDuration = RoutineTask.sanitizedActualDurationMinutes(durationMinutes)
        let previousDuration = state.task.actualDurationMinutes
        state.task.actualDurationMinutes = sanitizedDuration
        return persistTaskDuration(
            state.task.id,
            previousDuration,
            sanitizedDuration
        )
    }

    func confirmUndoCompletion(state: inout State) -> Effect<Action> {
        state.isUndoCompletionConfirmationPresented = false
        if let timestamp = state.pendingLogRemovalTimestamp {
            state.pendingLogRemovalTimestamp = nil
            return removeLogEntry(timestamp, state: &state)
        }
        return undoSelectedDateCompletion(state: &state)
    }

    func logsLoaded(_ logs: [RoutineLog], state: inout State) -> Effect<Action> {
        state.logs = logsPreservingPendingLocalCompletions(logs, &state)
        updateDerivedState(&state)
        return .none
    }

    func confirmAssumedPastDays(state: inout State) -> Effect<Action> {
        let assumedDays = RoutineAssumedCompletion.assumedDates(
            for: state.task,
            through: now(),
            logs: state.logs,
            includeToday: true,
            calendar: calendar
        )
        guard !assumedDays.isEmpty else { return .none }

        for day in assumedDays {
            let completionDate = RoutineAssumedCompletion.completionTimestamp(
                for: day,
                referenceDate: now(),
                calendar: calendar
            )
            _ = state.task.advance(completedAt: completionDate, calendar: calendar)
            upsertLocalLog(completionDate, &state)
        }
        refreshTaskView(&state)
        updateDerivedState(&state)
        return persistConfirmAssumedPastDays(state.task.id, assumedDays)
    }
}

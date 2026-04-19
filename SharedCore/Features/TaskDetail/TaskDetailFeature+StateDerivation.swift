import ComposableArchitecture
import Foundation

extension TaskDetailFeature {
    func updateDerivedState(_ state: inout State) {
        let nowStart = calendar.startOfDay(for: now)

        if let lastDone = state.task.lastDone {
            let lastDoneStart = calendar.startOfDay(for: lastDone)
            state.daysSinceLastRoutine = calendar.dateComponents([.day], from: lastDoneStart, to: nowStart).day ?? 0
        } else {
            state.daysSinceLastRoutine = 0
        }

        let doneTodayFromLastDone = state.task.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        let doneTodayFromLogs = state.logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            return $0.kind == .completed && calendar.isDate(timestamp, inSameDayAs: now)
        }
        state.isDoneToday = doneTodayFromLastDone || doneTodayFromLogs
        state.isAssumedDoneToday = !state.isDoneToday && RoutineAssumedCompletion.isAssumedDone(
            for: state.task,
            on: now,
            referenceDate: now,
            logs: state.logs,
            calendar: calendar
        )

        if state.task.isArchived(referenceDate: now, calendar: calendar) {
            state.overdueDays = 0
        } else {
            state.overdueDays = RoutineDateMath.overdueDays(for: state.task, referenceDate: now, calendar: calendar)
        }
    }

    func refreshTaskView(_ state: inout State) {
        state.taskRefreshID &+= 1
    }

    func resolvedCompletionDate(for selectedDate: Date?) -> Date {
        let baseDate = selectedDate ?? now
        if calendar.isDate(baseDate, inSameDayAs: now) {
            return now
        }

        let startOfDay = calendar.startOfDay(for: baseDate)
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay) ?? startOfDay
    }

    func resolvedSelectedDay(for selectedDate: Date?) -> Date {
        calendar.startOfDay(for: selectedDate ?? now)
    }

    func removeCompletion(on completedDay: Date, from state: inout State) {
        let removedLatestCompletion = state.task.lastDone.map {
            calendar.isDate($0, inSameDayAs: completedDay)
        } ?? false

        state.logs.removeAll { log in
            guard let timestamp = log.timestamp else { return false }
            return calendar.isDate(timestamp, inSameDayAs: completedDay)
        }

        let remainingLatestCompletion = state.logs
            .filter { $0.kind == .completed }
            .compactMap(\.timestamp)
            .max()

        if removedLatestCompletion {
            state.task.lastDone = remainingLatestCompletion
        }

        if state.task.canceledAt.map({ calendar.isDate($0, inSameDayAs: completedDay) }) == true {
            state.task.removeCanceledState()
        }

        if removedLatestCompletion {
            state.task.refreshScheduleAnchorAfterRemovingLatestCompletion(
                remainingLatestCompletion: remainingLatestCompletion
            )
        }

        state.task.resetStepProgress()
        state.task.resetChecklistProgress()
    }

    func upsertLocalLog(at timestamp: Date, kind: RoutineLogKind = .completed, in state: inout State) {
        if let existingIndex = state.logs.firstIndex(where: { log in
            guard let logTimestamp = log.timestamp else { return false }
            return log.kind == kind && calendar.isDate(logTimestamp, inSameDayAs: timestamp)
        }) {
            if timestamp > (state.logs[existingIndex].timestamp ?? .distantPast) {
                state.logs[existingIndex].timestamp = timestamp
            }
            state.logs.sort {
                ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast)
            }
            return
        }

        state.logs.insert(RoutineLog(timestamp: timestamp, taskID: state.task.id, kind: kind), at: 0)
    }
}

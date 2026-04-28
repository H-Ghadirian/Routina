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

        let todayDisplayDay = calendar.startOfDay(for: now)
        let doneTodayFromLastDone = state.task.lastDone.flatMap {
            RoutineDateMath.completionDisplayDay(for: state.task, completionDate: $0, calendar: calendar)
        }.map { calendar.isDate($0, inSameDayAs: todayDisplayDay) } ?? false
        let doneTodayFromLogs = state.logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            guard $0.kind == .completed else { return false }
            guard let displayDay = RoutineDateMath.completionDisplayDay(
                for: state.task,
                completionDate: timestamp,
                calendar: calendar
            ) else {
                return false
            }
            return calendar.isDate(displayDay, inSameDayAs: todayDisplayDay)
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

    func resolvedCompletionDate(
        for selectedDate: Date?,
        task: RoutineTask
    ) -> Date {
        let baseDate = selectedDate ?? now
        if calendar.isDate(baseDate, inSameDayAs: now) {
            return now
        }

        let startOfDay = calendar.startOfDay(for: baseDate)
        if let timeOfDay = task.recurrenceRule.timeOfDay,
           !task.isOneOffTask {
            return timeOfDay.date(on: startOfDay, calendar: calendar)
        }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay) ?? startOfDay
    }

    func resolvedMarkAsDoneDate(
        for selectedDate: Date?,
        task: RoutineTask
    ) -> Date? {
        let baseDate = selectedDate ?? now

        if let exactTimedTarget = RoutineDateMath.completionTargetDate(
            for: task,
            selectedDay: baseDate,
            referenceDate: now,
            calendar: calendar
        ) {
            return exactTimedTarget
        }

        if RoutineDateMath.usesExactTimedOccurrenceTracking(for: task) {
            return nil
        }

        return resolvedCompletionDate(for: selectedDate, task: task)
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

    func removeLogEntry(at timestamp: Date, from state: inout State) {
        let removedLatestCompletion = state.task.lastDone == timestamp
        let removedCanceledAt = state.task.canceledAt == timestamp

        state.logs.removeAll { $0.timestamp == timestamp }

        let remainingLatestCompletion = state.logs
            .filter { $0.kind == .completed }
            .compactMap(\.timestamp)
            .max()

        if removedLatestCompletion {
            state.task.lastDone = remainingLatestCompletion
            state.task.refreshScheduleAnchorAfterRemovingLatestCompletion(
                remainingLatestCompletion: remainingLatestCompletion
            )
        }

        if removedCanceledAt {
            state.task.removeCanceledState()
        }

        state.task.resetStepProgress()
        state.task.resetChecklistProgress()
    }

    func trackPendingLocalCompletion(at timestamp: Date, in state: inout State) {
        let alreadyPending = state.pendingLocalCompletionDates.contains {
            calendar.isDate($0, inSameDayAs: timestamp)
        }
        guard !alreadyPending else { return }
        state.pendingLocalCompletionDates.append(timestamp)
    }

    func removePendingLocalCompletion(on completedDay: Date, from state: inout State) {
        state.pendingLocalCompletionDates.removeAll {
            calendar.isDate($0, inSameDayAs: completedDay)
        }
    }

    func logsPreservingPendingLocalCompletions(
        _ loadedLogs: [RoutineLog],
        in state: inout State
    ) -> [RoutineLog] {
        var mergedLogs = loadedLogs.map { $0.detachedCopy() }

        state.pendingLocalCompletionDates.removeAll { pendingDate in
            mergedLogs.contains { log in
                guard let timestamp = log.timestamp else { return false }
                return log.kind == .completed && calendar.isDate(timestamp, inSameDayAs: pendingDate)
            }
        }

        for pendingDate in state.pendingLocalCompletionDates {
            guard !mergedLogs.contains(where: { log in
                guard let timestamp = log.timestamp else { return false }
                return log.kind == .completed && calendar.isDate(timestamp, inSameDayAs: pendingDate)
            }) else {
                continue
            }

            if let optimisticLog = state.logs.first(where: { log in
                guard let timestamp = log.timestamp else { return false }
                return log.kind == .completed && calendar.isDate(timestamp, inSameDayAs: pendingDate)
            }) {
                mergedLogs.append(optimisticLog.detachedCopy())
            } else {
                mergedLogs.append(RoutineLog(timestamp: pendingDate, taskID: state.task.id, kind: .completed))
            }
        }

        mergedLogs.sort {
            ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast)
        }
        return mergedLogs
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

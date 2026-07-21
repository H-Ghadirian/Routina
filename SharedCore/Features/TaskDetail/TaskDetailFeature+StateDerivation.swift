import ComposableArchitecture
import Foundation

extension TaskDetailFeature {
    func updateDerivedState(_ state: inout State) {
        let nowStart = calendar.startOfDay(for: now)
        state.task.resetStaleDailyChecklistProgressIfNeeded(referenceDate: now, calendar: calendar)
        state.refreshChecklistItemsCache()

        if let lastDone = state.task.lastDone {
            let lastDoneStart = calendar.startOfDay(for: lastDone)
            state.daysSinceLastRoutine = calendar.dateComponents([.day], from: lastDoneStart, to: nowStart).day ?? 0
        } else {
            state.daysSinceLastRoutine = 0
        }

        let todayDisplayDay = calendar.startOfDay(for: now)
        let doneTodayFromLastDone = state.task.lastDone.flatMap {
            RoutineDateMath.completionDisplayDay(for: state.task, completionDate: $0, calendar: calendar)
        }.map { displayDay in
            !state.hasPendingLocalRemoval(on: displayDay, calendar: calendar)
                && calendar.isDate(displayDay, inSameDayAs: todayDisplayDay)
        } ?? false
        let doneTodayFromLogs = state.logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            guard $0.kind.resolvesDoneDate else { return false }
            guard let displayDay = RoutineDateMath.completionDisplayDay(
                for: state.task,
                completionDate: timestamp,
                calendar: calendar
            ) else {
                return false
            }
            return !state.hasPendingLocalRemoval(on: displayDay, calendar: calendar)
                && calendar.isDate(displayDay, inSameDayAs: todayDisplayDay)
        }
        state.isDoneToday = RoutineDateMath.isCompletedForCurrentPeriod(
            doneTodayFromLastDone || doneTodayFromLogs,
            task: state.task,
            referenceDate: now,
            calendar: calendar
        )
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
        state.refreshChecklistItemsCache()
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
        if let timeOfDay = task.recurrenceRule.timeRange?.start ?? task.recurrenceRule.timeOfDay,
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

    func resolvedRunoutActionDate(for selectedDate: Date?) -> Date? {
        let selectedDay = calendar.startOfDay(for: selectedDate ?? now)
        let today = calendar.startOfDay(for: now)
        guard selectedDay <= today else { return nil }
        if calendar.isDate(selectedDay, inSameDayAs: today) {
            return now
        }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDay) ?? selectedDay
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
            .filter { $0.kind.resolvesDoneDate }
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

        state.task.removeMultiDaySpan(containing: completedDay, calendar: calendar)
        state.task.resetStepProgress()
        state.task.resetChecklistProgress()
    }

    func removeLogEntry(at timestamp: Date, from state: inout State) {
        let removedLatestCompletion = state.task.lastDone == timestamp
        let removedCanceledAt = state.task.canceledAt == timestamp

        state.logs.removeAll { $0.timestamp == timestamp }

        let remainingLatestCompletion = state.logs
            .filter { $0.kind.resolvesDoneDate }
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

        state.task.removeMultiDaySpan(containing: timestamp, calendar: calendar)
        state.task.resetStepProgress()
        state.task.resetChecklistProgress()
    }

    func trackPendingLocalCompletion(at timestamp: Date, in state: inout State) {
        let alreadyPending = state.pendingLocalCompletionDates.contains {
            resolutionDatesMatch($0, timestamp, for: state.task)
        }
        guard !alreadyPending else { return }
        state.pendingLocalCompletionDates.append(timestamp)
    }

    func removePendingLocalCompletion(on completedDay: Date, from state: inout State) {
        let task = state.task
        state.pendingLocalCompletionDates.removeAll {
            pendingDateMatches($0, target: completedDay, for: task)
        }
    }

    func trackPendingLocalRemoval(on completedDay: Date, in state: inout State) {
        let alreadyPending = state.pendingLocalRemovalDates.contains {
            pendingDateMatches($0, target: completedDay, for: state.task)
        }
        guard !alreadyPending else { return }
        state.pendingLocalRemovalDates.append(completedDay)
    }

    func logsPreservingPendingLocalCompletions(
        _ loadedLogs: [RoutineLog],
        in state: inout State
    ) -> [RoutineLog] {
        let task = state.task
        var mergedLogs = loadedLogs.filter { log in
            guard let timestamp = log.timestamp else { return true }
            guard log.kind.resolvesDoneDate else { return true }
            return !state.pendingLocalRemovalDates.contains {
                pendingDateMatches($0, target: timestamp, for: state.task)
            }
        }.map { $0.detachedCopy() }

        let confirmedRemovalDates = state.pendingLocalRemovalDates.filter { pendingDate in
            !loadedLogs.contains { log in
                guard let timestamp = log.timestamp else { return false }
                return log.kind.resolvesDoneDate
                    && pendingDateMatches(pendingDate, target: timestamp, for: state.task)
            }
        }

        if !confirmedRemovalDates.isEmpty {
            let remainingLatestCompletion = mergedLogs
                .filter { $0.kind.resolvesDoneDate }
                .compactMap(\.timestamp)
                .max()
            for pendingDate in confirmedRemovalDates {
                if state.task.lastDone.map({
                    pendingDateMatches(pendingDate, target: $0, for: state.task)
                }) == true {
                    state.task.lastDone = remainingLatestCompletion
                    state.task.refreshScheduleAnchorAfterRemovingLatestCompletion(
                        remainingLatestCompletion: remainingLatestCompletion
                    )
                    state.task.resetStepProgress()
                    state.task.resetChecklistProgress()
                }
            }
            state.pendingLocalRemovalDates.removeAll { pendingDate in
                confirmedRemovalDates.contains {
                    pendingDateMatches($0, target: pendingDate, for: task)
                }
            }
        }

        state.pendingLocalCompletionDates.removeAll { pendingDate in
            mergedLogs.contains { log in
                guard let timestamp = log.timestamp else { return false }
                return log.kind.resolvesDoneDate
                    && resolutionDatesMatch(timestamp, pendingDate, for: task)
            }
        }

        for pendingDate in state.pendingLocalCompletionDates {
            guard !mergedLogs.contains(where: { log in
                guard let timestamp = log.timestamp else { return false }
                return log.kind.resolvesDoneDate
                    && resolutionDatesMatch(timestamp, pendingDate, for: state.task)
            }) else {
                continue
            }

            if let optimisticLog = state.logs.first(where: { log in
                guard let timestamp = log.timestamp else { return false }
                return log.kind.resolvesDoneDate
                    && resolutionDatesMatch(timestamp, pendingDate, for: state.task)
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
            return log.kind == kind && resolutionDatesMatch(logTimestamp, timestamp, for: state.task)
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

    private func resolutionDatesMatch(_ lhs: Date, _ rhs: Date, for task: RoutineTask) -> Bool {
        if task.recurrenceRule.occursMoreThanOncePerDay {
            return abs(lhs.timeIntervalSince(rhs)) < 1
        }
        return calendar.isDate(lhs, inSameDayAs: rhs)
    }

    private func pendingDateMatches(_ pendingDate: Date, target: Date, for task: RoutineTask) -> Bool {
        guard task.recurrenceRule.occursMoreThanOncePerDay else {
            return calendar.isDate(pendingDate, inSameDayAs: target)
        }
        if pendingDate == calendar.startOfDay(for: pendingDate) {
            return calendar.isDate(pendingDate, inSameDayAs: target)
        }
        return abs(pendingDate.timeIntervalSince(target)) < 1
    }
}

extension TaskDetailFeature.State {
    func hasPendingLocalRemoval(on date: Date, calendar: Calendar) -> Bool {
        pendingLocalRemovalDates.contains {
            guard task.recurrenceRule.occursMoreThanOncePerDay else {
                return calendar.isDate($0, inSameDayAs: date)
            }
            if $0 == calendar.startOfDay(for: $0) {
                return calendar.isDate($0, inSameDayAs: date)
            }
            return abs($0.timeIntervalSince(date)) < 1
        }
    }
}

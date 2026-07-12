import Foundation
import SwiftData

struct HomeDoneStats: Equatable {
    var totalCount: Int = 0
    var countsByTaskID: [UUID: Int] = [:]
    var completedDatesByTaskID: [UUID: Set<Date>] = [:]
    var canceledTotalCount: Int = 0
    var canceledCountsByTaskID: [UUID: Int] = [:]
    var canceledDatesByTaskID: [UUID: Set<Date>] = [:]
    var missedDatesByTaskID: [UUID: Set<Date>] = [:]

    var missedTotalCount: Int {
        missedDatesByTaskID.values.reduce(0) { $0 + $1.count }
    }

    func hasResolvedMissedDate(
        taskID: UUID,
        missedDate: Date,
        calendar: Calendar
    ) -> Bool {
        if let missedDates = missedDatesByTaskID[taskID],
           missedDates.contains(where: { calendar.isDate($0, inSameDayAs: missedDate) }) {
            return true
        }
        if let canceledDates = canceledDatesByTaskID[taskID],
           canceledDates.contains(where: { calendar.isDate($0, inSameDayAs: missedDate) }) {
            return true
        }
        if let completedDates = completedDatesByTaskID[taskID],
           completedDates.contains(where: { calendar.isDate($0, inSameDayAs: missedDate) }) {
            return true
        }
        return false
    }

    func hasCompletedDate(
        taskID: UUID,
        date: Date,
        calendar: Calendar
    ) -> Bool {
        completedDatesByTaskID[taskID]?.contains {
            calendar.isDate($0, inSameDayAs: date)
        } ?? false
    }

    mutating func replaceLogs(for taskID: UUID, with logs: [RoutineLog]) {
        totalCount = max(totalCount - countsByTaskID[taskID, default: 0], 0)
        canceledTotalCount = max(canceledTotalCount - canceledCountsByTaskID[taskID, default: 0], 0)

        countsByTaskID.removeValue(forKey: taskID)
        completedDatesByTaskID.removeValue(forKey: taskID)
        canceledCountsByTaskID.removeValue(forKey: taskID)
        canceledDatesByTaskID.removeValue(forKey: taskID)
        missedDatesByTaskID.removeValue(forKey: taskID)

        for log in logs where log.taskID == taskID {
            switch log.kind {
            case .completed:
                totalCount += 1
                countsByTaskID[taskID, default: 0] += 1
                if let timestamp = log.timestamp {
                    completedDatesByTaskID[taskID, default: []].insert(timestamp)
                }
            case .fulfilled:
                if let timestamp = log.timestamp {
                    completedDatesByTaskID[taskID, default: []].insert(timestamp)
                }
            case .canceled:
                canceledTotalCount += 1
                canceledCountsByTaskID[taskID, default: 0] += 1
                if let timestamp = log.timestamp {
                    canceledDatesByTaskID[taskID, default: []].insert(timestamp)
                }
            case .missed:
                if let timestamp = log.timestamp {
                    missedDatesByTaskID[taskID, default: []].insert(timestamp)
                }
            }
        }
    }
}

private struct HomeTaskLogPayloadSignature: Comparable, Equatable {
    let id: UUID
    let timestamp: Date?
    let taskID: UUID
    let kindRawValue: String
    let actualDurationMinutes: Int?
    let sourceTaskID: UUID?

    init(log: RoutineLog) {
        id = log.id
        timestamp = log.timestamp
        taskID = log.taskID
        kindRawValue = log.kindRawValue
        actualDurationMinutes = log.actualDurationMinutes
        sourceTaskID = log.sourceTaskID
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.id.uuidString < rhs.id.uuidString
    }
}

enum HomeTaskSupport {
    static func logsHaveSamePayload(_ lhs: [RoutineLog], _ rhs: [RoutineLog]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return lhs.map(HomeTaskLogPayloadSignature.init(log:)).sorted()
            == rhs.map(HomeTaskLogPayloadSignature.init(log:)).sorted()
    }

    static func replacingTimelineLogs(
        for taskID: UUID,
        in timelineLogs: [RoutineLog],
        with logs: [RoutineLog]
    ) -> [RoutineLog] {
        (timelineLogs.filter { $0.taskID != taskID } + logs)
            .sorted {
                let lhs = $0.timestamp ?? .distantPast
                let rhs = $1.timestamp ?? .distantPast
                return lhs > rhs
            }
    }

    static func timelineTasksIncludingSelectedDetail(
        tasks: [RoutineTask],
        detailTask: RoutineTask?
    ) -> [RoutineTask] {
        guard let detailTask else { return tasks }

        var resolvedTasks = tasks
        let resolvedDetailTask = detailTask.detachedCopy()
        if let index = resolvedTasks.firstIndex(where: { $0.id == detailTask.id }) {
            resolvedTasks[index] = resolvedDetailTask
        } else {
            resolvedTasks.append(resolvedDetailTask)
        }
        return resolvedTasks
    }

    static func timelineLogsIncludingSelectedDetailFallback(
        timelineLogs: [RoutineLog],
        detailTask: RoutineTask?,
        detailLogs: [RoutineLog]?,
        calendar: Calendar
    ) -> [RoutineLog] {
        guard let detailTask else { return timelineLogs }

        let selectedTaskLogs = detailLogs ?? timelineLogs.filter { $0.taskID == detailTask.id }
        let resolvedSelectedLogs = TimelineLogic.logsIncludingLastDoneFallbacks(
            logs: selectedTaskLogs,
            tasks: [detailTask],
            calendar: calendar
        )
        return replacingTimelineLogs(
            for: detailTask.id,
            in: timelineLogs,
            with: resolvedSelectedLogs
        )
    }

    static func taskDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineTask> {
        FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
    }

    static func logsDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
        FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            }
        )
    }

    @MainActor
    static func detailLogs(taskID: UUID, context: ModelContext) -> [RoutineLog] {
        RoutineLogHistory.detailLogs(taskID: taskID, context: context)
    }

    static func focusSessionsDescriptor(for taskID: UUID) -> FetchDescriptor<FocusSession> {
        FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.taskID == taskID
            }
        )
    }

    static func makeTaskDetailState(
        for task: RoutineTask,
        now: Date,
        calendar: Calendar
    ) -> TaskDetailFeature.State {
        let detailTask = task.detachedCopy()
        let defaultSelectedDate = (detailTask.isCompletedOneOff || detailTask.isCanceledOneOff)
            ? calendar.startOfDay(for: detailTask.lastDone ?? detailTask.canceledAt ?? now)
            : calendar.startOfDay(for: now)
        var state = TaskDetailFeature.State(
            task: detailTask,
            logs: [],
            selectedDate: defaultSelectedDate,
            daysSinceLastRoutine: RoutineDateMath.elapsedDaysSinceLastDone(
                from: detailTask.lastDone,
                referenceDate: now
            ),
            overdueDays: detailTask.isArchived(referenceDate: now, calendar: calendar)
                ? 0
                : RoutineDateMath.overdueDays(for: detailTask, referenceDate: now, calendar: calendar),
            isDoneToday: detailTask.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false,
            isAssumedDoneToday: RoutineAssumedCompletion.isAssumedDone(
                for: detailTask,
                on: now,
                logs: []
            )
        )
        state.refreshChecklistItemsCache()
        return state
    }

    static func populateTaskDetailDisplayContext(
        _ detailState: inout TaskDetailFeature.State,
        tasks: [RoutineTask],
        places: [RoutinePlace],
        goals: [RoutineGoal],
        now: Date,
        calendar: Calendar
    ) {
        guard !detailState.isEditSheetPresented else { return }

        let task = detailState.task
        detailState.availableGoals = RoutineGoalSummary.summaries(from: goals)
        let directRelationshipTargetIDs = Set(task.relationships.map(\.targetTaskID))
        let relatedTasks = tasks.filter { candidate in
            guard candidate.id != task.id else { return false }
            if directRelationshipTargetIDs.contains(candidate.id) {
                return true
            }
            return candidate.relationships.contains { $0.targetTaskID == task.id }
        }
        detailState.availableRelationshipTasks = RoutineTaskRelationshipCandidate.from(
            relatedTasks,
            excluding: task.id,
            referenceDate: now,
            calendar: calendar
        )

        detailState.availablePlaces = RoutinePlace.summaries(from: places, linkedTo: tasks)
    }

    static func availableTags(from tasks: [RoutineTask]) -> [String] {
        RoutineTag.allTags(from: tasks.map(\.tags))
    }

    static func uniqueTaskIDs(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }

    static func existingRoutineNames(from tasks: [RoutineTask]) -> [String] {
        tasks.compactMap(\.name)
    }

    static func makeDoneStats(tasks: [RoutineTask], logs: [RoutineLog]) -> HomeDoneStats {
        let taskIDs = Set(tasks.map(\.id))
        var totalCount = 0
        var countsByTaskID: [UUID: Int] = [:]
        var completedDatesByTaskID: [UUID: Set<Date>] = [:]
        var canceledTotalCount = 0
        var canceledCountsByTaskID: [UUID: Int] = [:]
        var canceledDatesByTaskID: [UUID: Set<Date>] = [:]
        var missedDatesByTaskID: [UUID: Set<Date>] = [:]

        for log in logs {
            guard taskIDs.contains(log.taskID) else { continue }

            switch log.kind {
            case .completed:
                totalCount += 1
                countsByTaskID[log.taskID, default: 0] += 1
                if let timestamp = log.timestamp {
                    completedDatesByTaskID[log.taskID, default: []].insert(timestamp)
                }
            case .fulfilled:
                if let timestamp = log.timestamp {
                    completedDatesByTaskID[log.taskID, default: []].insert(timestamp)
                }
            case .canceled:
                canceledTotalCount += 1
                canceledCountsByTaskID[log.taskID, default: 0] += 1
                if let timestamp = log.timestamp {
                    canceledDatesByTaskID[log.taskID, default: []].insert(timestamp)
                }
            case .missed:
                if let timestamp = log.timestamp {
                    missedDatesByTaskID[log.taskID, default: []].insert(timestamp)
                }
            }
        }

        return HomeDoneStats(
            totalCount: totalCount,
            countsByTaskID: countsByTaskID,
            completedDatesByTaskID: completedDatesByTaskID,
            canceledTotalCount: canceledTotalCount,
            canceledCountsByTaskID: canceledCountsByTaskID,
            canceledDatesByTaskID: canceledDatesByTaskID,
            missedDatesByTaskID: missedDatesByTaskID
        )
    }
}

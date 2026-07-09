import Foundation

struct HomeTaskLoadSnapshot {
    var tasks: [RoutineTask]
    var places: [RoutinePlace]
    var goals: [RoutineGoal]
    var timelineLogs: [RoutineLog]
    var doneStats: HomeDoneStats
    var relatedTagRules: [RoutineRelatedTagRule]
    var selectedTaskReloadGuard: HomeSelectedTaskReloadGuard?
}

enum HomeTaskLoadSupport {
    static func makeSnapshot(
        tasks incomingTasks: [RoutineTask],
        places incomingPlaces: [RoutinePlace],
        goals incomingGoals: [RoutineGoal],
        logs incomingLogs: [RoutineLog],
        doneStats: HomeDoneStats,
        selectedTaskID: UUID?,
        detailTask: RoutineTask?,
        selectedTaskReloadGuard: HomeSelectedTaskReloadGuard?,
        persistedRelatedTagRules: [RoutineRelatedTagRule],
        calendar: Calendar = .current
    ) -> HomeTaskLoadSnapshot {
        let detachedTasks = incomingTasks.map { $0.detachedCopy() }
        let detachedPlaces = incomingPlaces.map { $0.detachedCopy() }
        let detachedGoals = incomingGoals.map { $0.detachedCopy() }
        let reconciliation = HomeReloadGuardSupport.reconcileSelectedDetailTask(
            detachedTasks,
            selectedTaskID: selectedTaskID,
            detailTask: detailTask,
            selectedTaskReloadGuard: selectedTaskReloadGuard
        )
        let reconciledTasks = reconciliation.tasks
        let resolvedTimelineLogs = timelineLogsIncludingLastDoneFallbacks(
            tasks: reconciledTasks,
            logs: incomingLogs,
            calendar: calendar
        )
        let resolvedDoneStats = resolvedTimelineLogs.count == incomingLogs.count
            ? doneStats
            : HomeTaskSupport.makeDoneStats(tasks: reconciledTasks, logs: resolvedTimelineLogs)

        return HomeTaskLoadSnapshot(
            tasks: reconciledTasks,
            places: detachedPlaces,
            goals: detachedGoals,
            timelineLogs: sortedTimelineLogs(resolvedTimelineLogs),
            doneStats: resolvedDoneStats,
            relatedTagRules: RoutineTagRelations.sanitized(
                persistedRelatedTagRules + RoutineTagRelations.learnedRules(from: reconciledTasks.map(\.tags))
            ),
            selectedTaskReloadGuard: reconciliation.selectedTaskReloadGuard
        )
    }

    static func timelineLogsIncludingLastDoneFallbacks(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        calendar: Calendar
    ) -> [RoutineLog] {
        var resolvedLogs = logs

        for task in tasks {
            guard let lastDone = task.lastDone else { continue }
            let hasCompletionLog = resolvedLogs.contains { log in
                guard log.taskID == task.id,
                      log.kind == .completed,
                      let timestamp = log.timestamp else {
                    return false
                }
                return calendar.isDate(timestamp, inSameDayAs: lastDone)
            }
            guard !hasCompletionLog else { continue }

            resolvedLogs.append(
                RoutineLog(
                    id: HomeOptimisticTimelineLogID.make(taskID: task.id, completionDate: lastDone),
                    timestamp: lastDone,
                    taskID: task.id,
                    kind: .completed
                )
            )
        }

        return resolvedLogs
    }

    private static func sortedTimelineLogs(_ logs: [RoutineLog]) -> [RoutineLog] {
        logs.sorted {
            let lhs = $0.timestamp ?? .distantPast
            let rhs = $1.timestamp ?? .distantPast
            return lhs > rhs
        }
    }
}

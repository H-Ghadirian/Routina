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
        persistedRelatedTagRules: [RoutineRelatedTagRule]
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

        return HomeTaskLoadSnapshot(
            tasks: reconciledTasks,
            places: detachedPlaces,
            goals: detachedGoals,
            timelineLogs: incomingLogs.sorted {
                let lhs = $0.timestamp ?? .distantPast
                let rhs = $1.timestamp ?? .distantPast
                return lhs > rhs
            },
            doneStats: doneStats,
            relatedTagRules: RoutineTagRelations.sanitized(
                persistedRelatedTagRules + RoutineTagRelations.learnedRules(from: reconciledTasks.map(\.tags))
            ),
            selectedTaskReloadGuard: reconciliation.selectedTaskReloadGuard
        )
    }
}

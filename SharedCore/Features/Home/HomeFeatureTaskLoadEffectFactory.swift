import ComposableArchitecture
import Foundation
import SwiftData

struct HomeFeatureTaskLoadEffectResult {
    var tasks: [RoutineTask]
    var places: [RoutinePlace]
    var goals: [RoutineGoal]
    var logs: [RoutineLog]
    var doneStats: HomeDoneStats
}

struct HomeFeatureTaskLoadEffectFactory<Action, CancelID: Hashable & Sendable> {
    var calendar: Calendar
    var cancelID: CancelID
    var modelContext: @MainActor @Sendable () -> ModelContext
    var loadedAction: @Sendable ([RoutineTask], [RoutinePlace], [RoutineGoal], [RoutineLog], HomeDoneStats) -> Action
    var failedAction: @Sendable () -> Action

    @MainActor
    func loadTasks() throws -> HomeFeatureTaskLoadEffectResult {
        let context = ModelContext(modelContext().container)
        try HomeDeduplicationSupport.enforceUniqueRoutineNames(in: context)
        try HomeDeduplicationSupport.enforceUniquePlaceNames(in: context)
        _ = try RoutineLogHistory.deduplicateRedundantSameDayLogs(in: context, calendar: calendar)
        _ = try RoutineLogHistory.backfillMissingLastDoneLogs(in: context)

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        return HomeFeatureTaskLoadEffectResult(
            tasks: tasks,
            places: places,
            goals: goals,
            logs: logs,
            doneStats: HomeTaskSupport.makeDoneStats(tasks: tasks, logs: logs)
        )
    }

    func loadTasksEffect() -> Effect<Action> {
        let loadTasks = self.loadTasks
        let loadedAction = self.loadedAction
        let failedAction = self.failedAction

        return .run { @MainActor send in
            do {
                let result = try loadTasks()
                send(
                    loadedAction(
                        result.tasks,
                        result.places,
                        result.goals,
                        result.logs,
                        result.doneStats
                    )
                )
            } catch {
                send(failedAction())
            }
        }
        .cancellable(id: cancelID, cancelInFlight: true)
    }
}

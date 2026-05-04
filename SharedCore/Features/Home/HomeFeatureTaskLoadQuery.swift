import Foundation
import SwiftData

struct HomeFeatureTaskLoadQuery {
    var calendar: Calendar

    @MainActor
    func load(from sourceContext: ModelContext) throws -> HomeFeatureTaskLoadEffectResult {
        let context = ModelContext(sourceContext.container)
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
}

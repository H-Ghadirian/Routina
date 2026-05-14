import SwiftData

struct SettingsTagPersistenceResult {
    var tagSummaries: [RoutineTagSummary]
    var cloudUsageEstimate: CloudUsageEstimate
    var updatedRoutineCount: Int
    var updatedGoalCount: Int
}

enum SettingsTagPersistence {
    @MainActor
    static func rename(
        _ request: SettingsTagRenameRequest,
        in context: ModelContext
    ) throws -> SettingsTagPersistenceResult {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        var updatedRoutineCount = 0
        var updatedGoalCount = 0

        for task in tasks where RoutineTag.contains(request.originalTagName, in: task.tags) {
            let updatedTags = RoutineTag.replacing(
                request.originalTagName,
                with: request.cleanedName,
                in: task.tags
            )
            if updatedTags != task.tags {
                task.tags = updatedTags
                updatedRoutineCount += 1
            }
        }

        for goal in goals where RoutineTag.contains(request.originalTagName, in: goal.tags) {
            let updatedTags = RoutineTag.replacing(
                request.originalTagName,
                with: request.cleanedName,
                in: goal.tags
            )
            if updatedTags != goal.tags {
                goal.tags = updatedTags
                updatedGoalCount += 1
            }
        }

        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .tag,
            entityTitle: request.cleanedName,
            details: "Renamed \(request.originalTagName)",
            in: context
        )
        try context.save()

        return SettingsTagPersistenceResult(
            tagSummaries: try SettingsDataQueries.fetchTagSummaries(in: context),
            cloudUsageEstimate: SettingsDataQueries.loadCloudUsageEstimate(in: context),
            updatedRoutineCount: updatedRoutineCount,
            updatedGoalCount: updatedGoalCount
        )
    }

    @MainActor
    static func delete(
        _ request: SettingsTagDeletionRequest,
        in context: ModelContext
    ) throws -> SettingsTagPersistenceResult {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        var updatedRoutineCount = 0
        var updatedGoalCount = 0

        for task in tasks where RoutineTag.contains(request.tagName, in: task.tags) {
            let updatedTags = RoutineTag.removing(request.tagName, from: task.tags)
            if updatedTags != task.tags {
                task.tags = updatedTags
                updatedRoutineCount += 1
            }
        }

        for goal in goals where RoutineTag.contains(request.tagName, in: goal.tags) {
            let updatedTags = RoutineTag.removing(request.tagName, from: goal.tags)
            if updatedTags != goal.tags {
                goal.tags = updatedTags
                updatedGoalCount += 1
            }
        }

        DeviceActivityRecorder.recordAction(
            .deleted,
            entity: .tag,
            entityTitle: request.tagName,
            in: context
        )
        try context.save()

        return SettingsTagPersistenceResult(
            tagSummaries: try SettingsDataQueries.fetchTagSummaries(in: context),
            cloudUsageEstimate: SettingsDataQueries.loadCloudUsageEstimate(in: context),
            updatedRoutineCount: updatedRoutineCount,
            updatedGoalCount: updatedGoalCount
        )
    }
}

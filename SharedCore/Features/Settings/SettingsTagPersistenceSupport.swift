import SwiftData

struct SettingsTagPersistenceResult {
    var tagSummaries: [RoutineTagSummary]
    var cloudUsageEstimate: CloudUsageEstimate
    var updatedRoutineCount: Int
}

enum SettingsTagPersistence {
    @MainActor
    static func rename(
        _ request: SettingsTagRenameRequest,
        in context: ModelContext
    ) throws -> SettingsTagPersistenceResult {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        var updatedRoutineCount = 0

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

        try context.save()

        return SettingsTagPersistenceResult(
            tagSummaries: try SettingsDataQueries.fetchTagSummaries(in: context),
            cloudUsageEstimate: SettingsDataQueries.loadCloudUsageEstimate(in: context),
            updatedRoutineCount: updatedRoutineCount
        )
    }

    @MainActor
    static func delete(
        _ request: SettingsTagDeletionRequest,
        in context: ModelContext
    ) throws -> SettingsTagPersistenceResult {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        var updatedRoutineCount = 0

        for task in tasks where RoutineTag.contains(request.tagName, in: task.tags) {
            let updatedTags = RoutineTag.removing(request.tagName, from: task.tags)
            if updatedTags != task.tags {
                task.tags = updatedTags
                updatedRoutineCount += 1
            }
        }

        try context.save()

        return SettingsTagPersistenceResult(
            tagSummaries: try SettingsDataQueries.fetchTagSummaries(in: context),
            cloudUsageEstimate: SettingsDataQueries.loadCloudUsageEstimate(in: context),
            updatedRoutineCount: updatedRoutineCount
        )
    }
}

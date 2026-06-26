import Foundation
import SwiftData

struct SettingsTagPersistenceResult {
    var tagSummaries: [RoutineTagSummary]
    var cloudUsageEstimate: CloudUsageEstimate
    var updatedRoutineCount: Int
    var updatedGoalCount: Int
    var updatedNoteCount: Int
    var updatedEventCount: Int
}

enum SettingsTagPersistence {
    @MainActor
    static func rename(
        _ request: SettingsTagRenameRequest,
        in context: ModelContext
    ) throws -> SettingsTagPersistenceResult {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let notes = SharedDefaults.app[.appSettingNotesEnabled]
            ? try context.fetch(FetchDescriptor<RoutineNote>())
            : []
        let events = try context.fetch(FetchDescriptor<RoutineEvent>())
        var updatedRoutineCount = 0
        var updatedGoalCount = 0
        var updatedNoteCount = 0
        var updatedEventCount = 0

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

        for note in notes where RoutineTag.contains(request.originalTagName, in: note.tags) {
            let updatedTags = RoutineTag.replacing(
                request.originalTagName,
                with: request.cleanedName,
                in: note.tags
            )
            if updatedTags != note.tags {
                note.tags = updatedTags
                note.updatedAt = Date()
                updatedNoteCount += 1
            }
        }

        for event in events where RoutineTag.contains(request.originalTagName, in: event.tags) {
            let updatedTags = RoutineTag.replacing(
                request.originalTagName,
                with: request.cleanedName,
                in: event.tags
            )
            if updatedTags != event.tags {
                event.tags = updatedTags
                event.updatedAt = Date()
                updatedEventCount += 1
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
            updatedGoalCount: updatedGoalCount,
            updatedNoteCount: updatedNoteCount,
            updatedEventCount: updatedEventCount
        )
    }

    @MainActor
    static func delete(
        _ request: SettingsTagDeletionRequest,
        in context: ModelContext
    ) throws -> SettingsTagPersistenceResult {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let notes = SharedDefaults.app[.appSettingNotesEnabled]
            ? try context.fetch(FetchDescriptor<RoutineNote>())
            : []
        let events = try context.fetch(FetchDescriptor<RoutineEvent>())
        var updatedRoutineCount = 0
        var updatedGoalCount = 0
        var updatedNoteCount = 0
        var updatedEventCount = 0

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

        for note in notes where RoutineTag.contains(request.tagName, in: note.tags) {
            let updatedTags = RoutineTag.removing(request.tagName, from: note.tags)
            if updatedTags != note.tags {
                note.tags = updatedTags
                note.updatedAt = Date()
                updatedNoteCount += 1
            }
        }

        for event in events where RoutineTag.contains(request.tagName, in: event.tags) {
            let updatedTags = RoutineTag.removing(request.tagName, from: event.tags)
            if updatedTags != event.tags {
                event.tags = updatedTags
                event.updatedAt = Date()
                updatedEventCount += 1
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
            updatedGoalCount: updatedGoalCount,
            updatedNoteCount: updatedNoteCount,
            updatedEventCount: updatedEventCount
        )
    }
}

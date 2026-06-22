import Foundation
import SwiftData

enum CloudKitDirectPullMergeHousekeeping {
    @MainActor
    static func deduplicateLogs(in context: ModelContext) throws {
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        var keptLogIDsByKey: [CloudKitDirectPullMergeSupport.LogDeduplicationKey: UUID] = [:]
        for log in logs {
            let key = CloudKitDirectPullMergeSupport.LogDeduplicationKey(
                taskID: log.taskID,
                timestamp: log.timestamp
            )
            if let keptLogID = keptLogIDsByKey[key], keptLogID != log.id {
                context.delete(log)
            } else {
                keptLogIDsByKey[key] = log.id
            }
        }
    }

    @MainActor
    static func deleteTaskAndRelatedRows(taskID: UUID, in context: ModelContext) throws {
        let taskDescriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        RoutineTask.removeRelationships(targeting: Set([taskID]), from: tasks)

        if let task = try context.fetch(taskDescriptor).first {
            context.delete(task)
        }

        try deleteRows(forTaskIDs: Set([taskID]), in: context)
    }

    @MainActor
    static func deleteOrphanedTaskRows(in context: ModelContext) throws {
        let taskIDs = Set(try context.fetch(FetchDescriptor<RoutineTask>()).map(\.id))
        let orphanedLogTaskIDs = try context.fetch(FetchDescriptor<RoutineLog>())
            .filter { !taskIDs.contains($0.taskID) }
            .map(\.taskID)
        let orphanedFocusTaskIDs = try context.fetch(FetchDescriptor<FocusSession>())
            .filter { $0.isTaskFocus && !taskIDs.contains($0.taskID) }
            .map(\.taskID)
        let orphanedAttachmentTaskIDs = try context.fetch(FetchDescriptor<RoutineAttachment>())
            .filter { !taskIDs.contains($0.taskID) }
            .map(\.taskID)
        let orphanedTaskIDs = Set(orphanedLogTaskIDs + orphanedFocusTaskIDs + orphanedAttachmentTaskIDs)

        guard !orphanedTaskIDs.isEmpty else { return }
        try deleteRows(forTaskIDs: orphanedTaskIDs, in: context)
    }

    @MainActor
    static func deduplicatePlaces(in context: ModelContext) throws -> [UUID: UUID] {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let linkedCounts = tasks.reduce(into: [UUID: Int]()) { partialResult, task in
            for placeID in task.placeIDs {
                partialResult[placeID, default: 0] += 1
            }
        }

        var placesByNormalizedName: [String: [RoutinePlace]] = [:]
        var mergedPlaceIDs: [UUID: UUID] = [:]

        for place in places {
            guard let normalizedName = RoutinePlace.normalizedName(place.name) else { continue }
            placesByNormalizedName[normalizedName, default: []].append(place)
        }

        for sameNamedPlaces in placesByNormalizedName.values {
            guard sameNamedPlaces.count > 1 else { continue }

            let keeper = CloudKitDirectPullMergeSupport.preferredPlaceToKeep(
                from: sameNamedPlaces,
                linkedCounts: linkedCounts
            )
            mergedPlaceIDs[keeper.id] = keeper.id
            for place in sameNamedPlaces where place.id != keeper.id {
                try migratePlaceReferences(from: place.id, to: keeper.id, in: context)
                context.delete(place)
                mergedPlaceIDs[place.id] = keeper.id
            }
        }

        return mergedPlaceIDs
    }

    @MainActor
    static func migrateLogs(
        from sourceTaskID: UUID,
        to targetTaskID: UUID,
        in context: ModelContext
    ) throws {
        guard sourceTaskID != targetTaskID else { return }

        let descriptor = FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == sourceTaskID
            }
        )

        for log in try context.fetch(descriptor) {
            log.taskID = targetTaskID
        }
    }

    @MainActor
    static func migratePlaceReferences(
        from sourcePlaceID: UUID,
        to targetPlaceID: UUID,
        in context: ModelContext
    ) throws {
        guard sourcePlaceID != targetPlaceID else { return }

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks where task.placeIDs.contains(sourcePlaceID) {
            task.placeIDs = task.placeIDs.map { $0 == sourcePlaceID ? targetPlaceID : $0 }
        }
    }

    @MainActor
    static func migrateGoalReferences(
        from sourceGoalID: UUID,
        to targetGoalID: UUID,
        in context: ModelContext
    ) throws {
        guard sourceGoalID != targetGoalID else { return }

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks where task.goalIDs.contains(sourceGoalID) {
            task.goalIDs = RoutineGoalIDStorage.sanitized(
                task.goalIDs.map { $0 == sourceGoalID ? targetGoalID : $0 }
            )
        }

        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        for goal in goals where goal.parentGoalID == sourceGoalID {
            goal.parentGoalID = targetGoalID == goal.id ? nil : targetGoalID
        }
    }

    @MainActor
    private static func deleteRows(
        forTaskIDs taskIDs: Set<UUID>,
        in context: ModelContext
    ) throws {
        guard !taskIDs.isEmpty else { return }

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        for log in logs where taskIDs.contains(log.taskID) {
            context.delete(log)
        }

        let focusSessions = try context.fetch(FetchDescriptor<FocusSession>())
        for session in focusSessions where session.isTaskFocus && taskIDs.contains(session.taskID) {
            context.delete(session)
        }

        let attachments = try context.fetch(FetchDescriptor<RoutineAttachment>())
        for attachment in attachments where taskIDs.contains(attachment.taskID) {
            context.delete(attachment)
        }
    }
}

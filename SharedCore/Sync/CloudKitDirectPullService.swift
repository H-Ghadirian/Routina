import CloudKit
import Foundation
import SwiftData

enum CloudKitDirectPullService {
    struct PullResult {
        var changedRecords: [CKRecord]
        var deletedRecordIDs: [CKRecord.ID]
    }

    @MainActor
    static func pullLatestIntoLocalStore(
        containerIdentifier: String,
        modelContext: ModelContext
    ) async throws {
        let result = try await CloudKitDirectPullFetcher.fetchZoneChanges(
            containerIdentifier: containerIdentifier
        )
        try merge(result: result, into: modelContext)
    }

    @MainActor
    static func mergeForTesting(
        _ result: PullResult,
        into context: ModelContext
    ) throws {
        try merge(result: result, into: context)
    }

    @MainActor
    private static func merge(result: PullResult, into context: ModelContext) throws {
        var mergedPlaceIDs = try CloudKitDirectPullMergeHousekeeping.deduplicatePlaces(in: context)
        var mergedGoalIDs: [UUID: UUID] = [:]
        var mergedTaskIDs: [UUID: UUID] = [:]
        let payloadBatch = CloudKitDirectPullPayloadBatch.make(from: result.changedRecords)

        for placePayload in payloadBatch.placePayloads {
            mergedPlaceIDs[placePayload.id] = try upsertPlace(placePayload, in: context)
        }

        for goalPayload in payloadBatch.goalPayloads {
            mergedGoalIDs[goalPayload.id] = try upsertGoal(goalPayload, in: context)
        }

        for taskPayload in payloadBatch.taskPayloads {
            var canonicalPayload = taskPayload
            canonicalPayload.placeID = canonicalPayload.placeID.flatMap { placeID in
                CloudKitDirectPullCanonicalIDResolver.canonicalPlaceID(
                    for: placeID,
                    mergedPlaceIDs: mergedPlaceIDs,
                    in: context
                )
            }
            canonicalPayload.goalIDs = canonicalPayload.goalIDs?.map { goalID in
                CloudKitDirectPullCanonicalIDResolver.canonicalGoalID(
                    for: goalID,
                    mergedGoalIDs: mergedGoalIDs,
                    in: context
                )
            }
            mergedTaskIDs[taskPayload.id] = try upsertTask(canonicalPayload, in: context)
        }

        for logPayload in payloadBatch.logPayloads {
            var canonicalPayload = logPayload
            canonicalPayload.taskID = mergedTaskIDs[logPayload.taskID]
                ?? CloudKitDirectPullCanonicalIDResolver.canonicalTaskID(
                    for: logPayload.taskID,
                    in: context
                )
            try upsertLog(canonicalPayload, in: context)
        }

        for (sourcePlaceID, targetPlaceID) in mergedPlaceIDs where sourcePlaceID != targetPlaceID {
            try CloudKitDirectPullMergeHousekeeping.migratePlaceReferences(
                from: sourcePlaceID,
                to: targetPlaceID,
                in: context
            )
        }

        for (sourceTaskID, targetTaskID) in mergedTaskIDs where sourceTaskID != targetTaskID {
            try CloudKitDirectPullMergeHousekeeping.migrateLogs(
                from: sourceTaskID,
                to: targetTaskID,
                in: context
            )
        }

        try CloudKitDirectPullDeletionHandler.applyDeletedRecordIDs(
            result.deletedRecordIDs,
            mergedTaskIDs: mergedTaskIDs,
            mergedPlaceIDs: mergedPlaceIDs,
            mergedGoalIDs: mergedGoalIDs,
            in: context
        )

        try CloudKitDirectPullMergeHousekeeping.deduplicateLogs(in: context)

        if context.hasChanges {
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
        }
    }

    @MainActor
    private static func upsertGoal(_ payload: GoalPayload, in context: ModelContext) throws -> UUID {
        let payloadID = payload.id
        let descriptor = FetchDescriptor<RoutineGoal>(
            predicate: #Predicate { goal in
                goal.id == payloadID
            }
        )
        let normalizedIncomingTitle = RoutineGoal.normalizedTitle(payload.title)

        if let existing = try RoutineDuplicateIDCleanup.canonical(
            descriptor,
            in: context,
            rank: { $0.createdAt ?? .distantPast }
        ) {
            CloudKitDirectPullGoalPayloadApplier.apply(payload, to: existing)
            return existing.id
        }

        if let normalizedIncomingTitle,
           let goalWithSameTitle = try goal(matchingNormalizedTitle: normalizedIncomingTitle, in: context) {
            CloudKitDirectPullGoalPayloadApplier.apply(payload, to: goalWithSameTitle)
            return goalWithSameTitle.id
        }

        context.insert(CloudKitDirectPullGoalPayloadApplier.makeGoal(from: payload))
        return payload.id
    }

    @MainActor
    private static func upsertPlace(_ payload: PlacePayload, in context: ModelContext) throws -> UUID {
        let payloadID = payload.id
        let descriptor = FetchDescriptor<RoutinePlace>(
            predicate: #Predicate { place in
                place.id == payloadID
            }
        )
        let normalizedIncomingName = RoutinePlace.normalizedName(payload.name)

        if let existing = try RoutineDuplicateIDCleanup.canonical(
            descriptor,
            in: context,
            rank: { $0.createdAt }
        ) {
            CloudKitDirectPullPlacePayloadApplier.apply(payload, to: existing, updatesName: true)
            return existing.id
        }

        if let normalizedIncomingName,
           let placeWithSameName = try place(matchingNormalizedName: normalizedIncomingName, in: context) {
            CloudKitDirectPullPlacePayloadApplier.apply(payload, to: placeWithSameName, updatesName: false)
            return placeWithSameName.id
        }

        context.insert(CloudKitDirectPullPlacePayloadApplier.makePlace(from: payload))
        return payload.id
    }

    @MainActor
    private static func upsertTask(_ payload: TaskPayload, in context: ModelContext) throws -> UUID {
        let payloadID = payload.id
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == payloadID
            }
        )
        let normalizedIncomingName = RoutineTask.normalizedName(payload.name)

        if let existing = try RoutineDuplicateIDCleanup.canonical(
            descriptor,
            in: context,
            rank: { $0.lastDone ?? $0.createdAt ?? .distantPast }
        ) {
            if let normalizedIncomingName,
               let taskWithSameName = try task(matchingNormalizedName: normalizedIncomingName, in: context),
               taskWithSameName.id != existing.id {
                // Keep local uniqueness invariant if cloud data contains a duplicate name.
                CloudKitDirectPullTaskPayloadApplier.apply(payload, to: taskWithSameName, updatesName: true)
                try CloudKitDirectPullMergeHousekeeping.migrateLogs(
                    from: existing.id,
                    to: taskWithSameName.id,
                    in: context
                )
                return taskWithSameName.id
            }

            CloudKitDirectPullTaskPayloadApplier.apply(payload, to: existing, updatesName: true)
            return existing.id
        } else {
            if let normalizedIncomingName,
               let taskWithSameName = try task(matchingNormalizedName: normalizedIncomingName, in: context) {
                CloudKitDirectPullTaskPayloadApplier.apply(payload, to: taskWithSameName, updatesName: false)
                try CloudKitDirectPullMergeHousekeeping.migrateLogs(
                    from: payload.id,
                    to: taskWithSameName.id,
                    in: context
                )
                return taskWithSameName.id
            }

            context.insert(CloudKitDirectPullTaskPayloadApplier.makeTask(from: payload))
            return payload.id
        }
    }

    @MainActor
    private static func upsertLog(_ payload: LogPayload, in context: ModelContext) throws {
        let payloadID = payload.id
        let descriptor = FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.id == payloadID
            }
        )

        if let existing = try RoutineDuplicateIDCleanup.canonical(
            descriptor,
            in: context,
            rank: { $0.timestamp ?? .distantPast }
        ) {
            CloudKitDirectPullLogPayloadApplier.apply(payload, to: existing)
        } else if let existing = try existingLog(matching: payload, in: context) {
            CloudKitDirectPullLogPayloadApplier.apply(payload, to: existing)
        } else {
            context.insert(CloudKitDirectPullLogPayloadApplier.makeLog(from: payload))
        }
    }

    @MainActor
    private static func existingLog(
        matching payload: LogPayload,
        in context: ModelContext
    ) throws -> RoutineLog? {
        let taskID = payload.taskID
        let descriptor = FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            }
        )

        return try context.fetch(descriptor).first { log in
            CloudKitDirectPullMergeSupport.timestampsMatch(log.timestamp, payload.timestamp)
        }
    }

    @MainActor
    private static func task(
        matchingNormalizedName normalizedName: String,
        in context: ModelContext
    ) throws -> RoutineTask? {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return tasks.first { task in
            RoutineTask.normalizedName(task.name) == normalizedName
        }
    }

    @MainActor
    private static func goal(
        matchingNormalizedTitle normalizedTitle: String,
        in context: ModelContext
    ) throws -> RoutineGoal? {
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        return goals.first { goal in
            RoutineGoal.normalizedTitle(goal.title) == normalizedTitle
        }
    }

    @MainActor
    private static func place(
        matchingNormalizedName normalizedName: String,
        in context: ModelContext
    ) throws -> RoutinePlace? {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let linkedCounts = tasks.reduce(into: [UUID: Int]()) { partialResult, task in
            guard let placeID = task.placeID else { return }
            partialResult[placeID, default: 0] += 1
        }

        let matchingPlaces = places.filter { place in
            RoutinePlace.normalizedName(place.name) == normalizedName
        }

        guard !matchingPlaces.isEmpty else { return nil }
        return CloudKitDirectPullMergeSupport.preferredPlaceToKeep(
            from: matchingPlaces,
            linkedCounts: linkedCounts
        )
    }
}

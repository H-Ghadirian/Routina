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
            mergedPlaceIDs[placePayload.id] = try CloudKitDirectPullUpserter.upsertPlace(
                placePayload,
                in: context
            )
        }

        for goalPayload in payloadBatch.goalPayloads {
            mergedGoalIDs[goalPayload.id] = try CloudKitDirectPullUpserter.upsertGoal(
                goalPayload,
                in: context
            )
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
            mergedTaskIDs[taskPayload.id] = try CloudKitDirectPullUpserter.upsertTask(
                canonicalPayload,
                in: context
            )
        }

        for logPayload in payloadBatch.logPayloads {
            var canonicalPayload = logPayload
            canonicalPayload.taskID = mergedTaskIDs[logPayload.taskID]
                ?? CloudKitDirectPullCanonicalIDResolver.canonicalTaskID(
                    for: logPayload.taskID,
                    in: context
                )
            try CloudKitDirectPullUpserter.upsertLog(canonicalPayload, in: context)
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

}

import CloudKit
import Foundation
import SwiftData

enum CloudKitDirectPullService {
    @MainActor
    private static var isActiveFocusReconciliationInFlight = false

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

    /// Reconciles Focus state after an app launch or foreground transition.
    /// SwiftData normally imports CloudKit changes on its own, but an active
    /// timer that started on another device must also be discoverable before
    /// that asynchronous import arrives.
    @MainActor
    static func reconcileActiveFocusIfNeeded(
        containerIdentifier: String?,
        modelContext: ModelContext
    ) async {
        await reconcileActiveFocusIfNeeded(
            containerIdentifier: containerIdentifier,
            modelContext: modelContext,
            pullLatest: { containerIdentifier, modelContext in
                try await pullLatestIntoLocalStore(
                    containerIdentifier: containerIdentifier,
                    modelContext: modelContext
                )
            }
        )
    }

    @MainActor
    static func reconcileActiveFocusIfNeeded(
        containerIdentifier: String?,
        modelContext: ModelContext,
        pullLatest: @MainActor (_ containerIdentifier: String, _ modelContext: ModelContext) async throws -> Void,
        retryDelay: Duration = .seconds(2)
    ) async {
        guard let containerIdentifier, !containerIdentifier.isEmpty else { return }
        guard !isActiveFocusReconciliationInFlight else { return }
        isActiveFocusReconciliationInFlight = true
        defer { isActiveFocusReconciliationInFlight = false }

        do {
            try await pullLatest(containerIdentifier, modelContext)

            // A just-started or just-finished timer can race the originating
            // device's CloudKit export. One short retry closes that narrow gap
            // without polling.
            guard try hasActiveFocus(in: modelContext) else { return }
            if retryDelay > .zero {
                try? await Task.sleep(for: retryDelay)
            }
            guard try hasActiveFocus(in: modelContext) else { return }
            try await pullLatest(containerIdentifier, modelContext)
        } catch {
            NSLog("Focus-session CloudKit reconciliation failed: \(error.localizedDescription)")
        }
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
            canonicalPayload.placeIDs = canonicalPayload.placeIDs?.compactMap { placeID in
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

        for focusSessionPayload in payloadBatch.focusSessionPayloads {
            var canonicalPayload = focusSessionPayload
            if canonicalPayload.taskID != FocusSession.unassignedTaskID {
                canonicalPayload.taskID = mergedTaskIDs[focusSessionPayload.taskID]
                    ?? CloudKitDirectPullCanonicalIDResolver.canonicalTaskID(
                        for: focusSessionPayload.taskID,
                        in: context
                    )
            }
            try CloudKitDirectPullUpserter.upsertFocusSession(canonicalPayload, in: context)
        }

        for sprintFocusSessionPayload in payloadBatch.sprintFocusSessionPayloads {
            try CloudKitDirectPullUpserter.upsertSprintFocusSession(
                sprintFocusSessionPayload,
                in: context
            )
        }

        for (sourcePlaceID, targetPlaceID) in mergedPlaceIDs where sourcePlaceID != targetPlaceID {
            try CloudKitDirectPullMergeHousekeeping.migratePlaceReferences(
                from: sourcePlaceID,
                to: targetPlaceID,
                in: context
            )
        }

        for (sourceGoalID, targetGoalID) in mergedGoalIDs where sourceGoalID != targetGoalID {
            try CloudKitDirectPullMergeHousekeeping.migrateGoalReferences(
                from: sourceGoalID,
                to: targetGoalID,
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

        try CloudKitDirectPullMergeHousekeeping.deleteOrphanedTaskRows(in: context)
        try CloudKitDirectPullMergeHousekeeping.deduplicateLogs(in: context)

        if context.hasChanges {
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
        }
    }

    @MainActor
    private static func hasActiveFocus(in context: ModelContext) throws -> Bool {
        let activeFocusPredicate = #Predicate<FocusSession> { session in
            session.completedAt == nil && session.abandonedAt == nil
        }
        var focusDescriptor = FetchDescriptor<FocusSession>(predicate: activeFocusPredicate)
        focusDescriptor.fetchLimit = 1
        if try context.fetch(focusDescriptor).isEmpty == false {
            return true
        }

        let activeSprintFocusPredicate = #Predicate<SprintFocusSessionRecord> { session in
            session.stoppedAt == nil
        }
        var sprintDescriptor = FetchDescriptor<SprintFocusSessionRecord>(predicate: activeSprintFocusPredicate)
        sprintDescriptor.fetchLimit = 1
        return try context.fetch(sprintDescriptor).isEmpty == false
    }

}

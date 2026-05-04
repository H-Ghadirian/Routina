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
        var mergedPlaceIDs = try deduplicatePlaces(in: context)
        var mergedGoalIDs: [UUID: UUID] = [:]
        var mergedTaskIDs: [UUID: UUID] = [:]
        var placePayloads: [PlacePayload] = []
        var goalPayloads: [GoalPayload] = []
        var taskPayloads: [TaskPayload] = []
        var logPayloads: [LogPayload] = []

        for record in result.changedRecords {
            if let goalPayload = CloudKitDirectPullRecordParser.parseGoal(from: record) {
                goalPayloads.append(goalPayload)
                continue
            }

            if let placePayload = CloudKitDirectPullRecordParser.parsePlace(from: record) {
                placePayloads.append(placePayload)
                continue
            }

            if let taskPayload = CloudKitDirectPullTaskRecordParser.parse(from: record) {
                taskPayloads.append(taskPayload)
                continue
            }

            if let logPayload = CloudKitDirectPullRecordParser.parseLog(from: record) {
                logPayloads.append(logPayload)
            }
        }

        for placePayload in placePayloads {
            mergedPlaceIDs[placePayload.id] = try upsertPlace(placePayload, in: context)
        }

        for goalPayload in goalPayloads {
            mergedGoalIDs[goalPayload.id] = try upsertGoal(goalPayload, in: context)
        }

        for taskPayload in taskPayloads {
            var canonicalPayload = taskPayload
            canonicalPayload.placeID = canonicalPayload.placeID.flatMap { placeID in
                canonicalPlaceID(for: placeID, mergedPlaceIDs: mergedPlaceIDs, in: context)
            }
            canonicalPayload.goalIDs = canonicalPayload.goalIDs?.map { goalID in
                canonicalGoalID(for: goalID, mergedGoalIDs: mergedGoalIDs, in: context)
            }
            mergedTaskIDs[taskPayload.id] = try upsertTask(canonicalPayload, in: context)
        }

        for logPayload in logPayloads {
            var canonicalPayload = logPayload
            canonicalPayload.taskID = mergedTaskIDs[logPayload.taskID]
                ?? canonicalTaskID(for: logPayload.taskID, in: context)
            try upsertLog(canonicalPayload, in: context)
        }

        for (sourcePlaceID, targetPlaceID) in mergedPlaceIDs where sourcePlaceID != targetPlaceID {
            try migratePlaceReferences(from: sourcePlaceID, to: targetPlaceID, in: context)
        }

        for (sourceTaskID, targetTaskID) in mergedTaskIDs where sourceTaskID != targetTaskID {
            try migrateLogs(from: sourceTaskID, to: targetTaskID, in: context)
        }

        try CloudKitDirectPullDeletionHandler.applyDeletedRecordIDs(
            result.deletedRecordIDs,
            mergedTaskIDs: mergedTaskIDs,
            mergedPlaceIDs: mergedPlaceIDs,
            mergedGoalIDs: mergedGoalIDs,
            in: context
        )

        try deduplicateLogs(in: context)

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
            update(existing, with: payload)
            return existing.id
        }

        if let normalizedIncomingTitle,
           let goalWithSameTitle = try goal(matchingNormalizedTitle: normalizedIncomingTitle, in: context) {
            update(goalWithSameTitle, with: payload)
            return goalWithSameTitle.id
        }

        context.insert(
            RoutineGoal(
                id: payload.id,
                title: RoutineGoal.cleanedTitle(payload.title) ?? "Goal",
                emoji: payload.emoji,
                notes: payload.notes,
                targetDate: payload.targetDate,
                status: payload.status ?? .active,
                color: payload.color ?? .none,
                createdAt: payload.createdAt ?? Date(),
                sortOrder: payload.sortOrder ?? 0
            )
        )
        return payload.id
    }

    private static func update(_ goal: RoutineGoal, with payload: GoalPayload) {
        goal.title = RoutineGoal.cleanedTitle(payload.title) ?? goal.displayTitle
        goal.emoji = RoutineGoal.cleanedEmoji(payload.emoji)
        goal.notes = payload.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        goal.targetDate = payload.targetDate
        if let status = payload.status {
            goal.status = status
        }
        if let color = payload.color {
            goal.color = color
        }
        if let createdAt = payload.createdAt {
            goal.createdAt = createdAt
        }
        if let sortOrder = payload.sortOrder {
            goal.sortOrder = sortOrder
        }
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
            existing.name = RoutinePlace.cleanedName(payload.name) ?? existing.displayName
            existing.latitude = payload.latitude
            existing.longitude = payload.longitude
            existing.radiusMeters = max(payload.radiusMeters, 25)
            if let createdAt = payload.createdAt {
                existing.createdAt = createdAt
            }
            return existing.id
        }

        if let normalizedIncomingName,
           let placeWithSameName = try place(matchingNormalizedName: normalizedIncomingName, in: context) {
            placeWithSameName.latitude = payload.latitude
            placeWithSameName.longitude = payload.longitude
            placeWithSameName.radiusMeters = max(payload.radiusMeters, 25)
            if let createdAt = payload.createdAt {
                placeWithSameName.createdAt = createdAt
            }
            return placeWithSameName.id
        }

        context.insert(
            RoutinePlace(
                id: payload.id,
                name: RoutinePlace.cleanedName(payload.name) ?? "Place",
                latitude: payload.latitude,
                longitude: payload.longitude,
                radiusMeters: payload.radiusMeters,
                createdAt: payload.createdAt ?? Date()
            )
        )
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
                try migrateLogs(from: existing.id, to: taskWithSameName.id, in: context)
                return taskWithSameName.id
            }

            CloudKitDirectPullTaskPayloadApplier.apply(payload, to: existing, updatesName: true)
            return existing.id
        } else {
            if let normalizedIncomingName,
               let taskWithSameName = try task(matchingNormalizedName: normalizedIncomingName, in: context) {
                CloudKitDirectPullTaskPayloadApplier.apply(payload, to: taskWithSameName, updatesName: false)
                try migrateLogs(from: payload.id, to: taskWithSameName.id, in: context)
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
            existing.timestamp = payload.timestamp
            existing.taskID = payload.taskID
            existing.kind = payload.kind
            existing.actualDurationMinutes = payload.actualDurationMinutes
        } else if let existing = try existingLog(matching: payload, in: context) {
            existing.timestamp = payload.timestamp
            existing.taskID = payload.taskID
            existing.kind = payload.kind
            existing.actualDurationMinutes = payload.actualDurationMinutes
        } else {
            context.insert(
                RoutineLog(
                    id: payload.id,
                    timestamp: payload.timestamp,
                    taskID: payload.taskID,
                    kind: payload.kind,
                    actualDurationMinutes: payload.actualDurationMinutes
                )
            )
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
    private static func deduplicateLogs(in context: ModelContext) throws {
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
    private static func deduplicatePlaces(in context: ModelContext) throws -> [UUID: UUID] {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let linkedCounts = tasks.reduce(into: [UUID: Int]()) { partialResult, task in
            guard let placeID = task.placeID else { return }
            partialResult[placeID, default: 0] += 1
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
    private static func migrateLogs(
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
    private static func migratePlaceReferences(
        from sourcePlaceID: UUID,
        to targetPlaceID: UUID,
        in context: ModelContext
    ) throws {
        guard sourcePlaceID != targetPlaceID else { return }

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks where task.placeID == sourcePlaceID {
            task.placeID = targetPlaceID
        }
    }

    @MainActor
    private static func canonicalTaskID(for taskID: UUID, in context: ModelContext) -> UUID {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
        let task = try? context.fetch(descriptor).first
        return task?.id ?? taskID
    }

    @MainActor
    private static func canonicalGoalID(
        for goalID: UUID,
        mergedGoalIDs: [UUID: UUID],
        in context: ModelContext
    ) -> UUID {
        var currentGoalID = goalID
        var visitedGoalIDs: Set<UUID> = []

        while let nextGoalID = mergedGoalIDs[currentGoalID], nextGoalID != currentGoalID {
            guard visitedGoalIDs.insert(currentGoalID).inserted else { break }
            currentGoalID = nextGoalID
        }

        let descriptor = FetchDescriptor<RoutineGoal>(
            predicate: #Predicate { goal in
                goal.id == currentGoalID
            }
        )
        let goal = try? context.fetch(descriptor).first
        return goal?.id ?? currentGoalID
    }

    @MainActor
    private static func canonicalPlaceID(
        for placeID: UUID,
        mergedPlaceIDs: [UUID: UUID],
        in context: ModelContext
    ) -> UUID {
        var currentPlaceID = placeID
        var visitedPlaceIDs: Set<UUID> = []

        while let nextPlaceID = mergedPlaceIDs[currentPlaceID], nextPlaceID != currentPlaceID {
            guard visitedPlaceIDs.insert(currentPlaceID).inserted else { break }
            currentPlaceID = nextPlaceID
        }

        let descriptor = FetchDescriptor<RoutinePlace>(
            predicate: #Predicate { place in
                place.id == currentPlaceID
            }
        )
        let place = try? context.fetch(descriptor).first
        return place?.id ?? currentPlaceID
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

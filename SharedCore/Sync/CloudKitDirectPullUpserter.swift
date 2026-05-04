import Foundation
import SwiftData

enum CloudKitDirectPullUpserter {
    typealias GoalPayload = CloudKitDirectPullService.GoalPayload
    typealias PlacePayload = CloudKitDirectPullService.PlacePayload
    typealias TaskPayload = CloudKitDirectPullService.TaskPayload
    typealias LogPayload = CloudKitDirectPullService.LogPayload

    @MainActor
    static func upsertGoal(_ payload: GoalPayload, in context: ModelContext) throws -> UUID {
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
           let goalWithSameTitle = try CloudKitDirectPullEntityLookup.goal(
            matchingNormalizedTitle: normalizedIncomingTitle,
            in: context
           ) {
            CloudKitDirectPullGoalPayloadApplier.apply(payload, to: goalWithSameTitle)
            return goalWithSameTitle.id
        }

        context.insert(CloudKitDirectPullGoalPayloadApplier.makeGoal(from: payload))
        return payload.id
    }

    @MainActor
    static func upsertPlace(_ payload: PlacePayload, in context: ModelContext) throws -> UUID {
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
           let placeWithSameName = try CloudKitDirectPullEntityLookup.place(
            matchingNormalizedName: normalizedIncomingName,
            in: context
           ) {
            CloudKitDirectPullPlacePayloadApplier.apply(payload, to: placeWithSameName, updatesName: false)
            return placeWithSameName.id
        }

        context.insert(CloudKitDirectPullPlacePayloadApplier.makePlace(from: payload))
        return payload.id
    }

    @MainActor
    static func upsertTask(_ payload: TaskPayload, in context: ModelContext) throws -> UUID {
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
               let taskWithSameName = try CloudKitDirectPullEntityLookup.task(
                matchingNormalizedName: normalizedIncomingName,
                in: context
               ),
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
               let taskWithSameName = try CloudKitDirectPullEntityLookup.task(
                matchingNormalizedName: normalizedIncomingName,
                in: context
               ) {
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
    static func upsertLog(_ payload: LogPayload, in context: ModelContext) throws {
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
        } else if let existing = try CloudKitDirectPullEntityLookup.existingLog(
            matching: payload,
            in: context
        ) {
            CloudKitDirectPullLogPayloadApplier.apply(payload, to: existing)
        } else {
            context.insert(CloudKitDirectPullLogPayloadApplier.makeLog(from: payload))
        }
    }
}

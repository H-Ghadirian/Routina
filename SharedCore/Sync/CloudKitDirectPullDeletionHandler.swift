import CloudKit
import Foundation
import SwiftData

enum CloudKitDirectPullDeletionHandler {
    @MainActor
    static func applyDeletedRecordIDs(
        _ recordIDs: [CKRecord.ID],
        mergedTaskIDs: [UUID: UUID],
        mergedPlaceIDs: [UUID: UUID],
        mergedGoalIDs: [UUID: UUID],
        in context: ModelContext
    ) throws {
        for recordID in recordIDs {
            guard let id = UUID(uuidString: recordID.recordName) else { continue }
            if shouldIgnoreDeletedRecord(
                id,
                mergedTaskIDs: mergedTaskIDs,
                mergedPlaceIDs: mergedPlaceIDs,
                mergedGoalIDs: mergedGoalIDs
            ) {
                continue
            }

            if try deleteGoal(id: id, in: context) {
                continue
            }

            if try deletePlace(id: id, in: context) {
                continue
            }

            try deleteTask(id: id, in: context)
            try deleteLog(id: id, in: context)
        }
    }

    private static func shouldIgnoreDeletedRecord(
        _ id: UUID,
        mergedTaskIDs: [UUID: UUID],
        mergedPlaceIDs: [UUID: UUID],
        mergedGoalIDs: [UUID: UUID]
    ) -> Bool {
        if let targetTaskID = mergedTaskIDs[id], targetTaskID != id {
            return true
        }
        if let targetPlaceID = mergedPlaceIDs[id], targetPlaceID != id {
            return true
        }
        if let targetGoalID = mergedGoalIDs[id], targetGoalID != id {
            return true
        }
        return false
    }

    @MainActor
    private static func deleteGoal(id: UUID, in context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<RoutineGoal>(
            predicate: #Predicate { goal in
                goal.id == id
            }
        )
        guard let goal = try context.fetch(descriptor).first else { return false }
        context.delete(goal)
        try clearGoalReference(goalID: id, in: context)
        return true
    }

    @MainActor
    private static func deletePlace(id: UUID, in context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<RoutinePlace>(
            predicate: #Predicate { place in
                place.id == id
            }
        )
        guard let place = try context.fetch(descriptor).first else { return false }
        context.delete(place)
        try clearPlaceReference(placeID: id, in: context)
        return true
    }

    @MainActor
    private static func deleteTask(id: UUID, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == id
            }
        )
        if let task = try context.fetch(descriptor).first {
            context.delete(task)
        }
    }

    @MainActor
    private static func deleteLog(id: UUID, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.id == id
            }
        )
        if let log = try context.fetch(descriptor).first {
            context.delete(log)
        }
    }

    @MainActor
    private static func clearPlaceReference(placeID: UUID, in context: ModelContext) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks where task.placeID == placeID {
            task.placeID = nil
        }
    }

    @MainActor
    private static func clearGoalReference(goalID: UUID, in context: ModelContext) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks where task.goalIDs.contains(goalID) {
            task.goalIDs = task.goalIDs.filter { $0 != goalID }
        }
    }
}

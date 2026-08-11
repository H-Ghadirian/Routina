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
        let deletedIDs = Set(recordIDs.compactMap { UUID(uuidString: $0.recordName) })
            .filter {
                !shouldIgnoreDeletedRecord(
                    $0,
                    mergedTaskIDs: mergedTaskIDs,
                    mergedPlaceIDs: mergedPlaceIDs,
                    mergedGoalIDs: mergedGoalIDs
                )
            }
        guard !deletedIDs.isEmpty else { return }

        // A zone fetch can contain hundreds of tombstones. Fetch every affected
        // model family once, then apply the complete deletion set. Repeating
        // these full-history scans for each record freezes foreground UI.
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let events = try context.fetch(FetchDescriptor<RoutineEvent>())

        let deletedTaskIDs = Set(tasks.lazy.map(\.id)).intersection(deletedIDs)
        let deletedGoalIDs = Set(goals.lazy.map(\.id)).intersection(deletedIDs)
        let deletedPlaceIDs = Set(places.lazy.map(\.id)).intersection(deletedIDs)
        let deletedEventIDs = Set(events.lazy.map(\.id)).intersection(deletedIDs)

        if !deletedTaskIDs.isEmpty {
            RoutineTask.removeRelationships(targeting: deletedTaskIDs, from: tasks)
            for task in tasks where deletedTaskIDs.contains(task.id) {
                context.delete(task)
            }
            try CloudKitDirectPullMergeHousekeeping.deleteRows(
                forTaskIDs: deletedTaskIDs,
                in: context
            )
        }

        for goal in goals where deletedGoalIDs.contains(goal.id) {
            context.delete(goal)
        }
        for place in places where deletedPlaceIDs.contains(place.id) {
            context.delete(place)
        }
        for event in events where deletedEventIDs.contains(event.id) {
            context.delete(event)
        }

        for task in tasks where !deletedTaskIDs.contains(task.id) {
            if !deletedGoalIDs.isEmpty, task.goalIDs.contains(where: deletedGoalIDs.contains) {
                task.goalIDs = task.goalIDs.filter { !deletedGoalIDs.contains($0) }
            }
            if !deletedPlaceIDs.isEmpty, task.placeIDs.contains(where: deletedPlaceIDs.contains) {
                task.placeIDs = task.placeIDs.filter { !deletedPlaceIDs.contains($0) }
            }
            if !deletedEventIDs.isEmpty, task.eventIDs.contains(where: deletedEventIDs.contains) {
                task.eventIDs = task.eventIDs.filter { !deletedEventIDs.contains($0) }
            }
        }

        for goal in goals where !deletedGoalIDs.contains(goal.id) {
            if let parentGoalID = goal.parentGoalID, deletedGoalIDs.contains(parentGoalID) {
                goal.parentGoalID = nil
            }
        }

        let directLogIDs = deletedIDs.subtracting(deletedTaskIDs)
        guard !directLogIDs.isEmpty else { return }
        for log in try context.fetch(FetchDescriptor<RoutineLog>()) where directLogIDs.contains(log.id) {
            context.delete(log)
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

}

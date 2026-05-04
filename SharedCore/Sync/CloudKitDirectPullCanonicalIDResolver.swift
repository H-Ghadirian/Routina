import Foundation
import SwiftData

enum CloudKitDirectPullCanonicalIDResolver {
    @MainActor
    static func canonicalTaskID(for taskID: UUID, in context: ModelContext) -> UUID {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
        let task = try? context.fetch(descriptor).first
        return task?.id ?? taskID
    }

    @MainActor
    static func canonicalGoalID(
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
    static func canonicalPlaceID(
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
}

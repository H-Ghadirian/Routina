import Foundation
import SwiftData

enum CloudKitDirectPullEntityLookup {
    @MainActor
    static func existingLog(
        matching payload: CloudKitDirectPullService.LogPayload,
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
    static func task(
        matchingNormalizedName normalizedName: String,
        in context: ModelContext
    ) throws -> RoutineTask? {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return tasks.first { task in
            RoutineTask.normalizedName(task.name) == normalizedName
        }
    }

    @MainActor
    static func goal(
        matchingNormalizedTitle normalizedTitle: String,
        in context: ModelContext
    ) throws -> RoutineGoal? {
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        return goals.first { goal in
            RoutineGoal.normalizedTitle(goal.title) == normalizedTitle
        }
    }

    @MainActor
    static func place(
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

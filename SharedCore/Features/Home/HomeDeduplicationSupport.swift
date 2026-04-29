import Foundation
import SwiftData

enum HomeDeduplicationSupport {
    static func hasDuplicateRoutineName(
        _ name: String,
        in context: ModelContext,
        excludingID: UUID? = nil
    ) throws -> Bool {
        guard let normalized = RoutineTask.normalizedName(name) else { return false }
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return tasks.contains { task in
            if let excludingID, task.id == excludingID {
                return false
            }
            return RoutineTask.normalizedName(task.name) == normalized
        }
    }

    static func enforceUniqueRoutineNames(in context: ModelContext) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        var tasksByNormalizedName: [String: [RoutineTask]] = [:]
        var removedAny = false

        for task in tasks {
            guard let normalized = RoutineTask.normalizedName(task.name) else { continue }
            tasksByNormalizedName[normalized, default: []].append(task)
        }

        for sameNamedTasks in tasksByNormalizedName.values {
            guard sameNamedTasks.count > 1 else { continue }

            let keeper = preferredTaskToKeep(from: sameNamedTasks)
            var mergedRelationships = keeper.relationships
            var replacementTaskIDs: [UUID: UUID] = [:]
            for task in sameNamedTasks where task.id != keeper.id {
                replacementTaskIDs[task.id] = keeper.id
                mergedRelationships.append(contentsOf: task.relationships)
                let logs = try context.fetch(HomeTaskSupport.logsDescriptor(for: task.id))
                for log in logs {
                    context.delete(log)
                }
                let focusSessions = try context.fetch(HomeTaskSupport.focusSessionsDescriptor(for: task.id))
                for session in focusSessions {
                    context.delete(session)
                }
                context.delete(task)
                removedAny = true
            }

            if !replacementTaskIDs.isEmpty {
                keeper.replaceRelationships(
                    remappedRelationships(
                        mergedRelationships,
                        replacing: replacementTaskIDs,
                        ownerID: keeper.id
                    )
                )
                for task in tasks where task.id != keeper.id {
                    let updatedRelationships = remappedRelationships(
                        task.relationships,
                        replacing: replacementTaskIDs,
                        ownerID: task.id
                    )
                    if updatedRelationships != task.relationships {
                        task.replaceRelationships(updatedRelationships)
                    }
                }
            }
        }

        if removedAny {
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
        }
    }

    static func enforceUniquePlaceNames(in context: ModelContext) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let linkedCounts = tasks.reduce(into: [UUID: Int]()) { partialResult, task in
            guard let placeID = task.placeID else { return }
            partialResult[placeID, default: 0] += 1
        }

        var placesByNormalizedName: [String: [RoutinePlace]] = [:]
        var removedAny = false

        for place in places {
            guard let normalized = RoutinePlace.normalizedName(place.name) else { continue }
            placesByNormalizedName[normalized, default: []].append(place)
        }

        for sameNamedPlaces in placesByNormalizedName.values {
            guard sameNamedPlaces.count > 1 else { continue }

            let keeper = preferredPlaceToKeep(from: sameNamedPlaces, linkedCounts: linkedCounts)
            for place in sameNamedPlaces where place.id != keeper.id {
                for task in tasks where task.placeID == place.id {
                    task.placeID = keeper.id
                }
                context.delete(place)
                removedAny = true
            }
        }

        if removedAny {
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
        }
    }

    private static func preferredTaskToKeep(from tasks: [RoutineTask]) -> RoutineTask {
        tasks.min { taskSelectionKey($0) < taskSelectionKey($1) } ?? tasks[0]
    }

    private static func preferredPlaceToKeep(
        from places: [RoutinePlace],
        linkedCounts: [UUID: Int]
    ) -> RoutinePlace {
        places.min { lhs, rhs in
            placeSelectionKey(lhs, linkedCounts: linkedCounts) < placeSelectionKey(rhs, linkedCounts: linkedCounts)
        } ?? places[0]
    }

    private static func taskSelectionKey(_ task: RoutineTask) -> (Int, String, String) {
        let rawName = task.name ?? ""
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let whitespacePenalty = rawName == trimmedName ? 0 : 1
        let foldedName = trimmedName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return (whitespacePenalty, foldedName, task.id.uuidString.lowercased())
    }

    private static func remappedRelationships(
        _ relationships: [RoutineTaskRelationship],
        replacing replacementTaskIDs: [UUID: UUID],
        ownerID: UUID
    ) -> [RoutineTaskRelationship] {
        RoutineTaskRelationship.sanitized(
            relationships.map { relationship in
                RoutineTaskRelationship(
                    targetTaskID: replacementTaskIDs[relationship.targetTaskID] ?? relationship.targetTaskID,
                    kind: relationship.kind
                )
            },
            ownerID: ownerID
        )
    }

    private static func placeSelectionKey(
        _ place: RoutinePlace,
        linkedCounts: [UUID: Int]
    ) -> (Int, Int, Date, String, String) {
        let rawName = place.name
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkedCountPenalty = -linkedCounts[place.id, default: 0]
        let whitespacePenalty = rawName == trimmedName ? 0 : 1
        let foldedName = trimmedName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return (
            linkedCountPenalty,
            whitespacePenalty,
            place.createdAt,
            foldedName,
            place.id.uuidString.lowercased()
        )
    }
}

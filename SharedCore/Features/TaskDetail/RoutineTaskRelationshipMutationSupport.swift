import Foundation
import SwiftData

enum RoutineTaskRelationshipMutationError: Error {
    case taskNotFound
}

@MainActor
enum RoutineTaskRelationshipMutationSupport {
    /// Persists one canonical relationship through the same inverse-resolution
    /// rules used by Task Details.
    @discardableResult
    static func link(
        sourceTaskID: UUID,
        targetTaskID: UUID,
        kind: RoutineTaskRelationshipKind,
        timestamp: Date,
        calendar: Calendar,
        context: ModelContext
    ) throws -> Bool {
        let allTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        guard let sourceTask = allTasks.first(where: { $0.id == sourceTaskID }),
              targetTaskID != sourceTaskID,
              allTasks.contains(where: { $0.id == targetTaskID }) else {
            throw RoutineTaskRelationshipMutationError.taskNotFound
        }

        let candidates = RoutineTaskRelationshipCandidate.from(
            allTasks,
            excluding: sourceTaskID,
            referenceDate: timestamp,
            calendar: calendar
        )
        let previousRelationships = RoutineTask.editableRelationships(
            for: sourceTask,
            within: candidates
        )
        let updatedRelationships = RoutineTaskRelationship.sanitized(
            previousRelationships + [
                RoutineTaskRelationship(targetTaskID: targetTaskID, kind: kind)
            ],
            ownerID: sourceTaskID
        )
        guard updatedRelationships != previousRelationships else { return false }

        sourceTask.replaceRelationships(updatedRelationships)
        RoutineTask.removeInverseRelationships(targeting: sourceTaskID, from: allTasks)
        appendChangeEntries(
            to: sourceTask,
            previousRelationships: previousRelationships,
            updatedRelationships: updatedRelationships,
            timestamp: timestamp
        )
        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .task,
            entityID: sourceTaskID,
            entityTitle: RoutineTask.trimmedName(sourceTask.name) ?? "Untitled task",
            details: "Linked an existing task",
            in: context
        )
        try context.save()
        WidgetStatsService.refreshAndReload(using: context)
        NotificationCenter.default.postRoutineDidUpdate()
        return true
    }

    /// Updates only the manual/automatic completion rule for one task pair.
    /// Placement is stored independently by Task Ladder organization.
    @discardableResult
    static func setCompletionBehavior(
        sourceTaskID: UUID,
        targetTaskID: UUID,
        behavior: TaskLadderCompletionBehavior,
        timestamp: Date,
        calendar: Calendar,
        context: ModelContext
    ) throws -> Bool {
        let allTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        guard let sourceTask = allTasks.first(where: { $0.id == sourceTaskID }),
              targetTaskID != sourceTaskID,
              allTasks.contains(where: { $0.id == targetTaskID }) else {
            throw RoutineTaskRelationshipMutationError.taskNotFound
        }

        let candidates = RoutineTaskRelationshipCandidate.from(
            allTasks,
            excluding: sourceTaskID,
            referenceDate: timestamp,
            calendar: calendar
        )
        let previousRelationships = RoutineTask.editableRelationships(
            for: sourceTask,
            within: candidates
        )
        var updatedRelationships = previousRelationships
        updatedRelationships.removeAll { relationship in
            relationship.targetTaskID == targetTaskID
                && (relationship.kind == .canComplete || relationship.kind == .completes)
        }
        if let kind = behavior.relationshipKind {
            updatedRelationships.removeAll { $0.targetTaskID == targetTaskID }
            updatedRelationships.append(
                RoutineTaskRelationship(targetTaskID: targetTaskID, kind: kind)
            )
        }
        updatedRelationships = RoutineTaskRelationship.sanitized(
            updatedRelationships,
            ownerID: sourceTaskID
        )
        guard updatedRelationships != previousRelationships else { return false }

        sourceTask.replaceRelationships(updatedRelationships)
        RoutineTask.removeInverseRelationships(targeting: sourceTaskID, from: allTasks)
        appendChangeEntries(
            to: sourceTask,
            previousRelationships: previousRelationships,
            updatedRelationships: updatedRelationships,
            timestamp: timestamp
        )
        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .task,
            entityID: sourceTaskID,
            entityTitle: RoutineTask.trimmedName(sourceTask.name) ?? "Untitled task",
            details: "Updated completion behavior",
            in: context
        )
        try context.save()
        WidgetStatsService.refreshAndReload(using: context)
        NotificationCenter.default.postRoutineDidUpdate()
        return true
    }

    private static func appendChangeEntries(
        to task: RoutineTask,
        previousRelationships: [RoutineTaskRelationship],
        updatedRelationships: [RoutineTaskRelationship],
        timestamp: Date
    ) {
        let previousByID = Dictionary(
            uniqueKeysWithValues: previousRelationships.map { ($0.targetTaskID, $0) }
        )
        let updatedByID = Dictionary(
            uniqueKeysWithValues: updatedRelationships.map { ($0.targetTaskID, $0) }
        )

        for relationship in updatedRelationships
        where previousByID[relationship.targetTaskID] != relationship {
            task.appendChangeLogEntry(
                RoutineTaskChangeLogEntry(
                    timestamp: timestamp,
                    kind: .linkedTaskAdded,
                    relatedTaskID: relationship.targetTaskID,
                    relationshipKind: relationship.kind
                )
            )
        }

        for relationship in previousRelationships
        where updatedByID[relationship.targetTaskID] == nil {
            task.appendChangeLogEntry(
                RoutineTaskChangeLogEntry(
                    timestamp: timestamp,
                    kind: .linkedTaskRemoved,
                    relatedTaskID: relationship.targetTaskID,
                    relationshipKind: relationship.kind
                )
            )
        }
    }
}

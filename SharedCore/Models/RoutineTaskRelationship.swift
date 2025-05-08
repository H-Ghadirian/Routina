import Foundation

enum RoutineTaskRelationshipKind: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case related
    case blocks
    case blockedBy

    var title: String {
        switch self {
        case .related:
            return "Related"
        case .blocks:
            return "Blocks"
        case .blockedBy:
            return "Blocked by"
        }
    }

    var systemImage: String {
        switch self {
        case .related:
            return "link"
        case .blocks:
            return "arrow.turn.down.right"
        case .blockedBy:
            return "exclamationmark.triangle"
        }
    }

    var inverse: RoutineTaskRelationshipKind {
        switch self {
        case .related:
            return .related
        case .blocks:
            return .blockedBy
        case .blockedBy:
            return .blocks
        }
    }

    var sortOrder: Int {
        switch self {
        case .blockedBy:
            return 0
        case .blocks:
            return 1
        case .related:
            return 2
        }
    }
}

struct RoutineTaskRelationship: Codable, Equatable, Hashable, Identifiable, Sendable {
    var targetTaskID: UUID
    var kind: RoutineTaskRelationshipKind

    var id: String {
        "\(targetTaskID.uuidString)-\(kind.rawValue)"
    }

    static func sanitized(
        _ relationships: [RoutineTaskRelationship],
        ownerID: UUID? = nil
    ) -> [RoutineTaskRelationship] {
        var latestByTargetID: [UUID: RoutineTaskRelationship] = [:]
        for relationship in relationships {
            guard relationship.targetTaskID != ownerID else { continue }
            latestByTargetID[relationship.targetTaskID] = relationship
        }

        return latestByTargetID.values.sorted {
            if $0.kind.sortOrder != $1.kind.sortOrder {
                return $0.kind.sortOrder < $1.kind.sortOrder
            }
            return $0.targetTaskID.uuidString < $1.targetTaskID.uuidString
        }
    }
}

struct RoutineTaskRelationshipCandidate: Equatable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var emoji: String
    var relationships: [RoutineTaskRelationship]

    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled task" : name
    }

    static func from(
        _ tasks: [RoutineTask],
        excluding excludedTaskID: UUID? = nil
    ) -> [RoutineTaskRelationshipCandidate] {
        tasks.compactMap { task in
            guard task.id != excludedTaskID else { return nil }
            return RoutineTaskRelationshipCandidate(
                id: task.id,
                name: task.name ?? "Untitled task",
                emoji: task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨",
                relationships: task.relationships
            )
        }
        .sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}

struct RoutineTaskResolvedRelationship: Equatable, Hashable, Identifiable, Sendable {
    var taskID: UUID
    var taskName: String
    var taskEmoji: String
    var kind: RoutineTaskRelationshipKind

    var id: String {
        "\(taskID.uuidString)-\(kind.rawValue)"
    }
}

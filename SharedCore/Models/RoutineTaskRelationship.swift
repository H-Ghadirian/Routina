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

enum RoutineTaskRelationshipStatus: Equatable, Hashable, Sendable {
    case doneToday
    case completedOneOff
    case canceledOneOff
    case paused
    case pendingTodo
    case overdue(days: Int)
    case dueToday
    case onTrack

    var title: String {
        switch self {
        case .doneToday, .completedOneOff:
            return "Done"
        case .canceledOneOff:
            return "Canceled"
        case .paused:
            return "Paused"
        case .pendingTodo:
            return "To Do"
        case .overdue(let days):
            return days == 1 ? "Overdue 1d" : "Overdue \(days)d"
        case .dueToday:
            return "Today"
        case .onTrack:
            return "On Track"
        }
    }

    var systemImage: String {
        switch self {
        case .doneToday, .completedOneOff:
            return "checkmark.circle.fill"
        case .canceledOneOff:
            return "xmark.circle"
        case .paused:
            return "pause.circle.fill"
        case .pendingTodo:
            return "circle"
        case .overdue:
            return "exclamationmark.circle.fill"
        case .dueToday:
            return "clock.fill"
        case .onTrack:
            return "circle.fill"
        }
    }

    static func resolved(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> RoutineTaskRelationshipStatus {
        if task.isPaused { return .paused }
        if task.isCanceledOneOff { return .canceledOneOff }
        if task.isCompletedOneOff { return .completedOneOff }
        if let lastDone = task.lastDone, calendar.isDate(lastDone, inSameDayAs: referenceDate) {
            return .doneToday
        }
        if task.isOneOffTask { return .pendingTodo }
        let days = RoutineDateMath.daysUntilDue(for: task, referenceDate: referenceDate, calendar: calendar)
        if days < 0 { return .overdue(days: -days) }
        if days == 0 { return .dueToday }
        return .onTrack
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
    var status: RoutineTaskRelationshipStatus = .onTrack

    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled task" : name
    }

    static func from(
        _ tasks: [RoutineTask],
        excluding excludedTaskID: UUID? = nil,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [RoutineTaskRelationshipCandidate] {
        tasks.compactMap { task in
            guard task.id != excludedTaskID else { return nil }
            return RoutineTaskRelationshipCandidate(
                id: task.id,
                name: task.name ?? "Untitled task",
                emoji: task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨",
                relationships: task.relationships,
                status: RoutineTaskRelationshipStatus.resolved(for: task, referenceDate: referenceDate, calendar: calendar)
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
    var status: RoutineTaskRelationshipStatus = .onTrack

    var id: String {
        "\(taskID.uuidString)-\(kind.rawValue)"
    }
}

import Foundation

struct RoutineModelValueSanitizer {
    private init() {}

    static func trimmedName(_ name: String?) -> String? {
        name?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedName(_ name: String?) -> String? {
        guard let trimmed = trimmedName(name), !trimmed.isEmpty else { return nil }
        return trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    static func sanitizedNotes(_ notes: String?) -> String? {
        guard let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func sanitizedDescription(_ description: String?) -> String? {
        guard let trimmed = description?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func sanitizedLink(_ link: String?) -> String? {
        guard var trimmed = link?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        if !trimmed.contains("://") {
            trimmed = "https://\(trimmed)"
        }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host?.isEmpty == false else {
            return nil
        }

        return url.absoluteString
    }

    static func sanitizedEmoji(_ input: String, fallback: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return fallback }
        return String(first)
    }

    static func sanitizedPositiveInteger(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }
}

struct RoutineTaskResolvedLink: Equatable, Identifiable, Sendable {
    var text: String
    var url: URL

    var id: String { url.absoluteString }
}

struct RoutineTaskLink: Codable, Equatable, Sendable {
    var title: String?
    var url: String

    var displayText: String {
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        return url
    }
}

struct RoutineTaskRelationshipResolution {
    private init() {}

    static func resolvedRelationships(
        for task: RoutineTask,
        within candidates: [RoutineTaskRelationshipCandidate]
    ) -> [RoutineTaskResolvedRelationship] {
        var resolvedByID: [String: RoutineTaskResolvedRelationship] = [:]
        let candidateByID = RoutineTaskRelationshipCandidate.lookupByID(candidates)

        for relationship in task.relationships {
            guard let candidate = candidateByID[relationship.targetTaskID] else { continue }
            let resolved = RoutineTaskResolvedRelationship(
                taskID: candidate.id,
                taskName: candidate.displayName,
                taskEmoji: candidate.emoji,
                kind: relationship.kind,
                status: candidate.status
            )
            resolvedByID[resolved.id] = resolved
        }

        for candidate in candidates {
            for relationship in candidate.relationships where relationship.targetTaskID == task.id {
                let resolved = RoutineTaskResolvedRelationship(
                    taskID: candidate.id,
                    taskName: candidate.displayName,
                    taskEmoji: candidate.emoji,
                    kind: relationship.kind.inverse,
                    status: candidate.status
                )
                resolvedByID[resolved.id] = resolved
            }
        }

        return resolvedByID.values.sorted {
            if $0.kind.sortOrder != $1.kind.sortOrder {
                return $0.kind.sortOrder < $1.kind.sortOrder
            }
            return $0.taskName.localizedCaseInsensitiveCompare($1.taskName) == .orderedAscending
        }
    }

    static func editableRelationships(
        for task: RoutineTask,
        within candidates: [RoutineTaskRelationshipCandidate]
    ) -> [RoutineTaskRelationship] {
        var relationships: [RoutineTaskRelationship] = []

        for candidate in candidates {
            for relationship in candidate.relationships where relationship.targetTaskID == task.id {
                relationships.append(
                    RoutineTaskRelationship(
                        targetTaskID: candidate.id,
                        kind: relationship.kind.inverse
                    )
                )
            }
        }

        relationships.append(contentsOf: task.relationships)

        return RoutineTaskRelationship.sanitized(relationships, ownerID: task.id)
    }

    /// A task is unavailable while any confirmed Blocked by relationship has
    /// not completed after the dependent task's latest completion. Comparing
    /// completion order lets repeating chains advance one task at a time even
    /// when a prerequisite immediately recurs or is paused after completion.
    static func hasActiveBlocker(
        for task: RoutineTask,
        within candidates: [RoutineTaskRelationshipCandidate],
        dependentLatestCompletionAt: Date? = nil
    ) -> Bool {
        let candidateByID = RoutineTaskRelationshipCandidate.lookupByID(candidates)
        let dependentCompletionAt = latestCompletion(
            task.lastDone,
            dependentLatestCompletionAt
        )

        return blockerIDs(for: task, within: candidates).contains { blockerID in
            guard let blocker = candidateByID[blockerID] else { return false }
            return !prerequisiteIsResolved(
                status: blocker.status,
                blockerLatestCompletionAt: blocker.latestCompletionAt,
                dependentLatestCompletionAt: dependentCompletionAt
            )
        }
    }

    static func prerequisiteIsResolved(
        status: RoutineTaskRelationshipStatus,
        blockerLatestCompletionAt: Date?,
        dependentLatestCompletionAt: Date?
    ) -> Bool {
        switch status {
        case .completedOneOff, .canceledOneOff:
            return true
        case .doneToday, .paused, .pendingTodo, .overdue, .dueToday, .onTrack:
            break
        }

        if let blockerLatestCompletionAt {
            return dependentLatestCompletionAt.map { blockerLatestCompletionAt > $0 } ?? true
        }

        // Synthetic assumed-done occurrences have no persisted completion
        // timestamp, so retain their existing current-occurrence behavior.
        return status == .doneToday
    }

    static func latestCompletion(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return max(lhs, rhs)
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
    }

    private static func blockerIDs(
        for task: RoutineTask,
        within candidates: [RoutineTaskRelationshipCandidate]
    ) -> Set<UUID> {
        var ids = Set(task.relationships.compactMap { relationship in
            relationship.kind == .blockedBy ? relationship.targetTaskID : nil
        })

        for candidate in candidates {
            if candidate.relationships.contains(where: {
                $0.targetTaskID == task.id && $0.kind == .blocks
            }) {
                ids.insert(candidate.id)
            }
        }
        return ids
    }

    static func removeRelationships(
        targeting deletedTaskIDs: Set<UUID>,
        from tasks: [RoutineTask]
    ) {
        guard !deletedTaskIDs.isEmpty else { return }
        for task in tasks where !deletedTaskIDs.contains(task.id) {
            let updatedRelationships = task.relationships.filter { !deletedTaskIDs.contains($0.targetTaskID) }
            if updatedRelationships != task.relationships {
                task.replaceRelationships(updatedRelationships)
            }
        }
    }

    static func removeInverseRelationships(
        targeting ownerID: UUID,
        from tasks: [RoutineTask]
    ) {
        for task in tasks where task.id != ownerID {
            let updatedRelationships = task.relationships.filter { relationship in
                relationship.targetTaskID != ownerID
            }
            if updatedRelationships != task.relationships {
                task.replaceRelationships(updatedRelationships)
            }
        }
    }
}

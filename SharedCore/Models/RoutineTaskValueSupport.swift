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
}

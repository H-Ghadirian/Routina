import Foundation

enum RoutineStepStorage {
    static func serialize(_ steps: [RoutineStep]) -> String {
        let sanitized = RoutineStep.sanitized(steps)
        guard !sanitized.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sanitized),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> [RoutineStep] {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([RoutineStep].self, from: data) else {
            return []
        }
        return RoutineStep.sanitized(decoded)
    }
}

enum RoutineChecklistItemStorage {
    static func serialize(_ items: [RoutineChecklistItem]) -> String {
        let sanitized = RoutineChecklistItem.sanitized(items)
        guard !sanitized.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sanitized),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> [RoutineChecklistItem] {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([RoutineChecklistItem].self, from: data) else {
            return []
        }
        return RoutineChecklistItem.sanitized(decoded)
    }
}

enum RoutineChecklistProgressStorage {
    static func serialize(_ itemIDs: Set<UUID>) -> String {
        let sorted = itemIDs.sorted { $0.uuidString < $1.uuidString }
        guard !sorted.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sorted),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> Set<UUID> {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return Set(decoded)
    }
}

enum RoutineTaskRelationshipStorage {
    static func serialize(_ relationships: [RoutineTaskRelationship], ownerID: UUID? = nil) -> String {
        let sanitized = RoutineTaskRelationship.sanitized(relationships, ownerID: ownerID)
        guard !sanitized.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sanitized),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String, ownerID: UUID? = nil) -> [RoutineTaskRelationship] {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([RoutineTaskRelationship].self, from: data) else {
            return []
        }
        return RoutineTaskRelationship.sanitized(decoded, ownerID: ownerID)
    }
}

enum RoutineGoalIDStorage {
    static func sanitized(_ goalIDs: [UUID]) -> [UUID] {
        var seenIDs: Set<UUID> = []
        return goalIDs.filter { seenIDs.insert($0).inserted }
    }

    static func serialize(_ goalIDs: [UUID]) -> String {
        let sanitizedIDs = sanitized(goalIDs)
        guard !sanitizedIDs.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sanitizedIDs),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> [UUID] {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return sanitized(decoded)
    }
}

enum RoutineSectionOrderStorage {
    static func serialize(_ orders: [String: Int]) -> String {
        guard !orders.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(orders),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> [String: Int] {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return decoded
    }
}

enum RoutineRecurrenceRuleStorage {
    static func serialize(_ recurrenceRule: RoutineRecurrenceRule) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(recurrenceRule),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> RoutineRecurrenceRule? {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(RoutineRecurrenceRule.self, from: data)
    }
}

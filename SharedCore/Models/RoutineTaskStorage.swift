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

enum RoutineTaskLinkStorage {
    static func sanitizedItems(_ links: [RoutineTaskLink]) -> [RoutineTaskLink] {
        var seenLinks: Set<String> = []
        return links.compactMap { link in
            guard let sanitizedLink = RoutineModelValueSanitizer.sanitizedLink(link.url) else { return nil }
            let dedupeKey = sanitizedLink.lowercased()
            guard seenLinks.insert(dedupeKey).inserted else { return nil }
            let trimmedTitle = link.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = trimmedTitle?.isEmpty == false ? trimmedTitle : nil
            return RoutineTaskLink(title: title, url: sanitizedLink)
        }
    }

    static func sanitized(_ links: [String]) -> [String] {
        sanitizedItems(links.map { RoutineTaskLink(title: nil, url: $0) }).map(\.url)
    }

    static func serialize(_ links: [String]) -> String {
        serializeItems(sanitized(links).map { RoutineTaskLink(title: nil, url: $0) })
    }

    static func serializeItems(_ links: [RoutineTaskLink]) -> String {
        let sanitizedLinks = sanitizedItems(links)
        guard !sanitizedLinks.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sanitizedLinks),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> [String] {
        deserializeItems(storage).map(\.url)
    }

    static func deserializeItems(_ storage: String) -> [RoutineTaskLink] {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8) else {
            return []
        }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([RoutineTaskLink].self, from: data) {
            return sanitizedItems(decoded)
        }
        if let decoded = try? decoder.decode([String].self, from: data) {
            return sanitizedItems(decoded.map { RoutineTaskLink(title: nil, url: $0) })
        }
        return []
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

enum RoutineEventIDStorage {
    static func sanitized(_ eventIDs: [UUID]) -> [UUID] {
        var seenIDs: Set<UUID> = []
        return eventIDs.filter { seenIDs.insert($0).inserted }
    }

    static func serialize(_ eventIDs: [UUID]) -> String {
        let sanitizedIDs = sanitized(eventIDs)
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

enum RoutinePlaceIDStorage {
    static func sanitized(_ placeIDs: [UUID]) -> [UUID] {
        var seenIDs: Set<UUID> = []
        return placeIDs.filter { seenIDs.insert($0).inserted }
    }

    static func serialize(_ placeIDs: [UUID]) -> String {
        let sanitizedIDs = sanitized(placeIDs)
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

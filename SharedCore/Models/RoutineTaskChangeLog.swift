import Foundation

enum RoutineLogKind: String, Codable, Equatable, Sendable {
    case completed
    case canceled
}

enum RoutineTaskChangeKind: String, Codable, Equatable, Sendable {
    case created
    case stateChanged
    case linkedTaskAdded
    case linkedTaskRemoved
    case timeSpentAdded
    case timeSpentChanged
    case timeSpentRemoved
}

struct RoutineTaskChangeLogEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var timestamp: Date
    var kind: RoutineTaskChangeKind
    var previousValue: String?
    var newValue: String?
    var relatedTaskID: UUID?
    var relationshipKind: RoutineTaskRelationshipKind?
    var durationMinutes: Int?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: RoutineTaskChangeKind,
        previousValue: String? = nil,
        newValue: String? = nil,
        relatedTaskID: UUID? = nil,
        relationshipKind: RoutineTaskRelationshipKind? = nil,
        durationMinutes: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.previousValue = previousValue
        self.newValue = newValue
        self.relatedTaskID = relatedTaskID
        self.relationshipKind = relationshipKind
        self.durationMinutes = durationMinutes
    }
}

enum RoutineTaskChangeLogStorage {
    static func serialize(_ entries: [RoutineTaskChangeLogEntry]) -> String {
        let sortedEntries = entries.sorted { $0.timestamp > $1.timestamp }
        guard !sortedEntries.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sortedEntries),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> [RoutineTaskChangeLogEntry] {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([RoutineTaskChangeLogEntry].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.timestamp > $1.timestamp }
    }
}

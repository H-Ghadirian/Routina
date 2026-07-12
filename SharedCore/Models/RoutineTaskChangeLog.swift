import Foundation

enum RoutineLogKind: String, Codable, Equatable, Sendable {
    case completed
    case fulfilled
    case canceled
    case missed

    var resolvesDoneDate: Bool {
        self == .completed || self == .fulfilled
    }
}

enum RoutineTaskChangeKind: String, Codable, Equatable, Sendable {
    case created
    case stateChanged
    case linkedTaskAdded
    case linkedTaskRemoved
    case timeSpentAdded
    case timeSpentChanged
    case timeSpentRemoved
    case ongoingStarted
    case ongoingStopped
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

enum RoutineTaskMultiDaySpanDateStorage {
    static func encode(_ date: Date) -> String {
        String(date.timeIntervalSince1970)
    }

    static func decode(_ value: String?) -> Date? {
        guard let value, let interval = TimeInterval(value) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }
}

extension RoutineTask {
    @discardableResult
    func clearStoppedOngoingStateIfNeeded(calendar: Calendar = .current) -> Bool {
        if activityState == .ongoing, ongoingSince == nil {
            activityState = .idle
            return true
        }

        guard activityState == .ongoing,
              let ongoingSince,
              hasStoppedMultiDaySpan(startingAt: ongoingSince, calendar: calendar) else {
            return false
        }
        activityState = .idle
        self.ongoingSince = nil
        return true
    }

    func removeMultiDaySpan(containing day: Date, calendar: Calendar = .current) {
        let dayStart = calendar.startOfDay(for: day)
        var removedStartedAt: Date?
        let remainingEntries = changeLogEntries.filter { entry in
            guard entry.kind == .ongoingStopped,
                  let startedAt = RoutineTaskMultiDaySpanDateStorage.decode(entry.previousValue) else {
                return true
            }
            let finishedAt = RoutineTaskMultiDaySpanDateStorage.decode(entry.newValue) ?? entry.timestamp
            let startDay = calendar.startOfDay(for: min(startedAt, finishedAt))
            let finishDay = calendar.startOfDay(for: max(startedAt, finishedAt))
            let shouldRemove = dayStart >= startDay && dayStart <= finishDay
            if shouldRemove {
                removedStartedAt = startedAt
            }
            return !shouldRemove
        }

        guard let removedStartedAt else {
            changeLogEntries = remainingEntries
            return
        }

        changeLogEntries = remainingEntries.filter { entry in
            guard entry.kind == .ongoingStarted else { return true }
            guard let entryStartedAt = RoutineTaskMultiDaySpanDateStorage.decode(entry.newValue) else { return true }
            return !calendar.isDate(entryStartedAt, inSameDayAs: removedStartedAt)
        }
    }

    private func hasStoppedMultiDaySpan(startingAt startedAt: Date, calendar: Calendar) -> Bool {
        changeLogEntries.contains { entry in
            guard entry.kind == .ongoingStopped,
                  let entryStartedAt = RoutineTaskMultiDaySpanDateStorage.decode(entry.previousValue) else {
                return false
            }
            return calendar.isDate(entryStartedAt, inSameDayAs: startedAt)
        }
    }
}

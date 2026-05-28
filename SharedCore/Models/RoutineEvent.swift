import Foundation
import SwiftData

@Model
final class RoutineEvent {
    var id: UUID = UUID()
    var title: String?
    var notes: String?
    var emoji: String?
    var tagsStorage: String = ""
    var isAllDay: Bool = true
    var startedAt: Date?
    var endedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    var displayTitle: String {
        Self.cleanedText(title) ?? "Untitled event"
    }

    var displayEmoji: String {
        Self.cleanedText(emoji) ?? "🗓️"
    }

    var tags: [String] {
        get { RoutineTag.deserialize(tagsStorage) }
        set { tagsStorage = RoutineTag.serialize(newValue) }
    }

    init(
        id: UUID = UUID(),
        title: String? = nil,
        notes: String? = nil,
        emoji: String? = nil,
        tags: [String] = [],
        isAllDay: Bool = true,
        startedAt: Date? = Date(),
        endedAt: Date? = nil,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date()
    ) {
        self.id = id
        self.title = Self.cleanedText(title)
        self.notes = Self.cleanedText(notes)
        self.emoji = Self.cleanedText(emoji)
        self.tagsStorage = RoutineTag.serialize(tags)
        self.isAllDay = isAllDay
        self.startedAt = startedAt
        self.endedAt = Self.normalizedEndDate(startedAt: startedAt, endedAt: endedAt)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func detachedCopy() -> RoutineEvent {
        RoutineEvent(
            id: id,
            title: title,
            notes: notes,
            emoji: emoji,
            tags: tags,
            isAllDay: isAllDay,
            startedAt: startedAt,
            endedAt: endedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func cleanedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func normalizedEndDate(startedAt: Date?, endedAt: Date?) -> Date? {
        guard let startedAt else { return endedAt }
        guard let endedAt, endedAt > startedAt else { return nil }
        return endedAt
    }
}

extension RoutineEvent: Equatable {
    static func == (lhs: RoutineEvent, rhs: RoutineEvent) -> Bool {
        lhs.id == rhs.id
    }
}

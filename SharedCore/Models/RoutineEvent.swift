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
    var reminderAt: Date?
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
        reminderAt: Date? = nil,
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
        self.reminderAt = reminderAt
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
            reminderAt: reminderAt,
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

    static func reminderEventDate(
        startedAt: Date?,
        isAllDay: Bool,
        calendar: Calendar
    ) -> Date? {
        guard let startedAt else { return nil }
        if isAllDay {
            return NotificationPreferences.reminderDate(on: startedAt, calendar: calendar)
        }
        return startedAt
    }

    static func defaultReminderDate(
        startedAt: Date?,
        isAllDay: Bool,
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> Date {
        let eventDate = reminderEventDate(
            startedAt: startedAt,
            isAllDay: isAllDay,
            calendar: calendar
        )
        guard let eventDate, eventDate > referenceDate else {
            return referenceDate.addingTimeInterval(60 * 60)
        }
        return eventDate
    }
}

extension RoutineEvent: Equatable {
    static func == (lhs: RoutineEvent, rhs: RoutineEvent) -> Bool {
        lhs.id == rhs.id
    }
}

struct RoutineEventLinkCandidate: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var emoji: String
    var isAllDay: Bool
    var startedAt: Date?
    var endedAt: Date?

    init(
        id: UUID,
        title: String,
        emoji: String,
        isAllDay: Bool,
        startedAt: Date?,
        endedAt: Date?
    ) {
        self.id = id
        self.title = RoutineEvent.cleanedText(title) ?? "Untitled event"
        self.emoji = RoutineEvent.cleanedText(emoji) ?? "🗓️"
        self.isAllDay = isAllDay
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    init(event: RoutineEvent) {
        self.init(
            id: event.id,
            title: event.displayTitle,
            emoji: event.displayEmoji,
            isAllDay: event.isAllDay,
            startedAt: event.startedAt,
            endedAt: event.endedAt
        )
    }

    var displayTitle: String { title }
    var displayEmoji: String { emoji }

    static func candidates(from events: [RoutineEvent]) -> [RoutineEventLinkCandidate] {
        events.map(RoutineEventLinkCandidate.init(event:)).sorted(by: sort)
    }

    static func selectedCandidates(
        for eventIDs: [UUID],
        in candidates: [RoutineEventLinkCandidate]
    ) -> [RoutineEventLinkCandidate] {
        let candidatesByID = Dictionary(candidates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return RoutineEventIDStorage.sanitized(eventIDs).compactMap { candidatesByID[$0] }
    }

    static func sort(_ lhs: RoutineEventLinkCandidate, _ rhs: RoutineEventLinkCandidate) -> Bool {
        switch (lhs.startedAt, rhs.startedAt) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate > rhsDate
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
        }
    }
}

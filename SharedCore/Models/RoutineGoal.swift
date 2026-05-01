import Foundation
import SwiftData

enum RoutineGoalStatus: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case active
    case archived

    var title: String {
        switch self {
        case .active: return "Active"
        case .archived: return "Archived"
        }
    }
}

@Model
final class RoutineGoal {
    var id: UUID = UUID()
    var title: String = ""
    var emoji: String?
    var notes: String?
    var targetDate: Date?
    var statusRawValue: String = RoutineGoalStatus.active.rawValue
    var colorRawValue: String = RoutineTaskColor.none.rawValue
    var createdAt: Date? = Date()
    var sortOrder: Int = 0

    var status: RoutineGoalStatus {
        get { RoutineGoalStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    var color: RoutineTaskColor {
        get { RoutineTaskColor(rawValue: colorRawValue) ?? .none }
        set { colorRawValue = newValue.rawValue }
    }

    var displayTitle: String {
        Self.cleanedTitle(title) ?? "Untitled goal"
    }

    init(
        id: UUID = UUID(),
        title: String,
        emoji: String? = nil,
        notes: String? = nil,
        targetDate: Date? = nil,
        status: RoutineGoalStatus = .active,
        color: RoutineTaskColor = .none,
        createdAt: Date? = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = Self.cleanedTitle(title) ?? ""
        self.emoji = Self.cleanedEmoji(emoji)
        self.notes = Self.cleanedNotes(notes)
        self.targetDate = targetDate
        self.statusRawValue = status.rawValue
        self.colorRawValue = color.rawValue
        self.createdAt = createdAt
        self.sortOrder = max(sortOrder, 0)
    }

    func detachedCopy() -> RoutineGoal {
        RoutineGoal(
            id: id,
            title: title,
            emoji: emoji,
            notes: notes,
            targetDate: targetDate,
            status: status,
            color: color,
            createdAt: createdAt,
            sortOrder: sortOrder
        )
    }

    static func cleanedTitle(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func normalizedTitle(_ value: String?) -> String? {
        guard let cleaned = cleanedTitle(value) else { return nil }
        return cleaned.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    static func cleanedEmoji(_ value: String?) -> String? {
        guard let first = value?.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return nil
        }
        return String(first)
    }

    static func cleanedNotes(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

extension RoutineGoal: Equatable {
    static func == (lhs: RoutineGoal, rhs: RoutineGoal) -> Bool {
        lhs.id == rhs.id
    }
}

struct RoutineGoalSummary: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var emoji: String?
    var status: RoutineGoalStatus
    var color: RoutineTaskColor

    var displayTitle: String {
        RoutineGoal.cleanedTitle(title) ?? "Untitled goal"
    }

    var displayEmoji: String {
        emoji.flatMap(RoutineGoal.cleanedEmoji) ?? "\u{1F3AF}"
    }

    init(
        id: UUID = UUID(),
        title: String,
        emoji: String? = nil,
        status: RoutineGoalStatus = .active,
        color: RoutineTaskColor = .none
    ) {
        self.id = id
        self.title = RoutineGoal.cleanedTitle(title) ?? ""
        self.emoji = RoutineGoal.cleanedEmoji(emoji)
        self.status = status
        self.color = color
    }

    init(goal: RoutineGoal) {
        self.init(
            id: goal.id,
            title: goal.displayTitle,
            emoji: goal.emoji,
            status: goal.status,
            color: goal.color
        )
    }

    static func summaries(from goals: [RoutineGoal]) -> [RoutineGoalSummary] {
        sanitized(goals.map(RoutineGoalSummary.init(goal:))).sorted {
            if $0.status != $1.status {
                return $0.status == .active
            }
            return $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }
    }

    static func summaries(
        for goalIDs: [UUID],
        in goals: [RoutineGoalSummary]
    ) -> [RoutineGoalSummary] {
        let summariesByID = Dictionary(uniqueKeysWithValues: sanitized(goals).map { ($0.id, $0) })
        return goalIDs.compactMap { summariesByID[$0] }
    }

    static func sanitized(_ goals: [RoutineGoalSummary]) -> [RoutineGoalSummary] {
        var seenIDs: Set<UUID> = []
        var seenTitles: Set<String> = []
        var result: [RoutineGoalSummary] = []

        for goal in goals {
            guard let cleanedTitle = RoutineGoal.cleanedTitle(goal.title),
                  let normalizedTitle = RoutineGoal.normalizedTitle(cleanedTitle),
                  seenIDs.insert(goal.id).inserted,
                  seenTitles.insert(normalizedTitle).inserted else {
                continue
            }
            result.append(
                RoutineGoalSummary(
                    id: goal.id,
                    title: cleanedTitle,
                    emoji: goal.emoji,
                    status: goal.status,
                    color: goal.color
                )
            )
        }

        return result
    }

    static func appending(
        _ draft: String,
        availableGoals: [RoutineGoalSummary],
        to selectedGoals: [RoutineGoalSummary]
    ) -> [RoutineGoalSummary] {
        let parsedGoals = draft
            .split(separator: ",")
            .compactMap { rawTitle -> RoutineGoalSummary? in
                guard let title = RoutineGoal.cleanedTitle(String(rawTitle)) else { return nil }
                if let existing = availableGoals.first(where: {
                    RoutineGoal.normalizedTitle($0.title) == RoutineGoal.normalizedTitle(title)
                }) {
                    return existing
                }
                return RoutineGoalSummary(title: title)
            }
        return sanitized(selectedGoals + parsedGoals)
    }

    static func toggling(
        _ goal: RoutineGoalSummary,
        in selectedGoals: [RoutineGoalSummary]
    ) -> [RoutineGoalSummary] {
        if selectedGoals.contains(where: { $0.id == goal.id }) {
            return removing(goal.id, from: selectedGoals)
        }
        return sanitized(selectedGoals + [goal])
    }

    static func removing(
        _ goalID: UUID,
        from selectedGoals: [RoutineGoalSummary]
    ) -> [RoutineGoalSummary] {
        sanitized(selectedGoals.filter { $0.id != goalID })
    }
}

enum RoutineGoalPersistence {
    @MainActor
    static func ensureGoals(
        _ goalSummaries: [RoutineGoalSummary],
        in context: ModelContext
    ) throws -> [UUID] {
        let requestedGoals = RoutineGoalSummary.sanitized(goalSummaries)
        guard !requestedGoals.isEmpty else { return [] }

        let existingGoals = try context.fetch(FetchDescriptor<RoutineGoal>())
        var goalsByID = Dictionary(uniqueKeysWithValues: existingGoals.map { ($0.id, $0) })
        var goalsByNormalizedTitle: [String: RoutineGoal] = [:]
        for goal in existingGoals {
            if let normalizedTitle = RoutineGoal.normalizedTitle(goal.title) {
                goalsByNormalizedTitle[normalizedTitle] = goal
            }
        }

        var resolvedIDs: [UUID] = []
        for summary in requestedGoals {
            guard let normalizedTitle = RoutineGoal.normalizedTitle(summary.title) else { continue }

            if let existingGoal = goalsByID[summary.id] ?? goalsByNormalizedTitle[normalizedTitle] {
                if existingGoal.status == .archived {
                    existingGoal.status = .active
                }
                resolvedIDs.append(existingGoal.id)
                continue
            }

            let goal = RoutineGoal(
                id: summary.id,
                title: summary.title,
                emoji: summary.emoji,
                status: summary.status,
                color: summary.color
            )
            context.insert(goal)
            goalsByID[goal.id] = goal
            goalsByNormalizedTitle[normalizedTitle] = goal
            resolvedIDs.append(goal.id)
        }

        return RoutineGoalIDStorage.sanitized(resolvedIDs)
    }
}

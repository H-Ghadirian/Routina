import Foundation

enum RoutineScheduleMode: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case fixedInterval
    case softInterval
    case fixedIntervalChecklist
    case derivedFromChecklist
    case oneOff

    var taskType: RoutineTaskType {
        self == .oneOff ? .todo : .routine
    }
}

enum RoutineActivityState: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case idle
    case ongoing
}

struct RoutineChecklistItem: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var title: String
    var intervalDays: Int
    var lastPurchasedAt: Date?
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        title: String,
        intervalDays: Int,
        lastPurchasedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.intervalDays = Self.clampedIntervalDays(intervalDays)
        self.lastPurchasedAt = lastPurchasedAt
        self.createdAt = createdAt
    }

    static func sanitized(_ items: [RoutineChecklistItem]) -> [RoutineChecklistItem] {
        items.compactMap { item in
            guard let title = normalizedTitle(item.title) else { return nil }
            return RoutineChecklistItem(
                id: item.id,
                title: title,
                intervalDays: item.intervalDays,
                lastPurchasedAt: item.lastPurchasedAt,
                createdAt: item.createdAt
            )
        }
    }

    static func normalizedTitle(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    static func clampedIntervalDays(_ value: Int) -> Int {
        min(max(value, 1), 3650)
    }
}

enum RoutineAdvanceResult: Equatable {
    case ignoredPaused
    case ignoredAlreadyCompletedToday
    case advancedStep(completedSteps: Int, totalSteps: Int)
    case advancedChecklist(completedItems: Int, totalItems: Int)
    case completedRoutine
}

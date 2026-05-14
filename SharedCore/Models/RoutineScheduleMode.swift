import Foundation

enum RoutineScheduleMode: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case fixedInterval
    case softInterval
    case fixedIntervalChecklist
    case softIntervalChecklist
    case derivedFromChecklist
    case softDerivedFromChecklist
    case oneOff

    var taskType: RoutineTaskType {
        self == .oneOff ? .todo : .routine
    }

    var scheduleBehavior: RoutineScheduleBehavior {
        switch self {
        case .softInterval, .softIntervalChecklist, .softDerivedFromChecklist:
            return .soft
        case .fixedInterval, .fixedIntervalChecklist, .derivedFromChecklist, .oneOff:
            return .fixed
        }
    }

    var routineFormat: RoutineFormat {
        switch self {
        case .fixedInterval, .softInterval, .oneOff:
            return .standard
        case .fixedIntervalChecklist, .softIntervalChecklist:
            return .checklist
        case .derivedFromChecklist, .softDerivedFromChecklist:
            return .runout
        }
    }

    var isSoftIntervalRoutine: Bool {
        scheduleBehavior == .soft
    }

    var isChecklistCompletionMode: Bool {
        routineFormat == .checklist
    }

    var isChecklistDrivenMode: Bool {
        routineFormat == .runout
    }

    var isStandardRoutineMode: Bool {
        routineFormat == .standard
    }

    var isRoutineModeRequiringChecklistItems: Bool {
        routineFormat == .checklist || routineFormat == .runout
    }

    var showsRoutineRepeatControls: Bool {
        self != .oneOff && routineFormat != .runout
    }

    static func routineMode(
        behavior: RoutineScheduleBehavior,
        format: RoutineFormat
    ) -> RoutineScheduleMode {
        switch (behavior, format) {
        case (.fixed, .standard): return .fixedInterval
        case (.soft, .standard): return .softInterval
        case (.fixed, .checklist): return .fixedIntervalChecklist
        case (.soft, .checklist): return .softIntervalChecklist
        case (.fixed, .runout): return .derivedFromChecklist
        case (.soft, .runout): return .softDerivedFromChecklist
        }
    }
}

enum RoutineScheduleBehavior: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case fixed = "Fixed"
    case soft = "Soft"

    var id: String { rawValue }
}

enum RoutineFormat: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case standard = "Standard"
    case checklist = "Checklist"
    case runout = "Runout"

    var id: String { rawValue }
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

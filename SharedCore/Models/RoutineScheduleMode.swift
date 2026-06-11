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

    var routineFinishMode: RoutineFinishMode {
        routineFormat == .standard ? .standard : .checklist
    }

    var checklistTimingMode: ChecklistTimingMode {
        routineFormat == .runout ? .runout : .together
    }

    func replacingRoutineFinishMode(_ finishMode: RoutineFinishMode) -> RoutineScheduleMode {
        let format: RoutineFormat
        switch finishMode {
        case .standard:
            format = .standard
        case .checklist:
            format = routineFormat == .runout ? .runout : .checklist
        }
        return Self.routineMode(behavior: scheduleBehavior, format: format)
    }

    func replacingChecklistTimingMode(_ timingMode: ChecklistTimingMode) -> RoutineScheduleMode {
        Self.routineMode(
            behavior: scheduleBehavior,
            format: timingMode == .runout ? .runout : .checklist
        )
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
    case fixed = "Due"
    case soft = "Gentle"

    var id: String { rawValue }

    var explanation: String {
        switch self {
        case .fixed:
            return "Due means this can become due or overdue."
        case .soft:
            return "Gentle keeps it visible and nudges you without overdue pressure."
        }
    }

    var rowPreviewBadges: [RoutineScheduleBehaviorPreviewBadge] {
        switch self {
        case .fixed:
            return [
                RoutineScheduleBehaviorPreviewBadge(title: "Today", systemImage: "clock.fill", style: .due),
                RoutineScheduleBehaviorPreviewBadge(title: "Overdue 2d", systemImage: "exclamationmark.circle.fill", style: .overdue)
            ]
        case .soft:
            return [
                RoutineScheduleBehaviorPreviewBadge(title: "Ready to Do", systemImage: "circle", style: .ready),
                RoutineScheduleBehaviorPreviewBadge(title: "Gentle nudge", systemImage: "clock.arrow.circlepath", style: .gentle)
            ]
        }
    }

    var rowPreviewDescription: String {
        switch self {
        case .fixed:
            return "Rows show Today, then Overdue if not completed."
        case .soft:
            return "Rows show Ready to Do or Gentle nudge, never Overdue."
        }
    }
}

struct RoutineScheduleBehaviorPreviewBadge: Equatable, Hashable, Identifiable, Sendable {
    var title: String
    var systemImage: String
    var style: RoutineScheduleBehaviorPreviewBadgeStyle

    var id: String { "\(style.rawValue)-\(title)" }
}

enum RoutineScheduleBehaviorPreviewBadgeStyle: String, Equatable, Hashable, Sendable {
    case due
    case overdue
    case ready
    case gentle
}

enum RoutineFormat: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case standard = "Standard"
    case checklist = "Checklist"
    case runout = "Runout"

    var id: String { rawValue }
}

enum RoutineFinishMode: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case standard = "Standard"
    case checklist = "Checklist"

    var id: String { rawValue }
}

enum ChecklistTimingMode: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case together = "Together"
    case runout = "Runout"

    var id: String { rawValue }
}

enum RoutineDurationMode: String, Codable, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case oneDay = "One day"
    case multiDay = "Multi-day"

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

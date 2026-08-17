import Foundation

enum RoutineTaskTemporalWeightCurve: String, Codable, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case onDueDate
    case gradual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onDueDate: return "On due date"
        case .gradual: return "Gradually"
        }
    }
}

/// Optional due-date targets for a repeating task. Stored values remain the
/// baseline; Task Ladder derives the temporary effective values at read time.
struct RoutineTaskTemporalWeightRule: Codable, Equatable, Sendable {
    static let maximumLeadDays = 365

    var curve: RoutineTaskTemporalWeightCurve
    var leadDays: Int
    var importanceAtDue: RoutineTaskImportance?
    var urgencyAtDue: RoutineTaskUrgency?
    var pressureAtDue: RoutineTaskPressure?

    init(
        curve: RoutineTaskTemporalWeightCurve = .onDueDate,
        leadDays: Int = 7,
        importanceAtDue: RoutineTaskImportance? = nil,
        urgencyAtDue: RoutineTaskUrgency? = nil,
        pressureAtDue: RoutineTaskPressure? = nil
    ) {
        self.curve = curve
        self.leadDays = min(max(leadDays, 1), Self.maximumLeadDays)
        self.importanceAtDue = importanceAtDue
        self.urgencyAtDue = urgencyAtDue
        self.pressureAtDue = pressureAtDue
    }

    var hasAnyTarget: Bool {
        importanceAtDue != nil || urgencyAtDue != nil || pressureAtDue != nil
    }

    var sanitized: Self? {
        guard hasAnyTarget else { return nil }
        return Self(
            curve: curve,
            leadDays: leadDays,
            importanceAtDue: importanceAtDue,
            urgencyAtDue: urgencyAtDue,
            pressureAtDue: pressureAtDue
        )
    }

    func sanitized(
        baseImportance: RoutineTaskImportance,
        baseUrgency: RoutineTaskUrgency,
        basePressure: RoutineTaskPressure
    ) -> Self? {
        let sanitizedRule = Self(
            curve: curve,
            leadDays: leadDays,
            importanceAtDue: (importanceAtDue?.sortOrder ?? Int.min) > baseImportance.sortOrder
                ? importanceAtDue
                : nil,
            urgencyAtDue: (urgencyAtDue?.sortOrder ?? Int.min) > baseUrgency.sortOrder
                ? urgencyAtDue
                : nil,
            pressureAtDue: (pressureAtDue?.sortOrder ?? Int.min) > basePressure.sortOrder
                ? pressureAtDue
                : nil
        )
        return sanitizedRule.sanitized
    }
}

enum RoutineTaskTemporalWeightStorage {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func serialize(_ rule: RoutineTaskTemporalWeightRule?) -> String {
        guard let rule = rule?.sanitized,
              let data = try? encoder.encode(rule) else {
            return ""
        }
        return String(decoding: data, as: UTF8.self)
    }

    static func deserialize(_ storage: String?) -> RoutineTaskTemporalWeightRule? {
        guard let storage,
              !storage.isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? decoder.decode(RoutineTaskTemporalWeightRule.self, from: data) else {
            return nil
        }
        return decoded.sanitized
    }
}

struct RoutineTaskEffectiveWeights: Equatable, Sendable {
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let pressure: RoutineTaskPressure
    let progress: Double

    var isAdjusted: Bool { progress > 0 }
}

enum RoutineTaskTemporalWeightResolver {
    static func supportsTemporalWeight(
        scheduleMode: RoutineScheduleMode,
        trackingCadenceEnabled: Bool
    ) -> Bool {
        scheduleMode.taskType == .routine
            && scheduleMode.scheduleBehavior == .fixed
            && scheduleMode.usesRoutineCadence
            && trackingCadenceEnabled
    }

    static func supportsTemporalWeight(_ task: RoutineTask) -> Bool {
        supportsTemporalWeight(
            scheduleMode: task.scheduleMode,
            trackingCadenceEnabled: task.trackingCadenceEnabled
        )
    }

    static func sanitizedRule(
        _ rule: RoutineTaskTemporalWeightRule?,
        scheduleMode: RoutineScheduleMode,
        trackingCadenceEnabled: Bool,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure
    ) -> RoutineTaskTemporalWeightRule? {
        guard supportsTemporalWeight(
            scheduleMode: scheduleMode,
            trackingCadenceEnabled: trackingCadenceEnabled
        ) else {
            return nil
        }
        return rule?.sanitized(
            baseImportance: importance,
            baseUrgency: urgency,
            basePressure: pressure
        )
    }

    static func sanitizedRule(
        _ rule: RoutineTaskTemporalWeightRule?,
        for task: RoutineTask
    ) -> RoutineTaskTemporalWeightRule? {
        sanitizedRule(
            rule,
            scheduleMode: task.scheduleMode,
            trackingCadenceEnabled: task.trackingCadenceEnabled,
            importance: task.importance,
            urgency: task.urgency,
            pressure: task.pressure
        )
    }

    static func effectiveWeights(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> RoutineTaskEffectiveWeights {
        guard supportsTemporalWeight(task),
              let rule = task.temporalWeightRule else {
            return RoutineTaskEffectiveWeights(
                importance: task.importance,
                urgency: task.urgency,
                pressure: task.pressure,
                progress: 0
            )
        }

        let daysUntilDue = RoutineDateMath.daysUntilDue(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        guard daysUntilDue != Int.max else {
            return RoutineTaskEffectiveWeights(
                importance: task.importance,
                urgency: task.urgency,
                pressure: task.pressure,
                progress: 0
            )
        }

        let progress: Double
        switch rule.curve {
        case .onDueDate:
            progress = daysUntilDue <= 0 ? 1 : 0
        case .gradual:
            let leadDays = min(max(rule.leadDays, 1), RoutineTaskTemporalWeightRule.maximumLeadDays)
            if daysUntilDue <= 0 {
                progress = 1
            } else if daysUntilDue >= leadDays {
                progress = 0
            } else {
                progress = Double(leadDays - daysUntilDue) / Double(leadDays)
            }
        }

        return RoutineTaskEffectiveWeights(
            importance: interpolated(
                base: task.importance,
                target: rule.importanceAtDue,
                progress: progress,
                values: RoutineTaskImportance.allCases
            ),
            urgency: interpolated(
                base: task.urgency,
                target: rule.urgencyAtDue,
                progress: progress,
                values: RoutineTaskUrgency.allCases
            ),
            pressure: interpolated(
                base: task.pressure,
                target: rule.pressureAtDue,
                progress: progress,
                values: RoutineTaskPressure.allCases
            ),
            progress: progress
        )
    }

    static func timingLabel(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard supportsTemporalWeight(task), task.temporalWeightRule != nil else { return nil }
        let days = RoutineDateMath.daysUntilDue(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        guard days != Int.max else { return nil }
        switch days {
        case ..<0: return abs(days) == 1 ? "1 day overdue" : "\(abs(days)) days overdue"
        case 0: return "Due today"
        case 1: return "Due tomorrow"
        default: return "Due in \(days) days"
        }
    }

    private static func interpolated<Value>(
        base: Value,
        target: Value?,
        progress: Double,
        values: [Value]
    ) -> Value where Value: Equatable {
        guard let target,
              let baseIndex = values.firstIndex(of: base),
              let targetIndex = values.firstIndex(of: target),
              targetIndex > baseIndex,
              progress > 0 else {
            return base
        }
        let distance = targetIndex - baseIndex
        let clampedProgress = min(max(progress, 0), 1)
        let proposedLevels = Int(ceil(Double(distance) * clampedProgress))
        let advancedLevels = clampedProgress >= 1
            ? distance
            : min(proposedLevels, max(distance - 1, 0))
        return values[min(baseIndex + advancedLevels, targetIndex)]
    }
}

enum RoutineTaskTemporalWeightPresentation {
    static func targetSummary(
        rule: RoutineTaskTemporalWeightRule?,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure
    ) -> String? {
        guard let rule = rule?.sanitized(
            baseImportance: importance,
            baseUrgency: urgency,
            basePressure: pressure
        ) else {
            return nil
        }

        var parts: [String] = []
        if let target = rule.importanceAtDue {
            parts.append("Importance \(importance.title) -> \(target.title)")
        }
        if let target = rule.urgencyAtDue {
            parts.append("Urgency \(urgency.title) -> \(target.title)")
        }
        if let target = rule.pressureAtDue {
            parts.append("Pressure \(pressure.title) -> \(target.title)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    static func changeSummary(rule: RoutineTaskTemporalWeightRule?) -> String? {
        guard let rule = rule?.sanitized else { return nil }
        switch rule.curve {
        case .onDueDate:
            return "Changes on due date"
        case .gradual:
            return "Rises over \(rule.leadDays) \(rule.leadDays == 1 ? "day" : "days")"
        }
    }

    static func nowSummary(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard RoutineTaskTemporalWeightResolver.supportsTemporalWeight(task),
              task.temporalWeightRule != nil else {
            return nil
        }
        let weights = RoutineTaskTemporalWeightResolver.effectiveWeights(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        return "Now: Importance \(weights.importance.title) • Urgency \(weights.urgency.title) • Pressure \(weights.pressure.title)"
    }

    static func baseSummary(
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure
    ) -> String {
        "Base: Importance \(importance.title) • Urgency \(urgency.title) • Pressure \(pressure.title)"
    }
}

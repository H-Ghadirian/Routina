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
    static func supportsTemporalWeight(_ task: RoutineTask) -> Bool {
        !task.isOneOffTask
            && task.scheduleMode.taskType == .routine
            && task.scheduleMode.scheduleBehavior == .fixed
            && task.usesEffectiveRoutineCadence
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

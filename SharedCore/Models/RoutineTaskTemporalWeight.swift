import Foundation

enum RoutineTaskTemporalWeightTiming: String, Codable, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case onDueDate
    case gradualBeforeDue
    case gradualWhileOverdue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onDueDate: return "Only on due date"
        case .gradualBeforeDue: return "Gradually before due"
        case .gradualWhileOverdue: return "Gradually while overdue"
        }
    }
}

/// Kept for source and stored-data compatibility with the former shared-curve model.
enum RoutineTaskTemporalWeightCurve: String, Codable, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case onDueDate
    case gradual

    var id: String { rawValue }
}

struct RoutineTaskTemporalWeightPolicy<Value>: Codable, Equatable, Sendable
where Value: Codable & Equatable & Sendable {
    var target: Value
    var timing: RoutineTaskTemporalWeightTiming
    var days: Int

    init(
        target: Value,
        timing: RoutineTaskTemporalWeightTiming = .onDueDate,
        days: Int = 1
    ) {
        self.target = target
        self.timing = timing
        self.days = Self.sanitizedDays(days, timing: timing, maximumBeforeDueDays: nil)
    }

    func sanitized(maximumBeforeDueDays: Int? = nil) -> Self {
        Self(
            target: target,
            timing: timing,
            days: Self.sanitizedDays(
                days,
                timing: timing,
                maximumBeforeDueDays: maximumBeforeDueDays
            )
        )
    }

    private static func sanitizedDays(
        _ days: Int,
        timing: RoutineTaskTemporalWeightTiming,
        maximumBeforeDueDays: Int?
    ) -> Int {
        guard timing != .onDueDate else { return 1 }
        let globalMaximum = RoutineTaskTemporalWeightRule.maximumTransitionDays
        let maximum: Int
        if timing == .gradualBeforeDue, let maximumBeforeDueDays {
            maximum = min(max(maximumBeforeDueDays, 1), globalMaximum)
        } else {
            maximum = globalMaximum
        }
        return min(max(days, 1), maximum)
    }
}

/// Independent changes for the three Task Ladder metrics that can vary with a
/// repeating due date. Stored task values are the after-completion baseline;
/// each policy derives a temporary effective value at read time.
struct RoutineTaskTemporalWeightRule: Codable, Equatable, Sendable {
    static let maximumTransitionDays = 365

    var importance: RoutineTaskTemporalWeightPolicy<RoutineTaskImportance>?
    var urgency: RoutineTaskTemporalWeightPolicy<RoutineTaskUrgency>?
    var pressure: RoutineTaskTemporalWeightPolicy<RoutineTaskPressure>?

    init(
        importance: RoutineTaskTemporalWeightPolicy<RoutineTaskImportance>? = nil,
        urgency: RoutineTaskTemporalWeightPolicy<RoutineTaskUrgency>? = nil,
        pressure: RoutineTaskTemporalWeightPolicy<RoutineTaskPressure>? = nil,
        curve legacyCurve: RoutineTaskTemporalWeightCurve? = nil,
        leadDays legacyLeadDays: Int = 7,
        importanceAtDue legacyImportance: RoutineTaskImportance? = nil,
        urgencyAtDue legacyUrgency: RoutineTaskUrgency? = nil,
        pressureAtDue legacyPressure: RoutineTaskPressure? = nil
    ) {
        let legacyTiming: RoutineTaskTemporalWeightTiming = legacyCurve == .gradual
            ? .gradualBeforeDue
            : .onDueDate
        self.importance = importance ?? legacyImportance.map {
            RoutineTaskTemporalWeightPolicy(
                target: $0,
                timing: legacyTiming,
                days: legacyLeadDays
            )
        }
        self.urgency = urgency ?? legacyUrgency.map {
            RoutineTaskTemporalWeightPolicy(
                target: $0,
                timing: legacyTiming,
                days: legacyLeadDays
            )
        }
        self.pressure = pressure ?? legacyPressure.map {
            RoutineTaskTemporalWeightPolicy(
                target: $0,
                timing: legacyTiming,
                days: legacyLeadDays
            )
        }
    }

    var hasAnyTarget: Bool {
        importance != nil || urgency != nil || pressure != nil
    }

    // Compatibility accessors for callers that only need the configured target.
    var importanceAtDue: RoutineTaskImportance? { importance?.target }
    var urgencyAtDue: RoutineTaskUrgency? { urgency?.target }
    var pressureAtDue: RoutineTaskPressure? { pressure?.target }

    var sanitized: Self? {
        guard hasAnyTarget else { return nil }
        return Self(
            importance: importance?.sanitized(),
            urgency: urgency?.sanitized(),
            pressure: pressure?.sanitized()
        )
    }

    func sanitized(
        baseImportance: RoutineTaskImportance,
        baseUrgency: RoutineTaskUrgency,
        basePressure: RoutineTaskPressure,
        maximumBeforeDueDays: Int? = nil
    ) -> Self? {
        let sanitizedRule = Self(
            importance: (importance?.target.sortOrder ?? Int.min) > baseImportance.sortOrder
                ? importance?.sanitized(maximumBeforeDueDays: maximumBeforeDueDays)
                : nil,
            urgency: (urgency?.target.sortOrder ?? Int.min) > baseUrgency.sortOrder
                ? urgency?.sanitized(maximumBeforeDueDays: maximumBeforeDueDays)
                : nil,
            pressure: (pressure?.target.sortOrder ?? Int.min) > basePressure.sortOrder
                ? pressure?.sanitized(maximumBeforeDueDays: maximumBeforeDueDays)
                : nil
        )
        return sanitizedRule.sanitized
    }

    private enum CodingKeys: String, CodingKey {
        case importance
        case urgency
        case pressure
        case curve
        case leadDays
        case importanceAtDue
        case urgencyAtDue
        case pressureAtDue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hasIndependentPolicies = container.contains(.importance)
            || container.contains(.urgency)
            || container.contains(.pressure)
        if hasIndependentPolicies {
            self.init(
                importance: try container.decodeIfPresent(
                    RoutineTaskTemporalWeightPolicy<RoutineTaskImportance>.self,
                    forKey: .importance
                ),
                urgency: try container.decodeIfPresent(
                    RoutineTaskTemporalWeightPolicy<RoutineTaskUrgency>.self,
                    forKey: .urgency
                ),
                pressure: try container.decodeIfPresent(
                    RoutineTaskTemporalWeightPolicy<RoutineTaskPressure>.self,
                    forKey: .pressure
                )
            )
            return
        }

        let legacyCurve = try container.decodeIfPresent(
            RoutineTaskTemporalWeightCurve.self,
            forKey: .curve
        ) ?? .onDueDate
        let legacyLeadDays = try container.decodeIfPresent(Int.self, forKey: .leadDays) ?? 7
        self.init(
            curve: legacyCurve,
            leadDays: legacyLeadDays,
            importanceAtDue: try container.decodeIfPresent(
                RoutineTaskImportance.self,
                forKey: .importanceAtDue
            ),
            urgencyAtDue: try container.decodeIfPresent(
                RoutineTaskUrgency.self,
                forKey: .urgencyAtDue
            ),
            pressureAtDue: try container.decodeIfPresent(
                RoutineTaskPressure.self,
                forKey: .pressureAtDue
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(importance, forKey: .importance)
        try container.encodeIfPresent(urgency, forKey: .urgency)
        try container.encodeIfPresent(pressure, forKey: .pressure)
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
        cadenceEnabled: Bool
    ) -> Bool {
        scheduleMode.taskType == .routine
            && scheduleMode.scheduleBehavior == .fixed
            && scheduleMode.usesRoutineCadence
            && cadenceEnabled
    }

    static func supportsTemporalWeight(_ task: RoutineTask) -> Bool {
        supportsTemporalWeight(
            scheduleMode: task.scheduleMode,
            cadenceEnabled: task.cadenceEnabled
        )
    }

    static func maximumBeforeDueDays(for recurrenceRule: RoutineRecurrenceRule) -> Int? {
        guard recurrenceRule.advanced == nil,
              recurrenceRule.kind == .intervalDays else {
            return nil
        }
        return min(
            max(recurrenceRule.approximateIntervalDays, 1),
            RoutineTaskTemporalWeightRule.maximumTransitionDays
        )
    }

    static func sanitizedRule(
        _ rule: RoutineTaskTemporalWeightRule?,
        scheduleMode: RoutineScheduleMode,
        cadenceEnabled: Bool,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure,
        maximumBeforeDueDays: Int? = nil
    ) -> RoutineTaskTemporalWeightRule? {
        guard supportsTemporalWeight(
            scheduleMode: scheduleMode,
            cadenceEnabled: cadenceEnabled
        ) else {
            return nil
        }
        return rule?.sanitized(
            baseImportance: importance,
            baseUrgency: urgency,
            basePressure: pressure,
            maximumBeforeDueDays: maximumBeforeDueDays
        )
    }

    static func sanitizedRule(
        _ rule: RoutineTaskTemporalWeightRule?,
        for task: RoutineTask
    ) -> RoutineTaskTemporalWeightRule? {
        sanitizedRule(
            rule,
            scheduleMode: task.scheduleMode,
            cadenceEnabled: task.cadenceEnabled,
            importance: task.importance,
            urgency: task.urgency,
            pressure: task.pressure,
            maximumBeforeDueDays: maximumBeforeDueDays(for: task.recurrenceRule)
        )
    }

    static func effectiveWeights(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> RoutineTaskEffectiveWeights {
        guard supportsTemporalWeight(task),
              let rule = sanitizedRule(task.temporalWeightRule, for: task) else {
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

        let importance = effectiveValue(
            base: task.importance,
            policy: rule.importance,
            daysUntilDue: daysUntilDue,
            values: RoutineTaskImportance.allCases
        )
        let urgency = effectiveValue(
            base: task.urgency,
            policy: rule.urgency,
            daysUntilDue: daysUntilDue,
            values: RoutineTaskUrgency.allCases
        )
        let pressure = effectiveValue(
            base: task.pressure,
            policy: rule.pressure,
            daysUntilDue: daysUntilDue,
            values: RoutineTaskPressure.allCases
        )

        return RoutineTaskEffectiveWeights(
            importance: importance.value,
            urgency: urgency.value,
            pressure: pressure.value,
            progress: max(importance.progress, urgency.progress, pressure.progress)
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

    private static func effectiveValue<Value>(
        base: Value,
        policy: RoutineTaskTemporalWeightPolicy<Value>?,
        daysUntilDue: Int,
        values: [Value]
    ) -> (value: Value, progress: Double)
    where Value: Codable & Equatable & Sendable {
        guard let policy,
              let baseIndex = values.firstIndex(of: base),
              let targetIndex = values.firstIndex(of: policy.target),
              targetIndex > baseIndex else {
            return (base, 0)
        }

        let distance = targetIndex - baseIndex
        switch policy.timing {
        case .onDueDate:
            return daysUntilDue <= 0 ? (policy.target, 1) : (base, 0)

        case .gradualBeforeDue:
            let leadDays = min(
                max(policy.days, 1),
                RoutineTaskTemporalWeightRule.maximumTransitionDays
            )
            let progress: Double
            if daysUntilDue <= 0 {
                progress = 1
            } else if daysUntilDue >= leadDays {
                progress = 0
            } else {
                progress = Double(leadDays - daysUntilDue) / Double(leadDays)
            }
            return (
                interpolated(
                    base: base,
                    target: policy.target,
                    progress: progress,
                    values: values
                ),
                progress
            )

        case .gradualWhileOverdue:
            guard daysUntilDue < 0 else { return (base, 0) }
            let intervalDays = min(
                max(policy.days, 1),
                RoutineTaskTemporalWeightRule.maximumTransitionDays
            )
            let levels = min(abs(daysUntilDue) / intervalDays, distance)
            guard levels > 0 else { return (base, 0) }
            return (
                values[min(baseIndex + levels, targetIndex)],
                Double(levels) / Double(distance)
            )
        }
    }

    private static func interpolated<Value>(
        base: Value,
        target: Value,
        progress: Double,
        values: [Value]
    ) -> Value where Value: Equatable {
        guard let baseIndex = values.firstIndex(of: base),
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
        pressure: RoutineTaskPressure,
        maximumBeforeDueDays: Int? = nil
    ) -> String? {
        guard let rule = rule?.sanitized(
            baseImportance: importance,
            baseUrgency: urgency,
            basePressure: pressure,
            maximumBeforeDueDays: maximumBeforeDueDays
        ) else {
            return nil
        }

        var parts: [String] = []
        if let policy = rule.importance {
            parts.append(metricSummary(
                title: "Importance",
                base: importance.title,
                target: policy.target.title,
                policy: policy
            ))
        }
        if let policy = rule.urgency {
            parts.append(metricSummary(
                title: "Urgency",
                base: urgency.title,
                target: policy.target.title,
                policy: policy
            ))
        }
        if let policy = rule.pressure {
            parts.append(metricSummary(
                title: "Pressure",
                base: pressure.title,
                target: policy.target.title,
                policy: policy
            ))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    static func metricSummaries(
        rule: RoutineTaskTemporalWeightRule?,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure,
        maximumBeforeDueDays: Int? = nil
    ) -> [String] {
        guard let summary = targetSummary(
            rule: rule,
            importance: importance,
            urgency: urgency,
            pressure: pressure,
            maximumBeforeDueDays: maximumBeforeDueDays
        ) else {
            return []
        }
        return summary.components(separatedBy: " • ")
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
        "After completion: Importance \(importance.title) • Urgency \(urgency.title) • Pressure \(pressure.title)"
    }

    private static func metricSummary<Value>(
        title: String,
        base: String,
        target: String,
        policy: RoutineTaskTemporalWeightPolicy<Value>
    ) -> String where Value: Codable & Equatable & Sendable {
        switch policy.timing {
        case .onDueDate:
            return "\(title) \(base) -> \(target) on due date"
        case .gradualBeforeDue:
            return "\(title) \(base) -> \(target) over \(dayCount(policy.days)) before due"
        case .gradualWhileOverdue:
            return "\(title) \(base) -> \(target), one level every \(dayCount(policy.days)) overdue"
        }
    }

    private static func dayCount(_ days: Int) -> String {
        "\(days) \(days == 1 ? "day" : "days")"
    }
}

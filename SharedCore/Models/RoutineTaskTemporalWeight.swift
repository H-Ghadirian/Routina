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
        let legacyTiming: RoutineTaskTemporalWeightTiming =
            legacyCurve == .gradual
            ? .gradualBeforeDue
            : .onDueDate
        self.importance =
            importance
            ?? legacyImportance.map {
                RoutineTaskTemporalWeightPolicy(
                    target: $0,
                    timing: legacyTiming,
                    days: legacyLeadDays
                )
            }
        self.urgency =
            urgency
            ?? legacyUrgency.map {
                RoutineTaskTemporalWeightPolicy(
                    target: $0,
                    timing: legacyTiming,
                    days: legacyLeadDays
                )
            }
        self.pressure =
            pressure
            ?? legacyPressure.map {
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
        let hasIndependentPolicies =
            container.contains(.importance)
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

        let legacyCurve =
            try container.decodeIfPresent(
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
            let data = try? encoder.encode(rule)
        else {
            return ""
        }
        return String(decoding: data, as: UTF8.self)
    }

    static func deserialize(_ storage: String?) -> RoutineTaskTemporalWeightRule? {
        guard let storage,
            !storage.isEmpty,
            let data = storage.data(using: .utf8),
            let decoded = try? decoder.decode(RoutineTaskTemporalWeightRule.self, from: data)
        else {
            return nil
        }
        return decoded.sanitized
    }
}

enum RoutineTaskLadderEntryWindowMode: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case throughoutCycle
    case beforeDue
    case onDueDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .throughoutCycle: return "Throughout"
        case .beforeDue: return "Before due"
        case .onDueDate: return "On due date"
        }
    }
}

enum RoutineTaskLadderEntryWindow: Equatable, Hashable, Sendable {
    case throughoutCycle
    case beforeDue(days: Int)
    case onDueDate

    static let defaultBeforeDueDays = 7

    init(storageLeadDays: Int?) {
        guard let storageLeadDays else {
            self = .throughoutCycle
            return
        }
        self =
            storageLeadDays <= 0
            ? .onDueDate
            : .beforeDue(days: storageLeadDays)
    }

    var mode: RoutineTaskLadderEntryWindowMode {
        switch self {
        case .throughoutCycle: return .throughoutCycle
        case .beforeDue: return .beforeDue
        case .onDueDate: return .onDueDate
        }
    }

    var storageLeadDays: Int? {
        switch self {
        case .throughoutCycle: return nil
        case let .beforeDue(days): return max(days, 1)
        case .onDueDate: return 0
        }
    }

    func sanitized(maximumBeforeDueDays: Int? = nil) -> Self {
        guard case let .beforeDue(days) = self else { return self }
        let maximum = min(
            max(maximumBeforeDueDays ?? RoutineTaskTemporalWeightRule.maximumTransitionDays, 1),
            RoutineTaskTemporalWeightRule.maximumTransitionDays
        )
        return .beforeDue(days: min(max(days, 1), maximum))
    }
}

/// A compatibility payload stored in the existing version-tolerant Task Ladder
/// JSON field. Temporal policies keep their former top-level keys so older app
/// versions can still read them, while newer versions also preserve entry timing.
struct RoutineTaskLadderConfiguration: Codable, Equatable, Sendable {
    var temporalWeightRule: RoutineTaskTemporalWeightRule?
    var entryLeadDays: Int?

    init(
        temporalWeightRule: RoutineTaskTemporalWeightRule? = nil,
        entryLeadDays: Int? = nil
    ) {
        self.temporalWeightRule = temporalWeightRule?.sanitized
        self.entryLeadDays = entryLeadDays.map { max($0, 0) }
    }

    var isEmpty: Bool {
        temporalWeightRule == nil && entryLeadDays == nil
    }

    private enum CodingKeys: String, CodingKey {
        case importance
        case urgency
        case pressure
        case entryLeadDays
        case temporalWeightRule
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let wrappedRule = try container.decodeIfPresent(
            RoutineTaskTemporalWeightRule.self,
            forKey: .temporalWeightRule
        )
        let directRule = try? RoutineTaskTemporalWeightRule(from: decoder)
        self.init(
            temporalWeightRule: wrappedRule ?? directRule?.sanitized,
            entryLeadDays: try container.decodeIfPresent(Int.self, forKey: .entryLeadDays)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(temporalWeightRule?.importance, forKey: .importance)
        try container.encodeIfPresent(temporalWeightRule?.urgency, forKey: .urgency)
        try container.encodeIfPresent(temporalWeightRule?.pressure, forKey: .pressure)
        try container.encodeIfPresent(entryLeadDays, forKey: .entryLeadDays)
    }
}

enum RoutineTaskLadderConfigurationStorage {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func serialize(_ configuration: RoutineTaskLadderConfiguration) -> String {
        let sanitized = RoutineTaskLadderConfiguration(
            temporalWeightRule: configuration.temporalWeightRule,
            entryLeadDays: configuration.entryLeadDays
        )
        guard !sanitized.isEmpty,
            let data = try? encoder.encode(sanitized)
        else {
            return ""
        }
        return String(decoding: data, as: UTF8.self)
    }

    static func deserialize(_ storage: String?) -> RoutineTaskLadderConfiguration {
        guard let storage,
            !storage.isEmpty,
            let data = storage.data(using: .utf8)
        else {
            return RoutineTaskLadderConfiguration()
        }

        if let configuration = try? decoder.decode(
            RoutineTaskLadderConfiguration.self,
            from: data
        ), !configuration.isEmpty {
            return RoutineTaskLadderConfiguration(
                temporalWeightRule: configuration.temporalWeightRule,
                entryLeadDays: configuration.entryLeadDays
            )
        }

        return RoutineTaskLadderConfiguration(
            temporalWeightRule: RoutineTaskTemporalWeightStorage.deserialize(storage)
        )
    }
}

import Foundation

struct RoutineRecurrenceRule: Codable, Equatable, Hashable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case interval
        case timeOfDay
        case timeRange
        case weekday
        case dayOfMonth
        case weekdays
        case daysOfMonth
        case advanced
    }

    enum Kind: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
        case intervalDays
        case dailyTime
        case weekly
        case monthlyDay

        static let calendarCases: [Kind] = [.weekly, .monthlyDay]

        var repeatBasis: RoutineRepeatBasis {
            self == .intervalDays ? .interval : .calendar
        }

        var pickerTitle: String {
            switch self {
            case .intervalDays:
                return "Interval"
            case .dailyTime:
                return "Daily"
            case .weekly:
                return "Weekday"
            case .monthlyDay:
                return "Month day"
            }
        }

        func replacingRepeatBasis(_ basis: RoutineRepeatBasis) -> Kind {
            switch basis {
            case .interval:
                return .intervalDays
            case .calendar:
                return Self.calendarCases.contains(self) ? self : .weekly
            }
        }
    }

    var kind: Kind
    var interval: Int
    var timeOfDay: RoutineTimeOfDay?
    var timeRange: RoutineTimeRange?
    var weekday: Int?
    var dayOfMonth: Int?
    var weekdays: [Int]
    var daysOfMonth: [Int]
    var advanced: RoutineAdvancedRecurrenceRule?

    init(
        kind: Kind,
        interval: Int = 1,
        timeOfDay: RoutineTimeOfDay? = nil,
        timeRange: RoutineTimeRange? = nil,
        weekday: Int? = nil,
        dayOfMonth: Int? = nil,
        weekdays: [Int]? = nil,
        daysOfMonth: [Int]? = nil,
        advanced: RoutineAdvancedRecurrenceRule? = nil
    ) {
        self.kind = kind
        self.advanced = advanced

        switch kind {
        case .intervalDays:
            self.interval = max(interval, 1)
            self.timeOfDay = timeRange == nil ? timeOfDay : nil
            self.timeRange = timeRange
            self.weekday = nil
            self.dayOfMonth = nil
            self.weekdays = []
            self.daysOfMonth = []

        case .dailyTime:
            self.interval = 1
            self.timeOfDay = timeRange == nil ? timeOfDay : nil
            self.timeRange = timeRange
            self.weekday = nil
            self.dayOfMonth = nil
            self.weekdays = []
            self.daysOfMonth = []

        case .weekly:
            let resolvedWeekdays = Self.clampedWeekdays(weekdays ?? weekday.map { [$0] })
            self.interval = 1
            self.timeOfDay = timeRange == nil ? timeOfDay : nil
            self.timeRange = timeRange
            self.weekday = resolvedWeekdays.first
            self.dayOfMonth = nil
            self.weekdays = resolvedWeekdays
            self.daysOfMonth = []

        case .monthlyDay:
            let resolvedDays = Self.clampedDaysOfMonth(daysOfMonth ?? dayOfMonth.map { [$0] })
            self.interval = 1
            self.timeOfDay = timeRange == nil ? timeOfDay : nil
            self.timeRange = timeRange
            self.weekday = nil
            self.dayOfMonth = resolvedDays.first
            self.weekdays = []
            self.daysOfMonth = resolvedDays
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        let interval = try container.decodeIfPresent(Int.self, forKey: .interval) ?? 1
        let timeOfDay = try container.decodeIfPresent(RoutineTimeOfDay.self, forKey: .timeOfDay)
        let timeRange = try container.decodeIfPresent(RoutineTimeRange.self, forKey: .timeRange)
        let weekday = try container.decodeIfPresent(Int.self, forKey: .weekday)
        let dayOfMonth = try container.decodeIfPresent(Int.self, forKey: .dayOfMonth)
        let weekdays = try container.decodeIfPresent([Int].self, forKey: .weekdays)
        let daysOfMonth = try container.decodeIfPresent([Int].self, forKey: .daysOfMonth)
        let advanced = try container.decodeIfPresent(RoutineAdvancedRecurrenceRule.self, forKey: .advanced)
        self.init(
            kind: kind,
            interval: interval,
            timeOfDay: timeOfDay,
            timeRange: timeRange,
            weekday: weekday,
            dayOfMonth: dayOfMonth,
            weekdays: weekdays,
            daysOfMonth: daysOfMonth,
            advanced: advanced
        )
    }

    static func advanced(_ advancedRule: RoutineAdvancedRecurrenceRule) -> RoutineRecurrenceRule {
        advanced(advancedRule, timeRange: nil)
    }

    static func advanced(
        _ advancedRule: RoutineAdvancedRecurrenceRule,
        timeRange: RoutineTimeRange?
    ) -> RoutineRecurrenceRule {
        let normalized = advancedRule.normalized()
        let timeOfDay =
            timeRange == nil
            ? normalized.timesOfDay.first ?? RoutineTimeOfDay.from(normalized.startDate)
            : nil

        switch normalized.frequency {
        case .hourly, .daily:
            return RoutineRecurrenceRule(
                kind: .intervalDays,
                interval: max(normalized.approximateIntervalDays, 1),
                timeOfDay: timeOfDay,
                timeRange: timeRange,
                advanced: normalized
            )
        case .weekly:
            return RoutineRecurrenceRule(
                kind: .weekly,
                timeOfDay: timeOfDay,
                timeRange: timeRange,
                weekdays: normalized.weekdays,
                advanced: normalized
            )
        case .monthly, .yearly:
            return RoutineRecurrenceRule(
                kind: .monthlyDay,
                timeOfDay: timeOfDay,
                timeRange: timeRange,
                daysOfMonth: normalized.monthDays,
                advanced: normalized
            )
        }
    }

    static func interval(
        days: Int,
        at timeOfDay: RoutineTimeOfDay? = nil,
        timeRange: RoutineTimeRange? = nil
    ) -> RoutineRecurrenceRule {
        RoutineRecurrenceRule(
            kind: .intervalDays,
            interval: days,
            timeOfDay: timeOfDay,
            timeRange: timeRange
        )
    }

    static func daily(at timeOfDay: RoutineTimeOfDay) -> RoutineRecurrenceRule {
        RoutineRecurrenceRule(kind: .dailyTime, timeOfDay: timeOfDay)
    }

    static func daily(in timeRange: RoutineTimeRange) -> RoutineRecurrenceRule {
        RoutineRecurrenceRule(kind: .dailyTime, timeRange: timeRange)
    }

    static func weekly(
        on weekday: Int,
        at timeOfDay: RoutineTimeOfDay? = nil,
        timeRange: RoutineTimeRange? = nil
    ) -> RoutineRecurrenceRule {
        RoutineRecurrenceRule(
            kind: .weekly,
            timeOfDay: timeOfDay,
            timeRange: timeRange,
            weekday: weekday
        )
    }

    static func weekly(
        on weekdays: [Int],
        at timeOfDay: RoutineTimeOfDay? = nil,
        timeRange: RoutineTimeRange? = nil
    ) -> RoutineRecurrenceRule {
        RoutineRecurrenceRule(
            kind: .weekly,
            timeOfDay: timeOfDay,
            timeRange: timeRange,
            weekdays: weekdays
        )
    }

    static func monthly(
        on dayOfMonth: Int,
        at timeOfDay: RoutineTimeOfDay? = nil,
        timeRange: RoutineTimeRange? = nil
    ) -> RoutineRecurrenceRule {
        RoutineRecurrenceRule(
            kind: .monthlyDay,
            timeOfDay: timeOfDay,
            timeRange: timeRange,
            dayOfMonth: dayOfMonth
        )
    }

    static func monthly(
        on daysOfMonth: [Int],
        at timeOfDay: RoutineTimeOfDay? = nil,
        timeRange: RoutineTimeRange? = nil
    ) -> RoutineRecurrenceRule {
        RoutineRecurrenceRule(
            kind: .monthlyDay,
            timeOfDay: timeOfDay,
            timeRange: timeRange,
            daysOfMonth: daysOfMonth
        )
    }

    var isFixedCalendar: Bool {
        advanced != nil || kind != .intervalDays
    }

    var approximateIntervalDays: Int {
        if let advanced {
            return max(advanced.approximateIntervalDays, 1)
        }
        switch kind {
        case .intervalDays:
            return max(interval, 1)
        case .dailyTime:
            return 1
        case .weekly:
            return 7
        case .monthlyDay:
            return 30
        }
    }

    var usesExplicitTimeOfDay: Bool {
        advanced != nil || timeOfDay != nil
    }

    var usesTimeRange: Bool {
        timeRange != nil
    }

    var usesTimeConstraint: Bool {
        advanced != nil || usesExplicitTimeOfDay || usesTimeRange
    }

    var isDaily: Bool {
        if let advanced {
            return advanced.isDaily
        }
        switch kind {
        case .intervalDays:
            return max(interval, 1) == 1
        case .dailyTime:
            return true
        case .weekly, .monthlyDay:
            return false
        }
    }

    var hasMultipleCalendarSelections: Bool {
        weekdays.count > 1 || daysOfMonth.count > 1
    }

    var requiresStructuredStorage: Bool {
        advanced != nil || hasMultipleCalendarSelections
    }

    var usesAdvancedModel: Bool {
        advanced != nil
    }

    var occursMoreThanOncePerDay: Bool {
        advanced?.occursMoreThanOncePerDay == true
    }

    func resolvedWeekdays(calendar: Calendar = .current) -> [Int] {
        switch kind {
        case .weekly:
            return Self.clampedWeekdays(weekdays.isEmpty ? [weekday ?? calendar.firstWeekday] : weekdays)
        case .intervalDays, .dailyTime, .monthlyDay:
            return []
        }
    }

    func resolvedDaysOfMonth(calendar: Calendar = .current) -> [Int] {
        switch kind {
        case .monthlyDay:
            return Self.clampedDaysOfMonth(
                daysOfMonth.isEmpty ? [dayOfMonth ?? calendar.component(.day, from: Date())] : daysOfMonth
            )
        case .intervalDays, .dailyTime, .weekly:
            return []
        }
    }

    static func clampedWeekdays(_ weekdays: [Int]?) -> [Int] {
        let resolved = (weekdays?.isEmpty == false ? weekdays ?? [] : [Calendar.current.firstWeekday])
            .map { min(max($0, 1), 7) }
        return Array(Set(resolved)).sorted()
    }

    static func clampedDaysOfMonth(_ daysOfMonth: [Int]?) -> [Int] {
        let resolved =
            (daysOfMonth?.isEmpty == false
            ? daysOfMonth ?? []
            : [Calendar.current.component(.day, from: Date())])
            .map { min(max($0, 1), 31) }
        return Array(Set(resolved)).sorted()
    }

}

enum RoutineRepeatBasis: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case interval = "Interval"
    case calendar = "Calendar"

    var id: String { rawValue }
}

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

    init(
        kind: Kind,
        interval: Int = 1,
        timeOfDay: RoutineTimeOfDay? = nil,
        timeRange: RoutineTimeRange? = nil,
        weekday: Int? = nil,
        dayOfMonth: Int? = nil,
        weekdays: [Int]? = nil,
        daysOfMonth: [Int]? = nil
    ) {
        self.kind = kind

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
        self.init(
            kind: kind,
            interval: interval,
            timeOfDay: timeOfDay,
            timeRange: timeRange,
            weekday: weekday,
            dayOfMonth: dayOfMonth,
            weekdays: weekdays,
            daysOfMonth: daysOfMonth
        )
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
        kind != .intervalDays
    }

    var approximateIntervalDays: Int {
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
        timeOfDay != nil
    }

    var usesTimeRange: Bool {
        timeRange != nil
    }

    var usesTimeConstraint: Bool {
        usesExplicitTimeOfDay || usesTimeRange
    }

    var isDaily: Bool {
        switch kind {
        case .intervalDays:
            return max(interval, 1) == 1
        case .dailyTime:
            return true
        case .weekly, .monthlyDay:
            return false
        }
    }

    func displayText(calendar: Calendar = .current) -> String {
        switch kind {
        case .intervalDays:
            let resolvedInterval = max(interval, 1)
            let baseText: String
            if resolvedInterval % 30 == 0 {
                let months = resolvedInterval / 30
                baseText = months == 1 ? "Every month" : "Every \(months) months"
            } else if resolvedInterval % 7 == 0 {
                let weeks = resolvedInterval / 7
                baseText = weeks == 1 ? "Every week" : "Every \(weeks) weeks"
            } else {
                baseText = resolvedInterval == 1 ? "Every day" : "Every \(resolvedInterval) days"
            }
            if let timeRange {
                return "\(baseText) from \(timeRange.formatted(calendar: calendar))"
            }
            if let timeOfDay {
                return "\(baseText) at \(timeOfDay.formatted(calendar: calendar))"
            }
            return baseText

        case .dailyTime:
            if let timeRange {
                return "Every day from \(timeRange.formatted(calendar: calendar))"
            }
            if let timeOfDay {
                return "Every day at \(timeOfDay.formatted(calendar: calendar))"
            }
            return "Every day"

        case .weekly:
            let weekdayNames = resolvedWeekdays(calendar: calendar).map {
                Self.weekdayName(for: $0, calendar: calendar)
            }
            let weekdayText = Self.formattedList(weekdayNames)
            if let timeRange {
                return "Every \(weekdayText) from \(timeRange.formatted(calendar: calendar))"
            }
            if let timeOfDay {
                return "Every \(weekdayText) at \(timeOfDay.formatted(calendar: calendar))"
            }
            return "Every \(weekdayText)"

        case .monthlyDay:
            if let timeRange {
                return Self.monthlyDisplayText(
                    for: resolvedDaysOfMonth(),
                    timingText: "from \(timeRange.formatted(calendar: calendar))"
                )
            }
            if let timeOfDay {
                return Self.monthlyDisplayText(
                    for: resolvedDaysOfMonth(),
                    timingText: "at \(timeOfDay.formatted(calendar: calendar))"
                )
            }
            return Self.monthlyDisplayText(for: resolvedDaysOfMonth())
        }
    }

    var hasMultipleCalendarSelections: Bool {
        weekdays.count > 1 || daysOfMonth.count > 1
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

    private static func clampedWeekday(_ weekday: Int?) -> Int {
        min(max(weekday ?? Calendar.current.firstWeekday, 1), 7)
    }

    static func clampedWeekdays(_ weekdays: [Int]?) -> [Int] {
        let resolved = (weekdays?.isEmpty == false ? weekdays ?? [] : [Calendar.current.firstWeekday])
            .map { min(max($0, 1), 7) }
        return Array(Set(resolved)).sorted()
    }

    private static func clampedDayOfMonth(_ dayOfMonth: Int?) -> Int {
        min(max(dayOfMonth ?? Calendar.current.component(.day, from: Date()), 1), 31)
    }

    static func clampedDaysOfMonth(_ daysOfMonth: [Int]?) -> [Int] {
        let resolved = (daysOfMonth?.isEmpty == false
            ? daysOfMonth ?? []
            : [Calendar.current.component(.day, from: Date())])
            .map { min(max($0, 1), 31) }
        return Array(Set(resolved)).sorted()
    }

    private static func weekdayName(
        for weekday: Int,
        calendar: Calendar
    ) -> String {
        let symbols = calendar.weekdaySymbols
        let safeIndex = min(max(weekday - 1, 0), max(symbols.count - 1, 0))
        return symbols[safeIndex]
    }

    private static func ordinalString(for day: Int) -> String {
        let resolvedDay = clampedDayOfMonth(day)
        let suffix: String
        switch resolvedDay % 100 {
        case 11, 12, 13:
            suffix = "th"
        default:
            switch resolvedDay % 10 {
            case 1:
                suffix = "st"
            case 2:
                suffix = "nd"
            case 3:
                suffix = "rd"
            default:
                suffix = "th"
            }
        }
        return "\(resolvedDay)\(suffix)"
    }

    private static func monthlyDisplayText(
        for day: Int,
        timingText: String? = nil
    ) -> String {
        let resolvedDay = clampedDayOfMonth(day)
        let suffix = timingText.map { " \($0)" } ?? ""
        switch resolvedDay {
        case 31:
            return "Every last day of the month\(suffix)"
        case 29, 30:
            return "Every \(ordinalString(for: resolvedDay))\(suffix); shorter months use last day"
        default:
            return "Every \(ordinalString(for: resolvedDay)) of the month\(suffix)"
        }
    }

    private static func monthlyDisplayText(
        for days: [Int],
        timingText: String? = nil
    ) -> String {
        let resolvedDays = clampedDaysOfMonth(days)
        guard resolvedDays.count > 1 else {
            return monthlyDisplayText(for: resolvedDays.first ?? 1, timingText: timingText)
        }
        let dayText = formattedList(resolvedDays.map(monthlyDayListLabel))
        let suffix = timingText.map { " \($0)" } ?? ""
        let fallback = resolvedDays.contains { $0 >= 29 } ? "; shorter months use last day" : ""
        return "Every \(dayText) of the month\(suffix)\(fallback)"
    }

    private static func monthlyDayListLabel(for day: Int) -> String {
        let resolvedDay = clampedDayOfMonth(day)
        return resolvedDay == 31 ? "last day" : ordinalString(for: resolvedDay)
    }

    private static func formattedList(_ values: [String]) -> String {
        switch values.count {
        case 0:
            return ""
        case 1:
            return values[0]
        case 2:
            return "\(values[0]) and \(values[1])"
        default:
            return "\(values.dropLast().joined(separator: ", ")), and \(values.last ?? "")"
        }
    }
}

enum RoutineRepeatBasis: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case interval = "Interval"
    case calendar = "Calendar"

    var id: String { rawValue }
}

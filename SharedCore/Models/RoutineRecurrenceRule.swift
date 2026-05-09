import Foundation

struct RoutineRecurrenceRule: Codable, Equatable, Hashable, Sendable {
    enum Kind: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
        case intervalDays
        case dailyTime
        case weekly
        case monthlyDay

        var pickerTitle: String {
            switch self {
            case .intervalDays:
                return "Interval"
            case .dailyTime:
                return "Time"
            case .weekly:
                return "Week"
            case .monthlyDay:
                return "Month"
            }
        }
    }

    var kind: Kind
    var interval: Int
    var timeOfDay: RoutineTimeOfDay?
    var timeRange: RoutineTimeRange?
    var weekday: Int?
    var dayOfMonth: Int?

    init(
        kind: Kind,
        interval: Int = 1,
        timeOfDay: RoutineTimeOfDay? = nil,
        timeRange: RoutineTimeRange? = nil,
        weekday: Int? = nil,
        dayOfMonth: Int? = nil
    ) {
        self.kind = kind

        switch kind {
        case .intervalDays:
            self.interval = max(interval, 1)
            self.timeOfDay = nil
            self.timeRange = nil
            self.weekday = nil
            self.dayOfMonth = nil

        case .dailyTime:
            self.interval = 1
            self.timeOfDay = timeRange == nil ? (timeOfDay ?? .defaultValue) : nil
            self.timeRange = timeRange
            self.weekday = nil
            self.dayOfMonth = nil

        case .weekly:
            self.interval = 1
            self.timeOfDay = timeRange == nil ? timeOfDay : nil
            self.timeRange = timeRange
            self.weekday = Self.clampedWeekday(weekday)
            self.dayOfMonth = nil

        case .monthlyDay:
            self.interval = 1
            self.timeOfDay = timeRange == nil ? timeOfDay : nil
            self.timeRange = timeRange
            self.weekday = nil
            self.dayOfMonth = Self.clampedDayOfMonth(dayOfMonth)
        }
    }

    static func interval(days: Int) -> RoutineRecurrenceRule {
        RoutineRecurrenceRule(kind: .intervalDays, interval: days)
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
            if resolvedInterval % 30 == 0 {
                let months = resolvedInterval / 30
                return months == 1 ? "Every month" : "Every \(months) months"
            }
            if resolvedInterval % 7 == 0 {
                let weeks = resolvedInterval / 7
                return weeks == 1 ? "Every week" : "Every \(weeks) weeks"
            }
            return resolvedInterval == 1 ? "Every day" : "Every \(resolvedInterval) days"

        case .dailyTime:
            if let timeRange {
                return "Every day from \(timeRange.formatted(calendar: calendar))"
            }
            let timeText = (timeOfDay ?? .defaultValue).formatted(calendar: calendar)
            return "Every day at \(timeText)"

        case .weekly:
            let weekdayName = Self.weekdayName(for: weekday ?? calendar.firstWeekday, calendar: calendar)
            if let timeRange {
                return "Every \(weekdayName) from \(timeRange.formatted(calendar: calendar))"
            }
            if let timeOfDay {
                return "Every \(weekdayName) at \(timeOfDay.formatted(calendar: calendar))"
            }
            return "Every \(weekdayName)"

        case .monthlyDay:
            let ordinalDay = Self.ordinalString(for: dayOfMonth ?? 1)
            if let timeRange {
                return "Every \(ordinalDay) from \(timeRange.formatted(calendar: calendar))"
            }
            if let timeOfDay {
                return "Every \(ordinalDay) at \(timeOfDay.formatted(calendar: calendar))"
            }
            return "Every \(ordinalDay) of the month"
        }
    }

    private static func clampedWeekday(_ weekday: Int?) -> Int {
        min(max(weekday ?? Calendar.current.firstWeekday, 1), 7)
    }

    private static func clampedDayOfMonth(_ dayOfMonth: Int?) -> Int {
        min(max(dayOfMonth ?? Calendar.current.component(.day, from: Date()), 1), 31)
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
}

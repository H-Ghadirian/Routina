import Foundation

enum RoutineRecurrenceEditorMode: String, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
    case simple = "Simple"
    case advanced = "Advanced"

    var id: String { rawValue }
}

struct RoutineAdvancedRecurrenceRule: Codable, Equatable, Hashable, Sendable {
    enum Frequency: String, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
        case hourly = "Hourly"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        case yearly = "Yearly"

        var id: String { rawValue }

        func unitName(for value: Int) -> String {
            let singular: String
            switch self {
            case .hourly: singular = "hour"
            case .daily: singular = "day"
            case .weekly: singular = "week"
            case .monthly: singular = "month"
            case .yearly: singular = "year"
            }
            return value == 1 ? singular : "\(singular)s"
        }
    }

    enum HourlyMode: String, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
        case continuous = "Continuously"
        case dailyWindow = "During each day"

        var id: String { rawValue }

        var displayTitle: String {
            switch self {
            case .continuous: return "Continuously"
            case .dailyWindow: return "Daily window"
            }
        }
    }

    enum MonthlyPattern: String, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
        case dayOfMonth = "Day of month"
        case ordinalWeekday = "Weekday"

        var id: String { rawValue }
    }

    enum WeekdayOrdinal: Int, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
        case first = 1
        case second = 2
        case third = 3
        case fourth = 4
        case last = -1

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .first: return "First"
            case .second: return "Second"
            case .third: return "Third"
            case .fourth: return "Fourth"
            case .last: return "Last"
            }
        }
    }

    enum EndMode: String, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
        case never = "Never"
        case onDate = "On date"
        case afterCount = "After occurrences"

        var id: String { rawValue }
    }

    var version: Int
    var frequency: Frequency
    var interval: Int
    var startDate: Date
    var weekdays: [Int]
    var monthDays: [Int]
    var monthlyPattern: MonthlyPattern
    var weekdayOrdinal: WeekdayOrdinal
    var ordinalWeekday: Int
    var monthsOfYear: [Int]
    var timesOfDay: [RoutineTimeOfDay]
    var hourlyMode: HourlyMode
    var dailyWindowStart: RoutineTimeOfDay
    var dailyWindowEnd: RoutineTimeOfDay
    var endMode: EndMode
    var endDate: Date
    var occurrenceCount: Int
    var timeZoneIdentifier: String

    init(
        version: Int = 1,
        frequency: Frequency = .weekly,
        interval: Int = 1,
        startDate: Date = Date(),
        weekdays: [Int] = [],
        monthDays: [Int] = [],
        monthlyPattern: MonthlyPattern = .dayOfMonth,
        weekdayOrdinal: WeekdayOrdinal = .first,
        ordinalWeekday: Int? = nil,
        monthsOfYear: [Int] = [],
        timesOfDay: [RoutineTimeOfDay] = [],
        hourlyMode: HourlyMode = .continuous,
        dailyWindowStart: RoutineTimeOfDay = RoutineTimeOfDay(hour: 7, minute: 0),
        dailyWindowEnd: RoutineTimeOfDay = RoutineTimeOfDay(hour: 22, minute: 0),
        endMode: EndMode = .never,
        endDate: Date? = nil,
        occurrenceCount: Int = 10,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        calendar: Calendar = .current
    ) {
        self.version = max(version, 1)
        self.frequency = frequency
        self.interval = max(interval, 1)
        self.startDate = startDate
        self.weekdays = Self.sanitizedWeekdays(
            weekdays.isEmpty ? [calendar.component(.weekday, from: startDate)] : weekdays
        )
        self.monthDays = Self.sanitizedMonthDays(
            monthDays.isEmpty ? [calendar.component(.day, from: startDate)] : monthDays
        )
        self.monthlyPattern = monthlyPattern
        self.weekdayOrdinal = weekdayOrdinal
        self.ordinalWeekday = min(max(
            ordinalWeekday ?? calendar.component(.weekday, from: startDate),
            1
        ), 7)
        self.monthsOfYear = Self.sanitizedMonths(
            monthsOfYear.isEmpty ? [calendar.component(.month, from: startDate)] : monthsOfYear
        )
        self.timesOfDay = Self.sanitizedTimes(
            timesOfDay.isEmpty ? [RoutineTimeOfDay.from(startDate, calendar: calendar)] : timesOfDay
        )
        self.hourlyMode = hourlyMode
        self.dailyWindowStart = dailyWindowStart
        self.dailyWindowEnd = dailyWindowEnd
        self.endMode = endMode
        self.endDate = endDate ?? calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        self.occurrenceCount = max(occurrenceCount, 1)
        self.timeZoneIdentifier = TimeZone(identifier: timeZoneIdentifier)?.identifier
            ?? TimeZone.current.identifier
    }

    var approximateIntervalDays: Int {
        switch frequency {
        case .hourly: return 1
        case .daily: return interval
        case .weekly: return interval * 7
        case .monthly: return interval * 30
        case .yearly: return interval * 365
        }
    }

    var occursMoreThanOncePerDay: Bool {
        frequency == .hourly || (frequency == .daily && timesOfDay.count > 1)
    }

    var isDaily: Bool {
        frequency == .hourly || (frequency == .daily && interval == 1)
    }

    func normalized(calendar: Calendar = .current) -> Self {
        Self(
            version: version,
            frequency: frequency,
            interval: interval,
            startDate: startDate,
            weekdays: weekdays,
            monthDays: monthDays,
            monthlyPattern: monthlyPattern,
            weekdayOrdinal: weekdayOrdinal,
            ordinalWeekday: ordinalWeekday,
            monthsOfYear: monthsOfYear,
            timesOfDay: timesOfDay,
            hourlyMode: hourlyMode,
            dailyWindowStart: dailyWindowStart,
            dailyWindowEnd: dailyWindowEnd,
            endMode: endMode,
            endDate: endDate,
            occurrenceCount: occurrenceCount,
            timeZoneIdentifier: timeZoneIdentifier,
            calendar: calendar
        )
    }

    func summary(calendar: Calendar = .current) -> String {
        let normalized = normalized(calendar: calendar)
        let cadence: String
        switch normalized.frequency {
        case .hourly:
            cadence = normalized.hourlyMode == .continuous
                ? "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval)) continuously"
                : "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval)) from \(normalized.dailyWindowStart.formatted(calendar: calendar)) to \(normalized.dailyWindowEnd.formatted(calendar: calendar)) each day"
        case .daily:
            cadence = "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval)) at \(Self.timeList(normalized.timesOfDay, calendar: calendar))"
        case .weekly:
            cadence = "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval)) on \(Self.weekdayList(normalized.weekdays, calendar: calendar))"
        case .monthly:
            if normalized.monthlyPattern == .ordinalWeekday {
                cadence = "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval)) on the \(normalized.weekdayOrdinal.title.lowercased()) \(Self.weekdayName(normalized.ordinalWeekday, calendar: calendar))"
            } else {
                cadence = "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval)) on \(Self.monthDayList(normalized.monthDays))"
            }
        case .yearly:
            cadence = "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval)) on \(Self.yearlyDateList(months: normalized.monthsOfYear, days: normalized.monthDays, calendar: calendar))"
        }

        let startText = Self.dateTimeText(normalized.startDate, calendar: calendar)
        let endText: String
        switch normalized.endMode {
        case .never:
            endText = ""
        case .onDate:
            endText = ", ending \(Self.dateText(normalized.endDate, calendar: calendar))"
        case .afterCount:
            endText = ", for \(normalized.occurrenceCount) occurrences"
        }
        return "\(cadence), starting \(startText)\(endText)."
    }

    private static func sanitizedWeekdays(_ weekdays: [Int]) -> [Int] {
        Array(Set(weekdays.map { min(max($0, 1), 7) })).sorted()
    }

    private static func sanitizedMonthDays(_ days: [Int]) -> [Int] {
        Array(Set(days.map { min(max($0, 1), 31) })).sorted()
    }

    private static func sanitizedMonths(_ months: [Int]) -> [Int] {
        Array(Set(months.map { min(max($0, 1), 12) })).sorted()
    }

    private static func sanitizedTimes(_ times: [RoutineTimeOfDay]) -> [RoutineTimeOfDay] {
        Array(Set(times)).sorted {
            ($0.hour, $0.minute) < ($1.hour, $1.minute)
        }
    }

    private static func timeList(_ times: [RoutineTimeOfDay], calendar: Calendar) -> String {
        formattedList(times.map { $0.formatted(calendar: calendar) })
    }

    private static func weekdayList(_ weekdays: [Int], calendar: Calendar) -> String {
        formattedList(weekdays.map { weekdayName($0, calendar: calendar) })
    }

    private static func weekdayName(_ weekday: Int, calendar: Calendar) -> String {
        let symbols = calendar.weekdaySymbols
        return symbols[min(max(weekday - 1, 0), symbols.count - 1)]
    }

    private static func monthDayList(_ days: [Int]) -> String {
        formattedList(days.map(ordinalDay))
    }

    private static func yearlyDateList(months: [Int], days: [Int], calendar: Calendar) -> String {
        let symbols = calendar.monthSymbols
        let values = months.flatMap { month in
            days.map { day in
                "\(symbols[min(max(month - 1, 0), symbols.count - 1)]) \(day)"
            }
        }
        return formattedList(values)
    }

    private static func ordinalDay(_ day: Int) -> String {
        let suffix: String
        switch day % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch day % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(day)\(suffix)"
    }

    private static func formattedList(_ values: [String]) -> String {
        switch values.count {
        case 0: return ""
        case 1: return values[0]
        case 2: return "\(values[0]) and \(values[1])"
        default: return "\(values.dropLast().joined(separator: ", ")), and \(values.last ?? "")"
        }
    }

    private static func dateTimeText(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func dateText(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

enum RoutineAdvancedRecurrenceGenerator {
    private static let maximumGeneratedOccurrences = 100_000

    static func nextOccurrence(
        for rule: RoutineAdvancedRecurrenceRule,
        after date: Date?,
        calendar inputCalendar: Calendar = .current
    ) -> Date? {
        occurrences(for: rule, after: date, limit: 1, calendar: inputCalendar).first
    }

    static func occurrences(
        for inputRule: RoutineAdvancedRecurrenceRule,
        after date: Date?,
        limit: Int,
        calendar inputCalendar: Calendar = .current
    ) -> [Date] {
        guard limit > 0 else { return [] }
        var calendar = inputCalendar
        if let timeZone = TimeZone(identifier: inputRule.timeZoneIdentifier) {
            calendar.timeZone = timeZone
        }
        let rule = inputRule.normalized(calendar: calendar)
        let threshold = date ?? rule.startDate.addingTimeInterval(-0.001)

        switch rule.frequency {
        case .hourly:
            if rule.hourlyMode == .dailyWindow {
                return dailyWindowOccurrences(for: rule, after: threshold, limit: limit, calendar: calendar)
            }
            return continuousHourlyOccurrences(for: rule, after: threshold, limit: limit, calendar: calendar)
        case .daily:
            return dailyOccurrences(for: rule, after: threshold, limit: limit, calendar: calendar)
        case .weekly:
            return weeklyOccurrences(for: rule, after: threshold, limit: limit, calendar: calendar)
        case .monthly:
            return monthlyOccurrences(for: rule, after: threshold, limit: limit, calendar: calendar)
        case .yearly:
            return yearlyOccurrences(for: rule, after: threshold, limit: limit, calendar: calendar)
        }
    }

    static func occurrence(
        for inputRule: RoutineAdvancedRecurrenceRule,
        onOrBefore date: Date,
        after completedOccurrence: Date?,
        calendar inputCalendar: Calendar = .current
    ) -> Date? {
        let occurrences = occurrences(
            for: inputRule,
            after: completedOccurrence,
            limit: maximumGeneratedOccurrences,
            calendar: inputCalendar
        )
        return occurrences.prefix { $0 <= date }.last
    }

    private static func continuousHourlyOccurrences(
        for rule: RoutineAdvancedRecurrenceRule,
        after threshold: Date,
        limit: Int,
        calendar: Calendar
    ) -> [Date] {
        collect(rule: rule, after: threshold, limit: limit, calendar: calendar) { index in
            calendar.date(byAdding: .hour, value: index * rule.interval, to: rule.startDate)
        }
    }

    private static func dailyOccurrences(
        for rule: RoutineAdvancedRecurrenceRule,
        after threshold: Date,
        limit: Int,
        calendar: Calendar
    ) -> [Date] {
        var generatedIndex = 0
        var results: [Date] = []
        for periodIndex in 0..<maximumGeneratedOccurrences where results.count < limit {
            guard let day = calendar.date(byAdding: .day, value: periodIndex * rule.interval, to: rule.startDate) else {
                break
            }
            for candidate in candidates(on: day, times: rule.timesOfDay, calendar: calendar) {
                guard candidate >= rule.startDate else { continue }
                if shouldStop(rule: rule, candidate: candidate, generatedIndex: generatedIndex, calendar: calendar) {
                    return results
                }
                if candidate > threshold {
                    results.append(candidate)
                    if results.count == limit { return results }
                }
                generatedIndex += 1
            }
        }
        return results
    }

    private static func weeklyOccurrences(
        for rule: RoutineAdvancedRecurrenceRule,
        after threshold: Date,
        limit: Int,
        calendar: Calendar
    ) -> [Date] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: rule.startDate)?.start
            ?? calendar.startOfDay(for: rule.startDate)
        let time = rule.timesOfDay.first ?? RoutineTimeOfDay.from(rule.startDate, calendar: calendar)
        var generatedIndex = 0
        var results: [Date] = []

        for periodIndex in 0..<maximumGeneratedOccurrences where results.count < limit {
            guard let periodStart = calendar.date(
                byAdding: .weekOfYear,
                value: periodIndex * rule.interval,
                to: weekStart
            ) else { break }
            let periodCandidates = rule.weekdays.compactMap { weekday -> Date? in
                let offset = (weekday - calendar.firstWeekday + 7) % 7
                guard let day = calendar.date(byAdding: .day, value: offset, to: periodStart) else { return nil }
                return time.date(on: day, calendar: calendar)
            }.sorted()
            for candidate in periodCandidates where candidate >= rule.startDate {
                if shouldStop(rule: rule, candidate: candidate, generatedIndex: generatedIndex, calendar: calendar) {
                    return results
                }
                if candidate > threshold {
                    results.append(candidate)
                    if results.count == limit { return results }
                }
                generatedIndex += 1
            }
        }
        return results
    }

    private static func monthlyOccurrences(
        for rule: RoutineAdvancedRecurrenceRule,
        after threshold: Date,
        limit: Int,
        calendar: Calendar
    ) -> [Date] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: rule.startDate))
            ?? calendar.startOfDay(for: rule.startDate)
        let time = rule.timesOfDay.first ?? RoutineTimeOfDay.from(rule.startDate, calendar: calendar)
        var generatedIndex = 0
        var results: [Date] = []

        for periodIndex in 0..<maximumGeneratedOccurrences where results.count < limit {
            guard let periodMonth = calendar.date(
                byAdding: .month,
                value: periodIndex * rule.interval,
                to: monthStart
            ) else { break }
            let periodCandidates = monthlyCandidates(
                in: periodMonth,
                rule: rule,
                time: time,
                calendar: calendar
            )
            for candidate in periodCandidates where candidate >= rule.startDate {
                if shouldStop(rule: rule, candidate: candidate, generatedIndex: generatedIndex, calendar: calendar) {
                    return results
                }
                if candidate > threshold {
                    results.append(candidate)
                    if results.count == limit { return results }
                }
                generatedIndex += 1
            }
        }
        return results
    }

    private static func yearlyOccurrences(
        for rule: RoutineAdvancedRecurrenceRule,
        after threshold: Date,
        limit: Int,
        calendar: Calendar
    ) -> [Date] {
        let startYear = calendar.component(.year, from: rule.startDate)
        let time = rule.timesOfDay.first ?? RoutineTimeOfDay.from(rule.startDate, calendar: calendar)
        var generatedIndex = 0
        var results: [Date] = []

        for periodIndex in 0..<maximumGeneratedOccurrences where results.count < limit {
            let year = startYear + periodIndex * rule.interval
            let periodCandidates = rule.monthsOfYear.flatMap { month -> [Date] in
                rule.monthDays.compactMap { day -> Date? in
                    var components = DateComponents()
                    components.year = year
                    components.month = month
                    components.day = min(day, dayCount(year: year, month: month, calendar: calendar))
                    components.hour = time.hour
                    components.minute = time.minute
                    return calendar.date(from: components)
                }
            }.sorted()
            for candidate in periodCandidates where candidate >= rule.startDate {
                if shouldStop(rule: rule, candidate: candidate, generatedIndex: generatedIndex, calendar: calendar) {
                    return results
                }
                if candidate > threshold {
                    results.append(candidate)
                    if results.count == limit { return results }
                }
                generatedIndex += 1
            }
        }
        return results
    }

    private static func dailyWindowOccurrences(
        for rule: RoutineAdvancedRecurrenceRule,
        after threshold: Date,
        limit: Int,
        calendar: Calendar
    ) -> [Date] {
        let firstDay = calendar.startOfDay(for: rule.startDate)
        var generatedIndex = 0
        var results: [Date] = []

        for dayOffset in 0..<maximumGeneratedOccurrences where results.count < limit {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: firstDay) else { break }
            let windowStart = rule.dailyWindowStart.date(on: day, calendar: calendar)
            var windowEnd = rule.dailyWindowEnd.date(on: day, calendar: calendar)
            if windowEnd <= windowStart {
                windowEnd = calendar.date(byAdding: .day, value: 1, to: windowEnd) ?? windowEnd
            }
            var candidate = windowStart
            while candidate <= windowEnd {
                if candidate >= rule.startDate {
                    if shouldStop(rule: rule, candidate: candidate, generatedIndex: generatedIndex, calendar: calendar) {
                        return results
                    }
                    if candidate > threshold {
                        results.append(candidate)
                        if results.count == limit { return results }
                    }
                    generatedIndex += 1
                }
                guard let next = calendar.date(byAdding: .hour, value: rule.interval, to: candidate),
                      next > candidate else { break }
                candidate = next
            }
        }
        return results
    }

    private static func collect(
        rule: RoutineAdvancedRecurrenceRule,
        after threshold: Date,
        limit: Int,
        calendar: Calendar,
        candidate: (Int) -> Date?
    ) -> [Date] {
        var results: [Date] = []
        for index in 0..<maximumGeneratedOccurrences where results.count < limit {
            guard let value = candidate(index) else { break }
            if shouldStop(rule: rule, candidate: value, generatedIndex: index, calendar: calendar) {
                break
            }
            if value > threshold {
                results.append(value)
            }
        }
        return results
    }

    private static func monthlyCandidates(
        in month: Date,
        rule: RoutineAdvancedRecurrenceRule,
        time: RoutineTimeOfDay,
        calendar: Calendar
    ) -> [Date] {
        if rule.monthlyPattern == .ordinalWeekday {
            return ordinalWeekdayDate(
                in: month,
                weekday: rule.ordinalWeekday,
                ordinal: rule.weekdayOrdinal,
                time: time,
                calendar: calendar
            ).map { [$0] } ?? []
        }

        let components = calendar.dateComponents([.year, .month], from: month)
        let count = calendar.range(of: .day, in: .month, for: month)?.count ?? 31
        return rule.monthDays.compactMap { day -> Date? in
            var candidateComponents = components
            candidateComponents.day = min(day, count)
            candidateComponents.hour = time.hour
            candidateComponents.minute = time.minute
            return calendar.date(from: candidateComponents)
        }.sorted()
    }

    private static func ordinalWeekdayDate(
        in month: Date,
        weekday: Int,
        ordinal: RoutineAdvancedRecurrenceRule.WeekdayOrdinal,
        time: RoutineTimeOfDay,
        calendar: Calendar
    ) -> Date? {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return nil }
        if ordinal == .last {
            guard let lastDay = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) else { return nil }
            let currentWeekday = calendar.component(.weekday, from: lastDay)
            let backwardOffset = (currentWeekday - weekday + 7) % 7
            guard let day = calendar.date(byAdding: .day, value: -backwardOffset, to: lastDay) else { return nil }
            return time.date(on: day, calendar: calendar)
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let forwardOffset = (weekday - firstWeekday + 7) % 7
        let dayOffset = forwardOffset + (ordinal.rawValue - 1) * 7
        guard let day = calendar.date(byAdding: .day, value: dayOffset, to: monthInterval.start),
              calendar.isDate(day, equalTo: month, toGranularity: .month) else {
            return nil
        }
        return time.date(on: day, calendar: calendar)
    }

    private static func candidates(
        on day: Date,
        times: [RoutineTimeOfDay],
        calendar: Calendar
    ) -> [Date] {
        times.map { $0.date(on: day, calendar: calendar) }.sorted()
    }

    private static func dayCount(year: Int, month: Int, calendar: Calendar) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = calendar.date(from: components) else { return 31 }
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 31
    }

    private static func shouldStop(
        rule: RoutineAdvancedRecurrenceRule,
        candidate: Date,
        generatedIndex: Int,
        calendar: Calendar
    ) -> Bool {
        switch rule.endMode {
        case .never:
            return false
        case .onDate:
            let endExclusive = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: rule.endDate)
            ) ?? rule.endDate
            return candidate >= endExclusive
        case .afterCount:
            return generatedIndex >= rule.occurrenceCount
        }
    }
}

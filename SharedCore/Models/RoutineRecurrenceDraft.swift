import Foundation

struct RoutineRecurrenceDraft: Equatable, Sendable {
    enum Cadence: String, CaseIterable, Equatable, Hashable, Sendable {
        case none
        case itemRunout
        case afterCompletion
        case scheduled
    }

    enum Availability: Equatable, Hashable, Sendable {
        case anyTime
        case at(RoutineTimeOfDay)
        case window(RoutineTimeRange)
    }

    enum ValidationIssue: Equatable, Hashable, Sendable {
        case unsupportedAfterCompletionFrequency
        case fixedStartRequired
        case timeZoneRequired
        case structuredAvailabilityUnsupported
    }

    var cadence: Cadence
    var frequency: RoutineAdvancedRecurrenceRule.Frequency
    var interval: Int
    var availability: Availability
    var timeRangeRole: RoutineTimeRangeRole

    var structuredVersion: Int
    var startDate: Date?
    var weekdays: [Int]
    var monthDays: [Int]
    var monthlyPattern: RoutineAdvancedRecurrenceRule.MonthlyPattern
    var weekdayOrdinal: RoutineAdvancedRecurrenceRule.WeekdayOrdinal
    var ordinalWeekday: Int
    var monthsOfYear: [Int]
    var occurrenceTimes: [RoutineTimeOfDay]
    var hourlyMode: RoutineAdvancedRecurrenceRule.HourlyMode
    var dailyWindowStart: RoutineTimeOfDay
    var dailyWindowEnd: RoutineTimeOfDay
    var endMode: RoutineAdvancedRecurrenceRule.EndMode
    var endDate: Date
    var occurrenceCount: Int
    var timeZoneIdentifier: String?

    init(
        cadence: Cadence,
        frequency: RoutineAdvancedRecurrenceRule.Frequency = .daily,
        interval: Int = 1,
        availability: Availability = .anyTime,
        timeRangeRole: RoutineTimeRangeRole = .availability,
        structuredVersion: Int = 1,
        startDate: Date? = nil,
        weekdays: [Int] = [],
        monthDays: [Int] = [],
        monthlyPattern: RoutineAdvancedRecurrenceRule.MonthlyPattern = .dayOfMonth,
        weekdayOrdinal: RoutineAdvancedRecurrenceRule.WeekdayOrdinal = .first,
        ordinalWeekday: Int = 1,
        monthsOfYear: [Int] = [],
        occurrenceTimes: [RoutineTimeOfDay] = [],
        hourlyMode: RoutineAdvancedRecurrenceRule.HourlyMode = .continuous,
        dailyWindowStart: RoutineTimeOfDay = RoutineTimeOfDay(hour: 7, minute: 0),
        dailyWindowEnd: RoutineTimeOfDay = RoutineTimeOfDay(hour: 22, minute: 0),
        endMode: RoutineAdvancedRecurrenceRule.EndMode = .never,
        endDate: Date = Date(timeIntervalSinceReferenceDate: 0),
        occurrenceCount: Int = 10,
        timeZoneIdentifier: String? = nil
    ) {
        self.cadence = cadence
        self.frequency = frequency
        self.interval = max(interval, 1)
        self.availability = availability
        self.timeRangeRole = availability.usesWindow ? timeRangeRole : .availability
        self.structuredVersion = max(structuredVersion, 1)
        self.startDate = startDate
        self.weekdays = Self.sanitized(weekdays, range: 1...7)
        self.monthDays = Self.sanitized(monthDays, range: 1...31)
        self.monthlyPattern = monthlyPattern
        self.weekdayOrdinal = weekdayOrdinal
        self.ordinalWeekday = min(max(ordinalWeekday, 1), 7)
        self.monthsOfYear = Self.sanitized(monthsOfYear, range: 1...12)
        self.occurrenceTimes = Array(Set(occurrenceTimes)).sorted {
            ($0.hour, $0.minute) < ($1.hour, $1.minute)
        }
        self.hourlyMode = hourlyMode
        self.dailyWindowStart = dailyWindowStart
        self.dailyWindowEnd = dailyWindowEnd
        self.endMode = endMode
        self.endDate = endDate
        self.occurrenceCount = max(occurrenceCount, 1)
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    init(
        recurrenceRule: RoutineRecurrenceRule,
        cadence cadenceOverride: Cadence? = nil,
        timeRangeRole: RoutineTimeRangeRole = .availability,
        calendar: Calendar = .current
    ) {
        if let advanced = recurrenceRule.advanced {
            self.init(
                cadence: cadenceOverride ?? .scheduled,
                frequency: advanced.frequency,
                interval: advanced.interval,
                availability: recurrenceRule.timeRange.map(Availability.window) ?? .anyTime,
                timeRangeRole: timeRangeRole,
                structuredVersion: advanced.version,
                startDate: advanced.startDate,
                weekdays: advanced.weekdays,
                monthDays: advanced.monthDays,
                monthlyPattern: advanced.monthlyPattern,
                weekdayOrdinal: advanced.weekdayOrdinal,
                ordinalWeekday: advanced.ordinalWeekday,
                monthsOfYear: advanced.monthsOfYear,
                occurrenceTimes: advanced.timesOfDay,
                hourlyMode: advanced.hourlyMode,
                dailyWindowStart: advanced.dailyWindowStart,
                dailyWindowEnd: advanced.dailyWindowEnd,
                endMode: advanced.endMode,
                endDate: advanced.endDate,
                occurrenceCount: advanced.occurrenceCount,
                timeZoneIdentifier: advanced.timeZoneIdentifier
            )
            return
        }

        let availability: Availability
        if let timeRange = recurrenceRule.timeRange {
            availability = .window(timeRange)
        } else if let timeOfDay = recurrenceRule.timeOfDay {
            availability = .at(timeOfDay)
        } else {
            availability = .anyTime
        }

        let cadence: Cadence
        let frequency: RoutineAdvancedRecurrenceRule.Frequency
        let interval: Int
        let weekdays: [Int]
        let monthDays: [Int]

        switch recurrenceRule.kind {
        case .intervalDays:
            cadence = .afterCompletion
            (frequency, interval) = Self.rollingFrequencyAndInterval(
                forDays: recurrenceRule.interval
            )
            weekdays = []
            monthDays = []

        case .dailyTime:
            cadence = .scheduled
            frequency = .daily
            interval = 1
            weekdays = []
            monthDays = []

        case .weekly:
            cadence = .scheduled
            frequency = .weekly
            interval = 1
            weekdays = recurrenceRule.resolvedWeekdays(calendar: calendar)
            monthDays = []

        case .monthlyDay:
            cadence = .scheduled
            frequency = .monthly
            interval = 1
            weekdays = []
            monthDays = recurrenceRule.resolvedDaysOfMonth(calendar: calendar)
        }

        self.init(
            cadence: cadenceOverride ?? cadence,
            frequency: frequency,
            interval: interval,
            availability: availability,
            timeRangeRole: timeRangeRole,
            weekdays: weekdays,
            monthDays: monthDays
        )
    }

    var validationIssue: ValidationIssue? {
        switch cadence {
        case .none, .itemRunout:
            return nil

        case .afterCompletion:
            switch frequency {
            case .daily, .weekly, .monthly:
                return nil
            case .hourly, .yearly:
                return .unsupportedAfterCompletionFrequency
            }

        case .scheduled:
            if canUseCompactScheduledRule {
                return nil
            }
            guard startDate != nil else {
                return .fixedStartRequired
            }
            guard timeZoneIdentifier != nil else {
                return .timeZoneRequired
            }
            guard availability == .anyTime else {
                return .structuredAvailabilityUnsupported
            }
            return nil
        }
    }

    func resolvedRecurrenceRule(calendar: Calendar = .current) -> RoutineRecurrenceRule? {
        guard validationIssue == nil else { return nil }

        switch cadence {
        case .none:
            return .interval(days: 1)

        case .itemRunout:
            return .interval(days: rollingIntervalDays)

        case .afterCompletion:
            return .interval(
                days: rollingIntervalDays,
                at: availability.timeOfDay,
                timeRange: availability.timeRange
            )

        case .scheduled:
            if canUseCompactScheduledRule {
                return compactScheduledRule
            }

            guard let startDate,
                  let timeZoneIdentifier
            else { return nil }

            let advanced = RoutineAdvancedRecurrenceRule(
                version: structuredVersion,
                frequency: frequency,
                interval: interval,
                startDate: startDate,
                weekdays: weekdays,
                monthDays: monthDays,
                monthlyPattern: monthlyPattern,
                weekdayOrdinal: weekdayOrdinal,
                ordinalWeekday: ordinalWeekday,
                monthsOfYear: monthsOfYear,
                timesOfDay: occurrenceTimes,
                hourlyMode: hourlyMode,
                dailyWindowStart: dailyWindowStart,
                dailyWindowEnd: dailyWindowEnd,
                endMode: endMode,
                endDate: endDate,
                occurrenceCount: occurrenceCount,
                timeZoneIdentifier: timeZoneIdentifier,
                calendar: calendar
            )
            return .advanced(advanced)
        }
    }

    func replacingAvailability(
        _ availability: Availability,
        timeRangeRole: RoutineTimeRangeRole
    ) -> Self {
        var updated = self
        updated.availability = availability
        updated.timeRangeRole = availability.usesWindow ? timeRangeRole : .availability
        return updated
    }

    private var canUseCompactScheduledRule: Bool {
        guard startDate == nil,
              interval == 1,
              occurrenceTimes.isEmpty,
              endMode == .never,
              timeZoneIdentifier == nil
        else { return false }

        switch frequency {
        case .daily, .weekly:
            return true
        case .monthly:
            return monthlyPattern == .dayOfMonth
        case .hourly, .yearly:
            return false
        }
    }

    private var compactScheduledRule: RoutineRecurrenceRule? {
        switch frequency {
        case .daily:
            if let timeRange = availability.timeRange {
                return .daily(in: timeRange)
            }
            return RoutineRecurrenceRule(kind: .dailyTime, timeOfDay: availability.timeOfDay)

        case .weekly:
            return .weekly(
                on: weekdays,
                at: availability.timeOfDay,
                timeRange: availability.timeRange
            )

        case .monthly:
            return .monthly(
                on: monthDays,
                at: availability.timeOfDay,
                timeRange: availability.timeRange
            )

        case .hourly, .yearly:
            return nil
        }
    }

    private var rollingIntervalDays: Int {
        let multiplier: Int
        switch frequency {
        case .daily:
            multiplier = 1
        case .weekly:
            multiplier = 7
        case .monthly:
            multiplier = 30
        case .hourly, .yearly:
            multiplier = 1
        }
        return max(interval * multiplier, 1)
    }

    private static func rollingFrequencyAndInterval(
        forDays inputDays: Int
    ) -> (RoutineAdvancedRecurrenceRule.Frequency, Int) {
        let days = max(inputDays, 1)
        if days % 30 == 0 {
            return (.monthly, max(days / 30, 1))
        }
        if days % 7 == 0 {
            return (.weekly, max(days / 7, 1))
        }
        return (.daily, days)
    }

    private static func sanitized(
        _ values: [Int],
        range: ClosedRange<Int>
    ) -> [Int] {
        Array(Set(values.map { min(max($0, range.lowerBound), range.upperBound) })).sorted()
    }
}

private extension RoutineRecurrenceDraft.Availability {
    var usesWindow: Bool {
        if case .window = self {
            return true
        }
        return false
    }

    var timeOfDay: RoutineTimeOfDay? {
        if case let .at(timeOfDay) = self {
            return timeOfDay
        }
        return nil
    }

    var timeRange: RoutineTimeRange? {
        if case let .window(timeRange) = self {
            return timeRange
        }
        return nil
    }
}

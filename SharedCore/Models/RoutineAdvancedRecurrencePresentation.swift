import Foundation

enum RoutineRecurrenceEditorMode: String, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
    case simple = "Simple"
    case advanced = "Advanced"

    var id: String { rawValue }
}

extension RoutineAdvancedRecurrenceRule {
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

    func summary(
        calendar: Calendar = .current,
        availabilityWindow: RoutineTimeRange? = nil
    ) -> String {
        let normalized = normalized(calendar: calendar)
        let cadence: String
        switch normalized.frequency {
        case .hourly:
            cadence =
                normalized.hourlyMode == .continuous
                ? "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval)) continuously"
                : "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval)) from \(normalized.dailyWindowStart.formatted(calendar: calendar)) to \(normalized.dailyWindowEnd.formatted(calendar: calendar)) each day"
        case .daily:
            if availabilityWindow == nil {
                cadence =
                    "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval)) at \(Self.timeList(normalized.timesOfDay, calendar: calendar))"
            } else {
                cadence = "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval))"
            }
        case .weekly:
            cadence =
                "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval)) on \(Self.weekdayList(normalized.weekdays, calendar: calendar))"
        case .monthly:
            if normalized.monthlyPattern == .ordinalWeekday {
                cadence =
                    "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval)) on the \(normalized.weekdayOrdinal.title.lowercased()) \(Self.weekdayName(normalized.ordinalWeekday, calendar: calendar))"
            } else {
                cadence =
                    "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval)) on \(Self.monthDayList(normalized.monthDays))"
            }
        case .yearly:
            cadence =
                "Every \(normalized.interval) \(normalized.frequency.unitName(for: normalized.interval)) on \(Self.yearlyDateList(months: normalized.monthsOfYear, days: normalized.monthDays, calendar: calendar))"
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
        let availabilityText =
            availabilityWindow.map {
                ", available from \($0.formatted(calendar: calendar))"
            } ?? ""
        return "\(cadence)\(availabilityText), starting \(startText)\(endText)."
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

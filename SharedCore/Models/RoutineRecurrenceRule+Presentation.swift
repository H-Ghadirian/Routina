import Foundation

extension RoutineRecurrenceRule {
    func displayText(calendar: Calendar = .current) -> String {
        if let advanced {
            return advanced.summary(
                calendar: calendar,
                availabilityWindow: timeRange
            )
        }
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

import Foundation

extension RoutinaQuickAddParser {
    struct ParsedAbsoluteDate {
        var date: Date
        var isDeadline: Bool
    }

    static func extractAbsoluteDate(
        from working: inout String,
        timeOfDay: RoutineTimeOfDay?,
        referenceDate: Date,
        calendar: Calendar
    ) -> ParsedAbsoluteDate? {
        var candidateWorking = working
        let pattern =
            #"(?:^|\s)(?:(due|by|on)\s+)?(?:(monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|"#
            + #"saturday|sat|sunday|sun)\s*,?\s+)?(\d{1,2})(?:st|nd|rd|th)?\s+"#
            + #"(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|"#
            + #"september|sep|sept|october|oct|november|nov|december|dec)(?:\s*,?\s*(\d{4}))?(?=\s|$)"#
        guard
            let match = removeFirstMatch(
                pattern: pattern,
                from: &candidateWorking
            ),
            let day = Int(match.groups[2]),
            let month = monthNumber(for: match.groups[3])
        else {
            return nil
        }

        let expectedWeekday =
            match.groups[1].isEmpty
            ? nil
            : weekdayNumber(for: match.groups[1])
        let explicitYear = Int(match.groups[4])
        guard
            let resolvedDay = resolvedAbsoluteDay(
                day: day,
                month: month,
                explicitYear: explicitYear,
                expectedWeekday: expectedWeekday,
                referenceDate: referenceDate,
                calendar: calendar
            )
        else {
            return nil
        }

        working = candidateWorking
        return ParsedAbsoluteDate(
            date: date(on: resolvedDay, timeOfDay: timeOfDay, calendar: calendar),
            isDeadline: ["due", "by"].contains(match.groups[0].lowercased())
        )
    }

    static func oneOffSchedule(
        on day: Date,
        timeOfDay: RoutineTimeOfDay?,
        isDeadline: Bool,
        calendar: Calendar
    ) -> ParsedSchedule {
        if isDeadline {
            return ParsedSchedule(
                deadline: date(on: day, timeOfDay: timeOfDay, calendar: calendar)
            )
        }

        return ParsedSchedule(
            recurrenceRule: .interval(days: 1, at: timeOfDay),
            availabilityStartDate: calendar.startOfDay(for: day)
        )
    }

    private static func resolvedAbsoluteDay(
        day: Int,
        month: Int,
        explicitYear: Int?,
        expectedWeekday: Int?,
        referenceDate: Date,
        calendar: Calendar
    ) -> Date? {
        if let explicitYear {
            guard
                let candidate = validDate(
                    year: explicitYear,
                    month: month,
                    day: day,
                    calendar: calendar
                ), matches(expectedWeekday: expectedWeekday, date: candidate, calendar: calendar)
            else {
                return nil
            }
            return candidate
        }

        let referenceDay = calendar.startOfDay(for: referenceDate)
        let referenceYear = calendar.component(.year, from: referenceDay)
        for year in referenceYear...(referenceYear + 14) {
            guard
                let candidate = validDate(
                    year: year,
                    month: month,
                    day: day,
                    calendar: calendar
                ), candidate >= referenceDay
            else {
                continue
            }
            guard matches(expectedWeekday: expectedWeekday, date: candidate, calendar: calendar) else {
                continue
            }
            return candidate
        }
        return nil
    }

    private static func validDate(
        year: Int,
        month: Int,
        day: Int,
        calendar: Calendar
    ) -> Date? {
        let components = DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day
        )
        guard let candidate = calendar.date(from: components) else { return nil }
        let resolved = calendar.dateComponents([.year, .month, .day], from: candidate)
        guard resolved.year == year, resolved.month == month, resolved.day == day else {
            return nil
        }
        return calendar.startOfDay(for: candidate)
    }

    private static func matches(
        expectedWeekday: Int?,
        date: Date,
        calendar: Calendar
    ) -> Bool {
        guard let expectedWeekday else { return true }
        return calendar.component(.weekday, from: date) == expectedWeekday
    }

    private static func monthNumber(for value: String) -> Int? {
        switch value.lowercased() {
        case "january", "jan": return 1
        case "february", "feb": return 2
        case "march", "mar": return 3
        case "april", "apr": return 4
        case "may": return 5
        case "june", "jun": return 6
        case "july", "jul": return 7
        case "august", "aug": return 8
        case "september", "sep", "sept": return 9
        case "october", "oct": return 10
        case "november", "nov": return 11
        case "december", "dec": return 12
        default: return nil
        }
    }

    static func nextDate(
        matchingWeekday weekday: Int,
        after referenceDate: Date,
        calendar: Calendar
    ) -> Date {
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let referenceWeekday = calendar.component(.weekday, from: referenceDay)
        let rawDelta = weekday - referenceWeekday
        let delta = rawDelta >= 0 ? rawDelta : rawDelta + 7
        return calendar.date(byAdding: .day, value: delta, to: referenceDay) ?? referenceDay
    }

    static func date(
        on day: Date,
        timeOfDay: RoutineTimeOfDay?,
        calendar: Calendar
    ) -> Date {
        let start = calendar.startOfDay(for: day)
        return timeOfDay?.date(on: start, calendar: calendar) ?? start
    }
}

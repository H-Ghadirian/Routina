import Foundation

extension RoutinaQuickAddParser {
    struct ParsedSchedule {
        var scheduleMode: RoutineScheduleMode = .oneOff
        var frequencyInDays: Int = 1
        var recurrenceRule: RoutineRecurrenceRule = .interval(days: 1)
        var availabilityStartDate: Date?
        var availabilityEndDate: Date?
        var deadline: Date?
        var reminderAt: Date?
    }

    private static let weekdayPattern =
        "monday|mon|tuesday|tue|wednesday|wed|thursday|thu|"
        + "friday|fri|saturday|sat|sunday|sun"

    private static let ordinalMonthlyPattern =
        "(?:^|\\s)every\\s+(\\d{1,3})\\s+months?\\s+on\\s+(?:the\\s+)?"
        + "(first|second|third|fourth|last)\\s+"
        + "(\(weekdayPattern))(?=\\s|$)"

    private static let intervalWeeklyPattern =
        "(?:^|\\s)every\\s+(\\d{1,3})\\s+weeks?\\s+on\\s+"
        + "(\(weekdayPattern))(?=\\s|$)"

    private static let alternateWeekdayPattern =
        "(?:^|\\s)every\\s+(other|\\d{1,3})\\s+"
        + "(\(weekdayPattern))(?=\\s|$)"

    private static let fixedWeeklyPattern =
        "(?:^|\\s)(?:every\\s+|weekly\\s+on\\s+)"
        + "(\(weekdayPattern))(?=\\s|$)"

    private static let dueWeekdayPattern =
        "(?:^|\\s)(?:due\\s+|by\\s+)"
        + "(\(weekdayPattern))(?=\\s|$)"

    static func extractSchedule(
        from working: inout String,
        timeOfDay: RoutineTimeOfDay?,
        referenceDate: Date,
        calendar: Calendar
    ) -> ParsedSchedule {
        let isSoft =
            removeFirstMatch(
                pattern: "(?:^|\\s)soft(?:ly)?(?=\\s|$)",
                from: &working
            ) != nil

        if let schedule = extractOrdinalMonthlySchedule(
            from: &working,
            timeOfDay: timeOfDay,
            isSoft: isSoft,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            return schedule
        }
        if let schedule = extractAdvancedWeeklySchedule(
            from: &working,
            timeOfDay: timeOfDay,
            isSoft: isSoft,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            return schedule
        }
        if let schedule = extractHourlySchedule(
            from: &working,
            timeOfDay: timeOfDay,
            isSoft: isSoft,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            return schedule
        }
        if let schedule = extractSimpleRecurringSchedule(
            from: &working,
            timeOfDay: timeOfDay,
            isSoft: isSoft
        ) {
            return schedule
        }
        return extractOneOffSchedule(
            from: &working,
            timeOfDay: timeOfDay,
            referenceDate: referenceDate,
            calendar: calendar
        ) ?? ParsedSchedule()
    }

    private static func extractOrdinalMonthlySchedule(
        from working: inout String,
        timeOfDay: RoutineTimeOfDay?,
        isSoft: Bool,
        referenceDate: Date,
        calendar: Calendar
    ) -> ParsedSchedule? {
        guard
            let match = removeFirstMatch(pattern: ordinalMonthlyPattern, from: &working),
            let value = Int(match.groups[0]),
            let ordinal = weekdayOrdinal(for: match.groups[1]),
            let weekday = weekdayNumber(for: match.groups[2])
        else {
            return nil
        }

        let start = date(
            on: referenceDate,
            timeOfDay: timeOfDay ?? RoutineTimeOfDay.from(referenceDate, calendar: calendar),
            calendar: calendar
        )
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .monthly,
            interval: value,
            startDate: start,
            monthlyPattern: .ordinalWeekday,
            weekdayOrdinal: ordinal,
            ordinalWeekday: weekday,
            timeZoneIdentifier: calendar.timeZone.identifier,
            calendar: calendar
        )
        return ParsedSchedule(
            scheduleMode: isSoft ? .softInterval : .fixedInterval,
            frequencyInDays: advanced.approximateIntervalDays,
            recurrenceRule: .advanced(advanced)
        )
    }

    private static func extractAdvancedWeeklySchedule(
        from working: inout String,
        timeOfDay: RoutineTimeOfDay?,
        isSoft: Bool,
        referenceDate: Date,
        calendar: Calendar
    ) -> ParsedSchedule? {
        if let match = removeFirstMatch(pattern: intervalWeeklyPattern, from: &working),
            let value = Int(match.groups[0]),
            let weekday = weekdayNumber(for: match.groups[1])
        {
            return advancedWeeklySchedule(
                interval: value,
                weekday: weekday,
                timeOfDay: timeOfDay,
                isSoft: isSoft,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }

        guard
            let match = removeFirstMatch(pattern: alternateWeekdayPattern, from: &working),
            let weekday = weekdayNumber(for: match.groups[1])
        else {
            return nil
        }
        let interval =
            match.groups[0].lowercased() == "other"
            ? 2
            : (Int(match.groups[0]) ?? 1)
        return advancedWeeklySchedule(
            interval: interval,
            weekday: weekday,
            timeOfDay: timeOfDay,
            isSoft: isSoft,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    private static func extractHourlySchedule(
        from working: inout String,
        timeOfDay: RoutineTimeOfDay?,
        isSoft: Bool,
        referenceDate: Date,
        calendar: Calendar
    ) -> ParsedSchedule? {
        guard
            let match = removeFirstMatch(
                pattern: "(?:^|\\s)every\\s+(\\d{1,3})\\s+hours?(\\s+(?:in|during)\\s+(?:the\\s+)?day)?(?=\\s|$)",
                from: &working
            ),
            let value = Int(match.groups[0])
        else {
            return nil
        }

        let start = date(
            on: referenceDate,
            timeOfDay: timeOfDay ?? RoutineTimeOfDay.from(referenceDate, calendar: calendar),
            calendar: calendar
        )
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .hourly,
            interval: value,
            startDate: start,
            hourlyMode: match.groups[1].isEmpty ? .continuous : .dailyWindow,
            timeZoneIdentifier: calendar.timeZone.identifier,
            calendar: calendar
        )
        return ParsedSchedule(
            scheduleMode: isSoft ? .softInterval : .fixedInterval,
            frequencyInDays: 1,
            recurrenceRule: .advanced(advanced)
        )
    }

    private static func extractSimpleRecurringSchedule(
        from working: inout String,
        timeOfDay: RoutineTimeOfDay?,
        isSoft: Bool
    ) -> ParsedSchedule? {
        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)every\\s+(\\d{1,3})\\s+(day|days|week|weeks|month|months)(?=\\s|$)",
            from: &working
        ), let value = Int(match.groups[0]) {
            let unit = match.groups[1].lowercased()
            let days =
                unit.hasPrefix("week")
                ? value * 7
                : (unit.hasPrefix("month") ? value * 30 : value)
            return ParsedSchedule(
                scheduleMode: isSoft ? .softInterval : .fixedInterval,
                frequencyInDays: max(days, 1),
                recurrenceRule: .interval(days: max(days, 1))
            )
        }

        if removeFirstMatch(
            pattern: "(?:^|\\s)(every\\s+day|daily)(?=\\s|$)",
            from: &working
        ) != nil {
            let recurrenceRule =
                timeOfDay.map(RoutineRecurrenceRule.daily(at:))
                ?? .interval(days: 1)
            return ParsedSchedule(
                scheduleMode: isSoft ? .softInterval : .fixedInterval,
                frequencyInDays: 1,
                recurrenceRule: recurrenceRule
            )
        }

        if let match = removeFirstMatch(pattern: fixedWeeklyPattern, from: &working),
            let weekday = weekdayNumber(for: match.groups[0])
        {
            return ParsedSchedule(
                scheduleMode: isSoft ? .softInterval : .fixedInterval,
                frequencyInDays: 7,
                recurrenceRule: .weekly(on: weekday, at: timeOfDay)
            )
        }

        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)(?:monthly\\s+on\\s+|every\\s+month\\s+on\\s+)(\\d{1,2})(?:st|nd|rd|th)?(?=\\s|$)",
            from: &working
        ), let day = Int(match.groups[0]) {
            return ParsedSchedule(
                scheduleMode: isSoft ? .softInterval : .fixedInterval,
                frequencyInDays: 30,
                recurrenceRule: .monthly(on: day, at: timeOfDay)
            )
        }

        return nil
    }

    private static func extractOneOffSchedule(
        from working: inout String,
        timeOfDay: RoutineTimeOfDay?,
        referenceDate: Date,
        calendar: Calendar
    ) -> ParsedSchedule? {
        if let absoluteDate = extractAbsoluteDate(
            from: &working,
            timeOfDay: timeOfDay,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            return oneOffSchedule(
                on: absoluteDate.date,
                timeOfDay: timeOfDay,
                isDeadline: absoluteDate.isDeadline,
                calendar: calendar
            )
        }

        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)(?:(due|by)\\s+)?today(?=\\s|$)",
            from: &working
        ) {
            return oneOffSchedule(
                on: referenceDate,
                timeOfDay: timeOfDay,
                isDeadline: !match.groups[0].isEmpty,
                calendar: calendar
            )
        }

        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)(?:(due|by)\\s+)?tomorrow(?=\\s|$)",
            from: &working
        ) {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
            return oneOffSchedule(
                on: tomorrow,
                timeOfDay: timeOfDay,
                isDeadline: !match.groups[0].isEmpty,
                calendar: calendar
            )
        }

        guard
            let match = removeFirstMatch(pattern: dueWeekdayPattern, from: &working),
            let weekday = weekdayNumber(for: match.groups[0])
        else {
            return nil
        }
        let dueDate = nextDate(
            matchingWeekday: weekday,
            after: referenceDate,
            calendar: calendar
        )
        return ParsedSchedule(
            deadline: date(on: dueDate, timeOfDay: timeOfDay, calendar: calendar)
        )
    }

    static func weekdayNumber(for value: String) -> Int? {
        switch value.lowercased() {
        case "sunday", "sun": return 1
        case "monday", "mon": return 2
        case "tuesday", "tue": return 3
        case "wednesday", "wed": return 4
        case "thursday", "thu": return 5
        case "friday", "fri": return 6
        case "saturday", "sat": return 7
        default: return nil
        }
    }

    private static func weekdayOrdinal(
        for value: String
    ) -> RoutineAdvancedRecurrenceRule.WeekdayOrdinal? {
        switch value.lowercased() {
        case "first": return .first
        case "second": return .second
        case "third": return .third
        case "fourth": return .fourth
        case "last": return .last
        default: return nil
        }
    }

    private static func advancedWeeklySchedule(
        interval: Int,
        weekday: Int,
        timeOfDay: RoutineTimeOfDay?,
        isSoft: Bool,
        referenceDate: Date,
        calendar: Calendar
    ) -> ParsedSchedule {
        let start = date(
            on: referenceDate,
            timeOfDay: timeOfDay ?? RoutineTimeOfDay.from(referenceDate, calendar: calendar),
            calendar: calendar
        )
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .weekly,
            interval: interval,
            startDate: start,
            weekdays: [weekday],
            timeZoneIdentifier: calendar.timeZone.identifier,
            calendar: calendar
        )
        return ParsedSchedule(
            scheduleMode: isSoft ? .softInterval : .fixedInterval,
            frequencyInDays: advanced.approximateIntervalDays,
            recurrenceRule: .advanced(advanced)
        )
    }
}

import Foundation

struct RoutinaQuickAddDraft: Equatable, Sendable {
    var name: String
    var scheduleMode: RoutineScheduleMode
    var frequencyInDays: Int
    var recurrenceRule: RoutineRecurrenceRule
    var availabilityStartDate: Date?
    var availabilityEndDate: Date?
    var deadline: Date?
    var reminderAt: Date?
    var tags: [String]
    var placeName: String?
    var importance: RoutineTaskImportance
    var urgency: RoutineTaskUrgency
    var hasExplicitPriority: Bool
    var estimatedDurationMinutes: Int?
    var focusModeEnabled: Bool

    var scheduleSummaryText: String {
        scheduleSummary
    }

    var hasDetectedMetadata: Bool {
        hasDetectedSchedule
            || !tags.isEmpty
            || placeName != nil
            || hasExplicitPriority
            || estimatedDurationMinutes != nil
    }

    var hasDetectedSchedule: Bool {
        scheduleMode != .oneOff
            || availabilityStartDate != nil
            || availabilityEndDate != nil
            || deadline != nil
            || reminderAt != nil
    }

    var summaryText: String {
        var parts: [String] = []
        parts.append(scheduleSummary)

        if !tags.isEmpty {
            parts.append(tags.map { "#\($0)" }.joined(separator: " "))
        }

        if let placeName {
            parts.append("@\(placeName)")
        }

        if let estimatedDurationMinutes {
            parts.append("\(estimatedDurationMinutes)m")
        }

        return parts.joined(separator: " · ")
    }

    private var scheduleSummary: String {
        switch scheduleMode {
        case .oneOff:
            if let availabilityDate = exactAvailabilityDate() {
                return "Todo at \(availabilityDate.formatted(date: .abbreviated, time: .shortened))"
            }
            if let availabilityStartDate {
                return "Todo on \(availabilityStartDate.formatted(date: .abbreviated, time: .omitted))"
            }
            if let deadline {
                return "Todo due \(deadline.formatted(date: .abbreviated, time: .shortened))"
            }
            return "Todo"
        case .softInterval, .softIntervalChecklist, .softDerivedFromChecklist:
            return "Gentle routine · \(recurrenceRule.displayText())"
        case .fixedInterval, .fixedIntervalChecklist, .derivedFromChecklist:
            return "Routine · \(recurrenceRule.displayText())"
        case .record:
            return "Gentle routine"
        case .recordChecklist:
            return "Gentle routine · Checklist"
        case .recordDerivedFromChecklist:
            return "Gentle routine · Item runout"
        }
    }

    func exactAvailabilityDate(calendar: Calendar = .current) -> Date? {
        guard scheduleMode == .oneOff,
              let availabilityStartDate,
              availabilityEndDate == nil,
              let timeOfDay = recurrenceRule.timeOfDay else {
            return nil
        }
        return timeOfDay.date(on: availabilityStartDate, calendar: calendar)
    }

    func saveRequest(placeID: UUID?, calendar: Calendar = .current) -> AddRoutineSaveRequest {
        AddRoutineSaveRequest(
            name: name,
            frequencyInDays: frequencyInDays,
            recurrenceRule: recurrenceRule,
            emoji: "✨",
            deadline: deadline,
            availabilityStartDate: availabilityStartDate,
            availabilityEndDate: availabilityEndDate,
            calendar: calendar,
            reminderAt: reminderAt,
            priority: hasExplicitPriority
                ? AddRoutinePriorityMatrix.priority(importance: importance, urgency: urgency)
                : .none,
            importance: importance,
            urgency: urgency,
            selectedPlaceID: placeID,
            tags: tags,
            scheduleMode: scheduleMode,
            color: .none,
            estimatedDurationMinutes: estimatedDurationMinutes,
            focusModeEnabled: focusModeEnabled
        )
    }
}

enum RoutinaQuickAddParser {
    static func parse(
        _ input: String,
        referenceDate: Date = .now,
        calendar: Calendar = .current,
        includingPlaces: Bool = true
    ) -> RoutinaQuickAddDraft? {
        var working = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !working.isEmpty else { return nil }

        let tags = extractTokens(
            pattern: "(?:^|\\s)#([^\\s#@!]+)",
            from: &working
        ).compactMap(RoutineTag.cleaned)

        let placeName = includingPlaces
            ? extractTokens(
                pattern: "(?:^|\\s)@([^\\s#@!]+)",
                from: &working
            ).first.flatMap(RoutinePlace.cleanedName)
            : nil

        let priority = extractPriority(from: &working)
        let timeOfDay = extractTimeOfDay(from: &working)
        let schedule = extractSchedule(
            from: &working,
            timeOfDay: timeOfDay,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let durationMinutes = extractDurationMinutes(from: &working)

        let name = cleanedName(from: working)
        guard !name.isEmpty else { return nil }

        return RoutinaQuickAddDraft(
            name: name,
            scheduleMode: schedule.scheduleMode,
            frequencyInDays: schedule.frequencyInDays,
            recurrenceRule: schedule.recurrenceRule,
            availabilityStartDate: schedule.availabilityStartDate,
            availabilityEndDate: schedule.availabilityEndDate,
            deadline: schedule.deadline,
            reminderAt: schedule.reminderAt,
            tags: tags,
            placeName: placeName,
            importance: priority.importance,
            urgency: priority.urgency,
            hasExplicitPriority: priority.wasExplicitlySet,
            estimatedDurationMinutes: durationMinutes,
            focusModeEnabled: durationMinutes != nil
        )
    }

    private struct ParsedSchedule {
        var scheduleMode: RoutineScheduleMode = .oneOff
        var frequencyInDays: Int = 1
        var recurrenceRule: RoutineRecurrenceRule = .interval(days: 1)
        var availabilityStartDate: Date?
        var availabilityEndDate: Date?
        var deadline: Date?
        var reminderAt: Date?
    }

    private static func extractSchedule(
        from working: inout String,
        timeOfDay: RoutineTimeOfDay?,
        referenceDate: Date,
        calendar: Calendar
    ) -> ParsedSchedule {
        let isSoft = removeFirstMatch(
            pattern: "(?:^|\\s)soft(?:ly)?(?=\\s|$)",
            from: &working
        ) != nil

        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)every\\s+(\\d{1,3})\\s+months?\\s+on\\s+(?:the\\s+)?(first|second|third|fourth|last)\\s+(monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)(?=\\s|$)",
            from: &working
        ), let value = Int(match.groups[0]),
           let ordinal = weekdayOrdinal(for: match.groups[1]),
           let weekday = weekdayNumber(for: match.groups[2]) {
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

        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)every\\s+(\\d{1,3})\\s+weeks?\\s+on\\s+(monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)(?=\\s|$)",
            from: &working
        ), let value = Int(match.groups[0]),
           let weekday = weekdayNumber(for: match.groups[1]) {
            return advancedWeeklySchedule(
                interval: value,
                weekday: weekday,
                timeOfDay: timeOfDay,
                isSoft: isSoft,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }

        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)every\\s+(other|\\d{1,3})\\s+(monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)(?=\\s|$)",
            from: &working
        ), let weekday = weekdayNumber(for: match.groups[1]) {
            let value = match.groups[0].lowercased() == "other"
                ? 2
                : (Int(match.groups[0]) ?? 1)
            return advancedWeeklySchedule(
                interval: value,
                weekday: weekday,
                timeOfDay: timeOfDay,
                isSoft: isSoft,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }

        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)every\\s+(\\d{1,3})\\s+hours?(\\s+(?:in|during)\\s+(?:the\\s+)?day)?(?=\\s|$)",
            from: &working
        ), let value = Int(match.groups[0]) {
            let start = date(
                on: referenceDate,
                timeOfDay: timeOfDay ?? RoutineTimeOfDay.from(referenceDate, calendar: calendar),
                calendar: calendar
            )
            let usesDailyWindow = !match.groups[1].isEmpty
            let advanced = RoutineAdvancedRecurrenceRule(
                frequency: .hourly,
                interval: value,
                startDate: start,
                hourlyMode: usesDailyWindow ? .dailyWindow : .continuous,
                timeZoneIdentifier: calendar.timeZone.identifier,
                calendar: calendar
            )
            return ParsedSchedule(
                scheduleMode: isSoft ? .softInterval : .fixedInterval,
                frequencyInDays: 1,
                recurrenceRule: .advanced(advanced)
            )
        }

        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)every\\s+(\\d{1,3})\\s+(day|days|week|weeks|month|months)(?=\\s|$)",
            from: &working
        ), let value = Int(match.groups[0]) {
            let unit = match.groups[1].lowercased()
            let days: Int
            if unit.hasPrefix("week") {
                days = value * 7
            } else if unit.hasPrefix("month") {
                days = value * 30
            } else {
                days = value
            }
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
            let recurrenceRule: RoutineRecurrenceRule = timeOfDay.map(RoutineRecurrenceRule.daily(at:)) ?? .interval(days: 1)
            return ParsedSchedule(
                scheduleMode: isSoft ? .softInterval : .fixedInterval,
                frequencyInDays: 1,
                recurrenceRule: recurrenceRule
            )
        }

        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)(?:every\\s+|weekly\\s+on\\s+)(monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)(?=\\s|$)",
            from: &working
        ), let weekday = weekdayNumber(for: match.groups[0]) {
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

        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)(?:due\\s+|by\\s+)(monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)(?=\\s|$)",
            from: &working
        ), let weekday = weekdayNumber(for: match.groups[0]) {
            let dueDate = nextDate(
                matchingWeekday: weekday,
                after: referenceDate,
                calendar: calendar
            )
            let deadline = date(on: dueDate, timeOfDay: timeOfDay, calendar: calendar)
            return ParsedSchedule(deadline: deadline)
        }

        return ParsedSchedule()
    }

    private struct ParsedAbsoluteDate {
        var date: Date
        var isDeadline: Bool
    }

    private static func extractAbsoluteDate(
        from working: inout String,
        timeOfDay: RoutineTimeOfDay?,
        referenceDate: Date,
        calendar: Calendar
    ) -> ParsedAbsoluteDate? {
        var candidateWorking = working
        guard let match = removeFirstMatch(
            pattern: #"(?:^|\s)(?:(due|by|on)\s+)?(?:(monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)\s*,?\s+)?(\d{1,2})(?:st|nd|rd|th)?\s+(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|sept|october|oct|november|nov|december|dec)(?:\s*,?\s*(\d{4}))?(?=\s|$)"#,
            from: &candidateWorking
        ),
        let day = Int(match.groups[2]),
        let month = monthNumber(for: match.groups[3])
        else {
            return nil
        }

        let expectedWeekday = match.groups[1].isEmpty
            ? nil
            : weekdayNumber(for: match.groups[1])
        let explicitYear = Int(match.groups[4])
        guard let resolvedDay = resolvedAbsoluteDay(
            day: day,
            month: month,
            explicitYear: explicitYear,
            expectedWeekday: expectedWeekday,
            referenceDate: referenceDate,
            calendar: calendar
        ) else {
            return nil
        }

        working = candidateWorking
        return ParsedAbsoluteDate(
            date: date(on: resolvedDay, timeOfDay: timeOfDay, calendar: calendar),
            isDeadline: ["due", "by"].contains(match.groups[0].lowercased())
        )
    }

    private static func oneOffSchedule(
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
            guard let candidate = validDate(
                year: explicitYear,
                month: month,
                day: day,
                calendar: calendar
            ), matches(expectedWeekday: expectedWeekday, date: candidate, calendar: calendar) else {
                return nil
            }
            return candidate
        }

        let referenceDay = calendar.startOfDay(for: referenceDate)
        let referenceYear = calendar.component(.year, from: referenceDay)
        for year in referenceYear...(referenceYear + 14) {
            guard let candidate = validDate(
                year: year,
                month: month,
                day: day,
                calendar: calendar
            ), candidate >= referenceDay else {
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

    private static func extractPriority(
        from working: inout String
    ) -> (
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        wasExplicitlySet: Bool
    ) {
        guard let match = removeFirstMatch(
            pattern: "(?:^|\\s)!(urgent|high|medium|low)(?=\\s|$)",
            from: &working
        ) else {
            return (.level2, .level2, false)
        }

        switch match.groups[0].lowercased() {
        case "urgent":
            return (.level4, .level4, true)
        case "high":
            return (.level3, .level3, true)
        case "low":
            return (.level1, .level1, true)
        default:
            return (.level2, .level2, true)
        }
    }

    private static func extractDurationMinutes(from working: inout String) -> Int? {
        guard let match = removeFirstMatch(
            pattern: "(?:^|\\s)(?:for\\s+)?(\\d{1,3})\\s*(m|min|mins|minute|minutes|h|hr|hrs|hour|hours)(?=\\s|$)",
            from: &working
        ), let value = Int(match.groups[0]) else {
            return nil
        }

        let unit = match.groups[1].lowercased()
        if unit.hasPrefix("h") {
            return min(max(value * 60, 1), 720)
        }
        return min(max(value, 1), 720)
    }

    private static func extractTimeOfDay(from working: inout String) -> RoutineTimeOfDay? {
        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)(morning|noon|afternoon|evening|night|tonight)(?=\\s|$)",
            from: &working
        ) {
            return partOfDayTime(match.groups[0])
        }

        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)(?:at\\s+)?(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)(?=\\s|$)",
            from: &working
        ), let rawHour = Int(match.groups[0]) {
            let minute = Int(match.groups[1]) ?? 0
            let marker = match.groups[2].lowercased()
            var hour = rawHour % 12
            if marker == "pm" {
                hour += 12
            }
            return RoutineTimeOfDay(hour: hour, minute: minute)
        }

        var candidateWorking = working
        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)(?:at\\s+)?(\\d{1,2}):(\\d{2})(?=\\s|$)",
            from: &candidateWorking
        ), let hour = Int(match.groups[0]), let minute = Int(match.groups[1]),
           (0...23).contains(hour), (0...59).contains(minute) {
            working = candidateWorking
            return RoutineTimeOfDay(hour: hour, minute: minute)
        }

        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)at\\s+(\\d{1,2})(?=\\s|$)",
            from: &working
        ), let hour = Int(match.groups[0]) {
            return RoutineTimeOfDay(hour: hour, minute: 0)
        }

        return nil
    }

    private static func partOfDayTime(_ value: String) -> RoutineTimeOfDay? {
        switch value.lowercased() {
        case "morning":
            return RoutineTimeOfDay(hour: 9, minute: 0)
        case "noon":
            return RoutineTimeOfDay(hour: 12, minute: 0)
        case "afternoon":
            return RoutineTimeOfDay(hour: 15, minute: 0)
        case "evening":
            return RoutineTimeOfDay(hour: 18, minute: 0)
        case "night", "tonight":
            return RoutineTimeOfDay(hour: 21, minute: 0)
        default:
            return nil
        }
    }

    private static func cleanedName(from working: String) -> String {
        var result = working
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let leadingPatterns = [
            #"^(add|create|new)\s+"#,
            #"^(todo|task|routine)\s+"#,
            #"^remind\s+me\s+to\s+"#
        ]

        for pattern in leadingPatterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return result
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private static func extractTokens(pattern: String, from working: inout String) -> [String] {
        var tokens: [String] = []
        while let match = removeFirstMatch(pattern: pattern, from: &working) {
            if let token = match.groups.first, !token.isEmpty {
                tokens.append(token)
            }
        }
        return tokens
    }

    private static func removeFirstMatch(
        pattern: String,
        from working: inout String
    ) -> RegexMatch? {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let range = NSRange(working.startIndex..<working.endIndex, in: working)
        guard let match = expression.firstMatch(in: working, range: range),
              let fullRange = Range(match.range, in: working)
        else {
            return nil
        }

        let groups = (1..<match.numberOfRanges).map { index -> String in
            guard let range = Range(match.range(at: index), in: working) else { return "" }
            return String(working[range])
        }

        working.removeSubrange(fullRange)
        return RegexMatch(groups: groups)
    }

    private static func weekdayNumber(for value: String) -> Int? {
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

    private static func nextDate(
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

    private static func date(
        on day: Date,
        timeOfDay: RoutineTimeOfDay?,
        calendar: Calendar
    ) -> Date {
        let start = calendar.startOfDay(for: day)
        return timeOfDay?.date(on: start, calendar: calendar) ?? start
    }
}

private struct RegexMatch: Equatable {
    var groups: [String]
}

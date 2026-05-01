import Foundation

struct RoutinaQuickAddDraft: Equatable, Sendable {
    var name: String
    var scheduleMode: RoutineScheduleMode
    var frequencyInDays: Int
    var recurrenceRule: RoutineRecurrenceRule
    var deadline: Date?
    var reminderAt: Date?
    var tags: [String]
    var placeName: String?
    var importance: RoutineTaskImportance
    var urgency: RoutineTaskUrgency
    var estimatedDurationMinutes: Int?
    var focusModeEnabled: Bool

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
            guard let deadline else { return "Todo" }
            return "Todo due \(deadline.formatted(date: .abbreviated, time: .shortened))"
        case .softInterval:
            return "Soft routine · \(recurrenceRule.displayText())"
        case .fixedInterval, .fixedIntervalChecklist, .derivedFromChecklist:
            return "Routine · \(recurrenceRule.displayText())"
        }
    }

    func saveRequest(placeID: UUID?) -> AddRoutineSaveRequest {
        AddRoutineSaveRequest(
            name: name,
            frequencyInDays: frequencyInDays,
            recurrenceRule: recurrenceRule,
            emoji: "✨",
            deadline: deadline,
            reminderAt: reminderAt,
            priority: AddRoutinePriorityMatrix.priority(
                importance: importance,
                urgency: urgency
            ),
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
        calendar: Calendar = .current
    ) -> RoutinaQuickAddDraft? {
        var working = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !working.isEmpty else { return nil }

        let tags = extractTokens(
            pattern: "(?:^|\\s)#([^\\s#@!]+)",
            from: &working
        ).compactMap(RoutineTag.cleaned)

        let placeName = extractTokens(
            pattern: "(?:^|\\s)@([^\\s#@!]+)",
            from: &working
        ).first.flatMap(RoutinePlace.cleanedName)

        let priority = extractPriority(from: &working)
        let durationMinutes = extractDurationMinutes(from: &working)
        let timeOfDay = extractTimeOfDay(from: &working)
        let schedule = extractSchedule(
            from: &working,
            timeOfDay: timeOfDay,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let name = cleanedName(from: working)
        guard !name.isEmpty else { return nil }

        return RoutinaQuickAddDraft(
            name: name,
            scheduleMode: schedule.scheduleMode,
            frequencyInDays: schedule.frequencyInDays,
            recurrenceRule: schedule.recurrenceRule,
            deadline: schedule.deadline,
            reminderAt: schedule.reminderAt,
            tags: tags,
            placeName: placeName,
            importance: priority.importance,
            urgency: priority.urgency,
            estimatedDurationMinutes: durationMinutes,
            focusModeEnabled: durationMinutes != nil
        )
    }

    private struct ParsedSchedule {
        var scheduleMode: RoutineScheduleMode = .oneOff
        var frequencyInDays: Int = 1
        var recurrenceRule: RoutineRecurrenceRule = .interval(days: 1)
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

        if removeFirstMatch(
            pattern: "(?:^|\\s)(?:due\\s+)?today(?=\\s|$)",
            from: &working
        ) != nil {
            let deadline = date(on: referenceDate, timeOfDay: timeOfDay, calendar: calendar)
            return ParsedSchedule(deadline: deadline, reminderAt: deadline)
        }

        if removeFirstMatch(
            pattern: "(?:^|\\s)(?:due\\s+|by\\s+)?tomorrow(?=\\s|$)",
            from: &working
        ) != nil {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
            let deadline = date(on: tomorrow, timeOfDay: timeOfDay, calendar: calendar)
            return ParsedSchedule(deadline: deadline, reminderAt: deadline)
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
            return ParsedSchedule(deadline: deadline, reminderAt: deadline)
        }

        return ParsedSchedule()
    }

    private static func extractPriority(
        from working: inout String
    ) -> (importance: RoutineTaskImportance, urgency: RoutineTaskUrgency) {
        guard let match = removeFirstMatch(
            pattern: "(?:^|\\s)!(urgent|high|medium|low)(?=\\s|$)",
            from: &working
        ) else {
            return (.level2, .level2)
        }

        switch match.groups[0].lowercased() {
        case "urgent":
            return (.level4, .level4)
        case "high":
            return (.level3, .level3)
        case "low":
            return (.level1, .level1)
        default:
            return (.level2, .level2)
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

        if let match = removeFirstMatch(
            pattern: "(?:^|\\s)at\\s+(\\d{1,2}):(\\d{2})(?=\\s|$)",
            from: &working
        ), let hour = Int(match.groups[0]), let minute = Int(match.groups[1]) {
            return RoutineTimeOfDay(hour: hour, minute: minute)
        }

        return nil
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

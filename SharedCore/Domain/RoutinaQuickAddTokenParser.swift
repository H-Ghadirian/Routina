import Foundation

extension RoutinaQuickAddParser {
    struct ParsedPriority {
        var importance: RoutineTaskImportance
        var urgency: RoutineTaskUrgency
        var wasExplicitlySet: Bool
    }

    static func extractPriority(
        from working: inout String
    ) -> ParsedPriority {
        guard
            let match = removeFirstMatch(
                pattern: "(?:^|\\s)!(urgent|high|medium|low)(?=\\s|$)",
                from: &working
            )
        else {
            return ParsedPriority(
                importance: .level2,
                urgency: .level2,
                wasExplicitlySet: false
            )
        }

        switch match.groups[0].lowercased() {
        case "urgent":
            return ParsedPriority(importance: .level4, urgency: .level4, wasExplicitlySet: true)
        case "high":
            return ParsedPriority(importance: .level3, urgency: .level3, wasExplicitlySet: true)
        case "low":
            return ParsedPriority(importance: .level1, urgency: .level1, wasExplicitlySet: true)
        default:
            return ParsedPriority(importance: .level2, urgency: .level2, wasExplicitlySet: true)
        }
    }

    static func extractDurationMinutes(from working: inout String) -> Int? {
        guard
            let match = removeFirstMatch(
                pattern: "(?:^|\\s)(?:for\\s+)?(\\d{1,3})\\s*(m|min|mins|minute|minutes|h|hr|hrs|hour|hours)(?=\\s|$)",
                from: &working
            ), let value = Int(match.groups[0])
        else {
            return nil
        }

        let unit = match.groups[1].lowercased()
        if unit.hasPrefix("h") {
            return min(max(value * 60, 1), 720)
        }
        return min(max(value, 1), 720)
    }

    static func extractTimeOfDay(from working: inout String) -> RoutineTimeOfDay? {
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
            (0...23).contains(hour), (0...59).contains(minute)
        {
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

    static func cleanedName(from working: String) -> String {
        var result =
            working
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let leadingPatterns = [
            #"^(add|create|new)\s+"#,
            #"^(one[- ]time task|repeating task|todo|task|routine)\s+"#,
            #"^remind\s+me\s+to\s+"#,
        ]

        for pattern in leadingPatterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return
            result
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }

    static func extractLinks(from working: inout String) -> [RoutineTaskLink] {
        let pattern = #"((?:https?://|www\.)[^\s<>\"']+)"#
        let trailingPunctuation = CharacterSet(charactersIn: ".,;:!?)]}")
        var links: [RoutineTaskLink] = []

        while let match = removeFirstMatch(pattern: pattern, from: &working),
            let rawLink = match.groups.first
        {
            let trimmedLink = rawLink.trimmingCharacters(in: trailingPunctuation)
            guard let sanitizedLink = RoutineTask.sanitizedLink(trimmedLink) else { continue }
            links.append(RoutineTaskLink(title: nil, url: sanitizedLink))
        }

        return RoutineTaskLinkStorage.sanitizedItems(links)
    }

    static func extractTokens(pattern: String, from working: inout String) -> [String] {
        var tokens: [String] = []
        while let match = removeFirstMatch(pattern: pattern, from: &working) {
            if let token = match.groups.first, !token.isEmpty {
                tokens.append(token)
            }
        }
        return tokens
    }

    static func removeFirstMatch(
        pattern: String,
        from working: inout String
    ) -> RegexMatch? {
        guard
            let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            )
        else {
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
}

struct RegexMatch: Equatable {
    var groups: [String]
}

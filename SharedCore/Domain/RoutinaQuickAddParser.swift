import Foundation

struct RoutinaQuickAddDraft: Equatable, Sendable {
    var name: String
    var usesGeneratedLinkName: Bool
    var linkItems: [RoutineTaskLink]
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
            || !linkItems.isEmpty
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

        if let primaryLinkURL {
            parts.append("Link · \(RoutinaQuickAddLinkSupport.sourceName(for: primaryLinkURL))")
        }

        return parts.joined(separator: " · ")
    }

    var primaryLinkURL: URL? {
        linkItems.first.flatMap { URL(string: $0.url) }
    }

    private var scheduleSummary: String {
        switch scheduleMode {
        case .oneOff:
            if let availabilityDate = exactAvailabilityDate() {
                return "One-time task at \(availabilityDate.formatted(date: .abbreviated, time: .shortened))"
            }
            if let availabilityStartDate {
                return "One-time task on \(availabilityStartDate.formatted(date: .abbreviated, time: .omitted))"
            }
            if let deadline {
                return "One-time task due \(deadline.formatted(date: .abbreviated, time: .shortened))"
            }
            return "One-time task"
        case .softInterval, .softIntervalChecklist, .softDerivedFromChecklist:
            return "Gentle repeating task · \(recurrenceRule.displayText())"
        case .fixedInterval, .fixedIntervalChecklist, .derivedFromChecklist:
            return "Repeating task · \(recurrenceRule.displayText())"
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
            linkItems: linkItems,
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
enum RoutinaQuickAddDraftContinuity {
    static func canPreservePreviewState(
        previousText: String,
        currentText: String,
        previousDraft: RoutinaQuickAddDraft?,
        currentDraft: RoutinaQuickAddDraft?
    ) -> Bool {
        let previousText = previousText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !previousText.isEmpty, !currentText.isEmpty else { return false }

        let previousLink = previousDraft?.primaryLinkURL
        let currentLink = currentDraft?.primaryLinkURL
        if previousLink != currentLink,
           previousLink != nil || currentLink != nil {
            return false
        }
        if previousLink != nil {
            return true
        }

        if currentText.hasPrefix(previousText)
            || previousText.hasPrefix(currentText)
            || differsByAtMostOneCharacter(previousText, currentText) {
            return true
        }

        guard let previousName = normalizedName(previousDraft?.name),
              let currentName = normalizedName(currentDraft?.name) else {
            return false
        }
        return previousName == currentName
    }

    private static func normalizedName(_ name: String?) -> String? {
        guard let normalized = name?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current),
              !normalized.isEmpty else {
            return nil
        }
        return normalized
    }

    private static func differsByAtMostOneCharacter(_ lhs: String, _ rhs: String) -> Bool {
        let lhs = Array(lhs)
        let rhs = Array(rhs)
        let difference = lhs.count - rhs.count
        guard abs(difference) <= 1 else { return false }

        if difference == 0 {
            return zip(lhs, rhs).lazy.filter { pair in
                pair.0 != pair.1
            }.count <= 1
        }

        let shorter = difference < 0 ? lhs : rhs
        let longer = difference < 0 ? rhs : lhs
        var shorterIndex = 0
        var longerIndex = 0
        var skippedCharacter = false

        while shorterIndex < shorter.count, longerIndex < longer.count {
            if shorter[shorterIndex] == longer[longerIndex] {
                shorterIndex += 1
                longerIndex += 1
            } else if skippedCharacter {
                return false
            } else {
                skippedCharacter = true
                longerIndex += 1
            }
        }
        return true
    }
}

enum RoutinaQuickAddPreviewPinning {
    static func updatedDraft(
        currentText: String,
        currentDraft: RoutinaQuickAddDraft?,
        pinnedDraft: RoutinaQuickAddDraft?,
        canBeginPresentation: Bool
    ) -> RoutinaQuickAddDraft? {
        guard !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if pinnedDraft != nil {
            return currentDraft ?? pinnedDraft
        }
        return canBeginPresentation ? currentDraft : nil
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

        let linkItems = extractLinks(from: &working)

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

        let explicitName = cleanedName(from: working)
        let usesGeneratedLinkName = explicitName.isEmpty && !linkItems.isEmpty
        let name = usesGeneratedLinkName
            ? linkItems.first.flatMap { URL(string: $0.url) }
                .map(RoutinaQuickAddLinkSupport.fallbackTaskTitle) ?? "Open link"
            : explicitName
        guard !name.isEmpty else { return nil }

        return RoutinaQuickAddDraft(
            name: name,
            usesGeneratedLinkName: usesGeneratedLinkName,
            linkItems: linkItems,
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
}

enum RoutinaQuickAddLinkSupport {
    static func fallbackTaskTitle(for url: URL) -> String {
        if isYouTubeURL(url) {
            return "Watch YouTube video"
        }
        if isGitHubURL(url) {
            return "Review GitHub link"
        }
        return "Open \(sourceName(for: url))"
    }

    static func taskTitle(fromMetadataTitle rawTitle: String, url: URL) -> String? {
        guard let pageTitle = cleanedMetadataTitle(rawTitle, url: url) else { return nil }
        if isYouTubeURL(url) {
            return hasActionPrefix(pageTitle, prefix: "Watch") ? pageTitle : "Watch: \(pageTitle)"
        }
        if isGitHubURL(url) {
            return hasActionPrefix(pageTitle, prefix: "Review") ? pageTitle : "Review: \(pageTitle)"
        }
        return pageTitle
    }

    static func cleanedMetadataTitle(_ rawTitle: String, url: URL) -> String? {
        var title = rawTitle
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        if isYouTubeURL(url) {
            title = title.replacingOccurrences(
                of: #"\s*[-|–—]\s*YouTube\s*$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return title.isEmpty ? nil : title
    }

    static func sourceName(for url: URL) -> String {
        if isYouTubeURL(url) { return "YouTube" }
        if isGitHubURL(url) { return "GitHub" }

        let host = normalizedHost(for: url)
        return host.isEmpty ? "link" : host
    }

    static func canFetchMetadata(for url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.user == nil,
              url.password == nil else {
            return false
        }

        let host = normalizedHost(for: url)
        guard !host.isEmpty,
              host != "localhost",
              !host.hasSuffix(".localhost"),
              !host.hasSuffix(".local"),
              host != "::1",
              host != "0.0.0.0",
              !host.hasPrefix("127."),
              !host.hasPrefix("10."),
              !host.hasPrefix("192.168.") else {
            return false
        }

        if host.hasPrefix("172."),
           let secondOctet = host.split(separator: ".").dropFirst().first.flatMap({ Int($0) }),
           (16...31).contains(secondOctet) {
            return false
        }

        return true
    }

    static func resolvedLinkTitle(from rawTitle: String, url: URL) -> String? {
        cleanedMetadataTitle(rawTitle, url: url)
    }

    private static func hasActionPrefix(_ title: String, prefix: String) -> Bool {
        title.range(
            of: "^\(NSRegularExpression.escapedPattern(for: prefix))(?:\\s|:)",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func isYouTubeURL(_ url: URL) -> Bool {
        let host = normalizedHost(for: url)
        return host == "youtube.com" || host.hasSuffix(".youtube.com") || host == "youtu.be"
    }

    private static func isGitHubURL(_ url: URL) -> Bool {
        let host = normalizedHost(for: url)
        return host == "github.com" || host.hasSuffix(".github.com")
    }

    private static func normalizedHost(for url: URL) -> String {
        var host = url.host?.lowercased() ?? ""
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        return host
    }
}

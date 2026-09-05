import Foundation

extension RoutineTask {
    static func trimmedName(_ name: String?) -> String? {
        RoutineModelValueSanitizer.trimmedName(name)
    }

    static func normalizedName(_ name: String?) -> String? {
        RoutineModelValueSanitizer.normalizedName(name)
    }

    static func sanitizedNotes(_ notes: String?) -> String? {
        RoutineModelValueSanitizer.sanitizedNotes(notes)
    }

    static func sanitizedDescription(_ description: String?) -> String? {
        RoutineModelValueSanitizer.sanitizedDescription(description)
    }

    static func sanitizedDestinationAddress(_ address: String?) -> String? {
        guard let address else { return nil }
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func sanitizedDestinationCoordinate(
        latitude: Double?,
        longitude: Double?
    ) -> LocationCoordinate? {
        guard let latitude,
            let longitude,
            latitude.isFinite,
            longitude.isFinite,
            (-90...90).contains(latitude),
            (-180...180).contains(longitude)
        else { return nil }
        return LocationCoordinate(latitude: latitude, longitude: longitude)
    }

    static func sanitizedLink(_ link: String?) -> String? {
        RoutineModelValueSanitizer.sanitizedLink(link)
    }

    static func sanitizedLinks(_ links: [String]) -> [String] {
        RoutineTaskLinkStorage.sanitized(links)
    }

    static func sanitizedLinks(fromEditorText text: String) -> [String] {
        sanitizedLinkItems(fromEditorText: text).map(\.url)
    }

    static func linkEditorText(for links: [String]) -> String {
        linkEditorText(for: links.map { RoutineTaskLink(title: nil, url: $0) })
    }

    static func sanitizedLinkItems(fromEditorText text: String) -> [RoutineTaskLink] {
        let items = text.components(separatedBy: .newlines).map { line in
            let parts = line.components(separatedBy: "\t")
            if parts.count >= 2 {
                return RoutineTaskLink(title: parts[0], url: parts.dropFirst().joined(separator: "\t"))
            }
            return RoutineTaskLink(title: nil, url: line)
        }
        return RoutineTaskLinkStorage.sanitizedItems(items)
    }

    static func linkEditorText(for links: [RoutineTaskLink]) -> String {
        RoutineTaskLinkStorage.sanitizedItems(links)
            .map { link in
                if let title = link.title, !title.isEmpty {
                    return "\(title)\t\(link.url)"
                }
                return link.url
            }
            .joined(separator: "\n")
    }

    static func normalizedAvailabilityDateBounds(
        startDate: Date?,
        endDate: Date?,
        calendar: Calendar = .current
    ) -> (startDate: Date?, endDate: Date?) {
        guard let startDate else {
            return (nil, nil)
        }
        let normalizedStartDate = calendar.startOfDay(for: startDate)
        guard let endDate else {
            return (normalizedStartDate, nil)
        }
        let normalizedEndDate = calendar.startOfDay(for: endDate)
        return (
            normalizedStartDate,
            normalizedEndDate < normalizedStartDate ? normalizedStartDate : normalizedEndDate
        )
    }

    static func normalizedPlannedDate(
        _ plannedDate: Date?,
        calendar: Calendar = .current
    ) -> Date? {
        plannedDate.map { calendar.startOfDay(for: $0) }
    }

    static func exactAvailabilityPlannedDate(
        scheduleMode: RoutineScheduleMode,
        availabilityStartDate: Date?,
        availabilityEndDate: Date?,
        calendar: Calendar = .current
    ) -> Date? {
        guard scheduleMode.taskType == .todo else { return nil }
        let bounds = normalizedAvailabilityDateBounds(
            startDate: availabilityStartDate,
            endDate: availabilityEndDate,
            calendar: calendar
        )
        guard let startDate = bounds.startDate,
            bounds.endDate == nil
        else {
            return nil
        }
        return startDate
    }

    static func effectivePlannedDate(
        plannedDate: Date?,
        scheduleMode: RoutineScheduleMode,
        availabilityStartDate: Date?,
        availabilityEndDate: Date?,
        calendar: Calendar = .current
    ) -> Date? {
        exactAvailabilityPlannedDate(
            scheduleMode: scheduleMode,
            availabilityStartDate: availabilityStartDate,
            availabilityEndDate: availabilityEndDate,
            calendar: calendar
        ) ?? normalizedPlannedDate(plannedDate, calendar: calendar)
    }

    var resolvedLinkURL: URL? {
        resolvedLinkURLs.first?.url
    }

    var resolvedLinkURLs: [RoutineTaskResolvedLink] {
        linkItems.compactMap { link in
            guard let url = URL(string: link.url) else { return nil }
            return RoutineTaskResolvedLink(text: link.displayText, url: url)
        }
    }

    static func sanitizedEmoji(_ input: String, fallback: String) -> String {
        RoutineModelValueSanitizer.sanitizedEmoji(input, fallback: fallback)
    }

    static func resolvedRelationships(
        for task: RoutineTask,
        within candidates: [RoutineTaskRelationshipCandidate]
    ) -> [RoutineTaskResolvedRelationship] {
        RoutineTaskRelationshipResolution.resolvedRelationships(for: task, within: candidates)
    }

    static func editableRelationships(
        for task: RoutineTask,
        within candidates: [RoutineTaskRelationshipCandidate]
    ) -> [RoutineTaskRelationship] {
        RoutineTaskRelationshipResolution.editableRelationships(for: task, within: candidates)
    }

    static func removeRelationships(
        targeting deletedTaskIDs: Set<UUID>,
        from tasks: [RoutineTask]
    ) {
        RoutineTaskRelationshipResolution.removeRelationships(targeting: deletedTaskIDs, from: tasks)
    }

    static func removeInverseRelationships(
        targeting ownerID: UUID,
        from tasks: [RoutineTask]
    ) {
        RoutineTaskRelationshipResolution.removeInverseRelationships(targeting: ownerID, from: tasks)
    }

    static func sanitizedEstimatedDurationMinutes(_ value: Int?) -> Int? {
        RoutineModelValueSanitizer.sanitizedPositiveInteger(value)
    }

    static func sanitizedActualDurationMinutes(_ value: Int?) -> Int? {
        RoutineModelValueSanitizer.sanitizedPositiveInteger(value)
    }

    static func sanitizedStoryPoints(_ value: Int?) -> Int? {
        RoutineModelValueSanitizer.sanitizedPositiveInteger(value)
    }
}

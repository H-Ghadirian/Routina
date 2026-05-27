import EventKit
import Foundation

struct CalendarTaskEventMetadata: Equatable {
    let isAllDay: Bool
    let startDate: Date
    let endDate: Date
}

struct CalendarTaskSuggestion: Identifiable, Equatable {
    enum ReviewState: Equatable {
        case pending
        case added
        case skipped
        case duplicate
    }

    let id: String
    let eventIdentifier: String
    let calendarIdentifier: String
    let calendarTitle: String
    let eventTitle: String
    let eventStartDate: Date
    let eventEndDate: Date
    let isAllDay: Bool
    var taskTitle: String
    var deadline: Date?
    var reviewState: ReviewState

    var sourceMarker: String {
        "Calendar event: \(eventIdentifier)"
    }
}

enum CalendarTaskImportError: Error, Equatable {
    case accessDenied
    case accessRestricted
    case failedToLoadEvents
}

@MainActor
final class CalendarTaskImportService {
    private let eventStore = EKEventStore()

    func requestAccessIfNeeded() async throws {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            return
        case .denied:
            throw CalendarTaskImportError.accessDenied
        case .restricted:
            throw CalendarTaskImportError.accessRestricted
        case .writeOnly:
            throw CalendarTaskImportError.accessDenied
        case .notDetermined:
            let granted = try await eventStore.requestFullAccessToEvents()
            guard granted else { throw CalendarTaskImportError.accessDenied }
        @unknown default:
            throw CalendarTaskImportError.accessDenied
        }
    }

    func calendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications || !$0.title.isEmpty }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    func suggestions(
        from startDate: Date,
        through endDate: Date,
        calendarIdentifiers: Set<String>,
        existingTasks: [RoutineTask],
        calendar: Calendar
    ) throws -> [CalendarTaskSuggestion] {
        let selectedCalendars = calendars().filter { calendarIdentifiers.contains($0.calendarIdentifier) }
        guard !selectedCalendars.isEmpty else { return [] }

        let existingMarkers = CalendarTaskImportSupport.existingSourceMarkers(in: existingTasks)

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: selectedCalendars
        )

        return eventStore.events(matching: predicate)
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.startDate < rhs.startDate
            }
            .map { event in
                let eventIdentifier = event.eventIdentifier ?? event.calendarItemIdentifier
                let marker = "Calendar event: \(eventIdentifier)"
                let normalizedTitle = CalendarTaskImportSupport.defaultTaskTitle(for: event.title)
                let deadline = event.isAllDay ? calendar.startOfDay(for: event.startDate) : event.startDate
                return CalendarTaskSuggestion(
                    id: eventIdentifier,
                    eventIdentifier: eventIdentifier,
                    calendarIdentifier: event.calendar.calendarIdentifier,
                    calendarTitle: event.calendar.title,
                    eventTitle: event.title,
                    eventStartDate: event.startDate,
                    eventEndDate: event.endDate,
                    isAllDay: event.isAllDay,
                    taskTitle: normalizedTitle,
                    deadline: deadline,
                    reviewState: existingMarkers.contains(marker) ? .duplicate : .pending
                )
            }
    }
}

enum CalendarTaskImportSupport {
    static let defaultTaskEmoji = "📅"
    private static let sourceMarkerPrefix = "Calendar event: "
    private static let allDayMarkerPrefix = "Calendar event all-day: "
    private static let startMarkerPrefix = "Calendar event start: "
    private static let endMarkerPrefix = "Calendar event end: "

    static func defaultTaskTitle(for eventTitle: String) -> String {
        let trimmed = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Calendar follow-up" }

        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("prepare ") || lowercased.hasPrefix("follow up ") || lowercased.hasPrefix("send ") {
            return trimmed
        }
        return trimmed
    }

    static func notes(for suggestion: CalendarTaskSuggestion, calendar: Calendar = .current) -> String {
        var lines = [
            "Imported from \(suggestion.calendarTitle).",
            suggestion.sourceMarker,
        ]

        if let metadata = metadata(for: suggestion, calendar: calendar) {
            lines.append(contentsOf: metadataLines(for: metadata))
        }

        return lines.joined(separator: "\n")
    }

    static func displayEmoji(for emoji: String?) -> String? {
        guard let emoji else { return nil }
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmoji.isEmpty else { return nil }
        if trimmedEmoji == "calendar.badge.plus" {
            return defaultTaskEmoji
        }
        return trimmedEmoji
    }

    static func displayNotes(from notes: String?) -> String? {
        guard let notes else { return nil }

        let visibleNotes = notes
            .components(separatedBy: .newlines)
            .filter { !isInternalMarkerLine($0) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return visibleNotes.isEmpty ? nil : visibleNotes
    }

    static func notesPreservingCalendarMarkers(
        visibleNotes: String?,
        existingNotes: String?
    ) -> String? {
        let visibleLines = (visibleNotes ?? "")
            .components(separatedBy: .newlines)
            .filter { !isInternalMarkerLine($0) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let markerLines = (existingNotes ?? "")
            .components(separatedBy: .newlines)
            .filter(isInternalMarkerLine)

        let combinedLines = ([visibleLines].filter { !$0.isEmpty } + markerLines)
        guard !combinedLines.isEmpty else { return nil }
        return combinedLines.joined(separator: "\n")
    }

    static func sourceMarker(in notes: String) -> String? {
        notes
            .components(separatedBy: .newlines)
            .first { $0.hasPrefix(sourceMarkerPrefix) }
    }

    static func existingSourceMarkers(in tasks: [RoutineTask]) -> Set<String> {
        Set(
            tasks.compactMap { task -> String? in
                guard let notes = task.notes else { return nil }
                return sourceMarker(in: notes)
            }
        )
    }

    static func eventMetadata(in notes: String?) -> CalendarTaskEventMetadata? {
        guard let notes else { return nil }
        var isAllDay = false
        var startDate: Date?
        var endDate: Date?

        for line in notes.components(separatedBy: .newlines) {
            if let value = markerValue(in: line, prefix: allDayMarkerPrefix) {
                isAllDay = value.lowercased() == "true"
            } else if let value = markerValue(in: line, prefix: startMarkerPrefix) {
                startDate = decodeDate(value)
            } else if let value = markerValue(in: line, prefix: endMarkerPrefix) {
                endDate = decodeDate(value)
            }
        }

        guard isAllDay, let startDate, let endDate, endDate > startDate else {
            return nil
        }

        return CalendarTaskEventMetadata(
            isAllDay: isAllDay,
            startDate: startDate,
            endDate: endDate
        )
    }

    private static func metadata(for suggestion: CalendarTaskSuggestion, calendar: Calendar) -> CalendarTaskEventMetadata? {
        guard suggestion.isAllDay else { return nil }

        let eventStartDay = calendar.startOfDay(for: suggestion.eventStartDate)
        let eventEndDay = normalizedAllDayEndDate(
            startDate: suggestion.eventStartDate,
            endDate: suggestion.eventEndDate,
            calendar: calendar
        )
        let dayCount = max(
            calendar.dateComponents([.day], from: eventStartDay, to: eventEndDay).day ?? 1,
            1
        )
        let selectedStartDay = calendar.startOfDay(for: suggestion.deadline ?? suggestion.eventStartDate)
        let selectedEndDay = calendar.date(
            byAdding: .day,
            value: dayCount,
            to: selectedStartDay
        ) ?? eventEndDay

        return CalendarTaskEventMetadata(
            isAllDay: true,
            startDate: selectedStartDay,
            endDate: selectedEndDay
        )
    }

    private static func normalizedAllDayEndDate(
        startDate: Date,
        endDate: Date,
        calendar: Calendar
    ) -> Date {
        let startDay = calendar.startOfDay(for: startDate)
        guard endDate > startDate else {
            return calendar.date(byAdding: .day, value: 1, to: startDay) ?? startDay
        }

        let endDay = calendar.startOfDay(for: endDate)
        if endDay <= startDay {
            return calendar.date(byAdding: .day, value: 1, to: startDay) ?? startDay
        }

        if isStartOfDay(endDate, calendar: calendar) {
            return endDay
        }

        return calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
    }

    private static func metadataLines(for metadata: CalendarTaskEventMetadata) -> [String] {
        [
            "\(allDayMarkerPrefix)\(metadata.isAllDay)",
            "\(startMarkerPrefix)\(encodeDate(metadata.startDate))",
            "\(endMarkerPrefix)\(encodeDate(metadata.endDate))",
        ]
    }

    private static func isInternalMarkerLine(_ line: String) -> Bool {
        line.hasPrefix(sourceMarkerPrefix)
            || line.hasPrefix(allDayMarkerPrefix)
            || line.hasPrefix(startMarkerPrefix)
            || line.hasPrefix(endMarkerPrefix)
    }

    private static func markerValue(in line: String, prefix: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isStartOfDay(_ date: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        return (components.hour ?? 0) == 0
            && (components.minute ?? 0) == 0
            && (components.second ?? 0) == 0
            && (components.nanosecond ?? 0) == 0
    }

    private static func encodeDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func decodeDate(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

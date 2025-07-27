import EventKit
import Foundation

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
            let granted: Bool
            if #available(iOS 17.0, macOS 14.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }
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

        let existingMarkers = Set(
            existingTasks.compactMap { task -> String? in
                guard let notes = task.notes else { return nil }
                return CalendarTaskImportSupport.sourceMarker(in: notes)
            }
        )

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
    static func defaultTaskTitle(for eventTitle: String) -> String {
        let trimmed = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Calendar follow-up" }

        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("prepare ") || lowercased.hasPrefix("follow up ") || lowercased.hasPrefix("send ") {
            return trimmed
        }
        return trimmed
    }

    static func notes(for suggestion: CalendarTaskSuggestion) -> String {
        [
            "Imported from \(suggestion.calendarTitle).",
            suggestion.sourceMarker,
        ].joined(separator: "\n")
    }

    static func sourceMarker(in notes: String) -> String? {
        notes
            .components(separatedBy: .newlines)
            .first { $0.hasPrefix("Calendar event: ") }
    }
}

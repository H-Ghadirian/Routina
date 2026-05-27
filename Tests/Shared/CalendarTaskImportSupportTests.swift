import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct CalendarTaskImportSupportTests {
    @Test
    func displayNotes_hidesCalendarEventIdentifier() {
        let notes = """
        Imported from Deutsche Feiertage.
        Calendar event: 3DE17037-44AD-4645-94A7-4B9A93139413:51a09fef-525c-3b76-85db-5934055bc9e7
        """

        #expect(CalendarTaskImportSupport.displayNotes(from: notes) == "Imported from Deutsche Feiertage.")
    }

    @Test
    func displayNotes_returnsNilWhenOnlyInternalMarkerRemains() {
        #expect(CalendarTaskImportSupport.displayNotes(from: "Calendar event: event-id") == nil)
    }

    @Test
    func displayEmoji_mapsLegacySystemSymbolToCalendarEmoji() {
        #expect(CalendarTaskImportSupport.displayEmoji(for: "calendar.badge.plus") == CalendarTaskImportSupport.defaultTaskEmoji)
        #expect(CalendarTaskImportSupport.displayEmoji(for: " calendar.badge.plus ") == CalendarTaskImportSupport.defaultTaskEmoji)
        #expect(CalendarTaskImportSupport.displayEmoji(for: "✅") == "✅")
    }

    @Test
    func notesStoresAllDayMetadataAndDisplayNotesHidesMarkers() throws {
        let calendar = gregorianCalendar
        let startDate = try #require(date("2026-05-25T00:00:00Z"))
        let endDate = try #require(date("2026-05-28T00:00:00Z"))
        let suggestion = CalendarTaskSuggestion(
            id: "event",
            eventIdentifier: "event",
            calendarIdentifier: "outlook",
            calendarTitle: "Outlook",
            eventTitle: "Travel",
            eventStartDate: startDate,
            eventEndDate: endDate,
            isAllDay: true,
            taskTitle: "Travel",
            deadline: startDate,
            reviewState: .pending
        )

        let notes = CalendarTaskImportSupport.notes(for: suggestion, calendar: calendar)
        let metadata = try #require(CalendarTaskImportSupport.eventMetadata(in: notes))

        #expect(CalendarTaskImportSupport.displayNotes(from: notes) == "Imported from Outlook.")
        #expect(metadata.isAllDay)
        #expect(metadata.startDate == startDate)
        #expect(metadata.endDate == endDate)
    }

    @Test
    func notesPreservingCalendarMarkersKeepsHiddenMetadataAfterVisibleEdits() throws {
        let calendar = gregorianCalendar
        let startDate = try #require(date("2026-05-25T00:00:00Z"))
        let endDate = try #require(date("2026-05-26T00:00:00Z"))
        let suggestion = CalendarTaskSuggestion(
            id: "event",
            eventIdentifier: "event",
            calendarIdentifier: "outlook",
            calendarTitle: "Outlook",
            eventTitle: "Sick day",
            eventStartDate: startDate,
            eventEndDate: endDate,
            isAllDay: true,
            taskTitle: "Sick day",
            deadline: startDate,
            reviewState: .pending
        )
        let existingNotes = CalendarTaskImportSupport.notes(for: suggestion, calendar: calendar)

        let mergedNotes = CalendarTaskImportSupport.notesPreservingCalendarMarkers(
            visibleNotes: "Doctor note submitted.",
            existingNotes: existingNotes
        )

        #expect(CalendarTaskImportSupport.displayNotes(from: mergedNotes) == "Doctor note submitted.")
        #expect(CalendarTaskImportSupport.sourceMarker(in: mergedNotes ?? "") == "Calendar event: event")
        #expect(CalendarTaskImportSupport.eventMetadata(in: mergedNotes)?.startDate == startDate)
    }

    @Test
    func suggestionRowPresentationMapsReviewStates() {
        #expect(CalendarTaskSuggestionRowPresentation.status(for: .pending) == nil)
        #expect(
            CalendarTaskSuggestionRowPresentation.status(for: .added)
                == CalendarTaskSuggestionStatusPresentation(
                    title: "Added",
                    systemImage: "checkmark.circle.fill",
                    tint: .success
                )
        )
        #expect(CalendarTaskSuggestionRowPresentation.status(for: .duplicate)?.title == "Already added")
    }

    @Test
    func suggestionRowPresentationRequiresPendingTrimmedTitleToAdd() {
        var suggestion = makeSuggestion(taskTitle: " Follow up ")
        #expect(CalendarTaskSuggestionRowPresentation.canAdd(suggestion))

        suggestion.reviewState = .skipped
        #expect(CalendarTaskSuggestionRowPresentation.canAdd(suggestion) == false)
    }

    private func makeSuggestion(
        taskTitle: String,
        reviewState: CalendarTaskSuggestion.ReviewState = .pending
    ) -> CalendarTaskSuggestion {
        CalendarTaskSuggestion(
            id: "event",
            eventIdentifier: "event",
            calendarIdentifier: "calendar",
            calendarTitle: "Work",
            eventTitle: "Follow up",
            eventStartDate: Date(),
            eventEndDate: Date(),
            isAllDay: false,
            taskTitle: taskTitle,
            deadline: nil,
            reviewState: reviewState
        )
    }
}

private let gregorianCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func date(_ string: String) -> Date? {
    ISO8601DateFormatter().date(from: string)
}

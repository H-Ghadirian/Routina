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

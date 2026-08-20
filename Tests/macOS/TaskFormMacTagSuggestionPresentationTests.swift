import Foundation
import Testing
@testable @preconcurrency import RoutinaMacOSDev

struct TaskFormMacTagSuggestionPresentationTests {
    @Test
    func collapsedSuggestionsShowOnlyHighestUsePrefix() {
        let usageOrderedTags = [
            "Work", "Health", "Home", "Focus", "Learning", "Errands", "Travel", "Finance"
        ]

        #expect(
            TaskFormMacTagSuggestionPresentation.visibleAvailableTags(
                usageOrderedTags,
                showsAll: false
            ) == Array(usageOrderedTags.prefix(6))
        )
    }

    @Test
    func expandedSuggestionsShowEveryAvailableTag() {
        let tags = ["Work", "Health", "Home", "Focus", "Learning", "Errands", "Travel"]

        #expect(
            TaskFormMacTagSuggestionPresentation.visibleAvailableTags(tags, showsAll: true)
                == tags
        )
    }

    @Test
    func twoHourQuickAddReminderUsesThePreviewEventDate() {
        let eventDate = Date(timeIntervalSince1970: 1_000_000)
        let customDate = Date(timeIntervalSince1970: 2_000_000)

        #expect(
            HomeMacToolbarSearchReminderChoice.twoHours.reminderDate(
                eventDate: eventDate,
                customDate: customDate
            ) == eventDate.addingTimeInterval(-2 * 60 * 60)
        )
    }
}

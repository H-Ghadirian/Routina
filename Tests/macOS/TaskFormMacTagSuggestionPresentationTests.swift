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
}

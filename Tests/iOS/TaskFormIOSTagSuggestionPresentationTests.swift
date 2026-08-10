import Testing
@testable @preconcurrency import Routina

struct TaskFormIOSTagSuggestionPresentationTests {
    @Test
    func inlineSuggestionsStayWithinTheCompactLimit() {
        let tags = ["Work", "Health", "Home", "Focus", "Learning", "Errands", "Travel"]

        let presentation = TaskFormIOSTagSuggestionPresentation.make(
            routineTags: [],
            relatedTagRules: [],
            availableTags: tags
        )

        #expect(presentation.suggestedTags == Array(tags.prefix(TaskFormIOSTagSuggestionPresentation.collapsedLimit)))
        #expect(presentation.remainingTagCount == tags.count)
    }
}

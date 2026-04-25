import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct HomeTagFilterSupportTests {
    @Test
    func buildsTagDataForCurrentTaskListMode() {
        let support = makeSupport(
            selectedTags: ["Focus"],
            displays: [
                TagDisplay(tags: ["Focus", "Deep Work"]),
                TagDisplay(tags: ["Focus", "Admin"]),
                TagDisplay(tags: ["Errand"]),
                TagDisplay(tags: ["Focus", "Hidden"], isVisible: false)
            ],
            relatedTagRules: [
                RoutineRelatedTagRule(tag: "Focus", relatedTags: ["Deep Work", "Errand"])
            ]
        )

        #expect(support.allTagTaskCount == 3)
        #expect(support.tagSummaries.map(\.name) == ["Focus", "Admin", "Deep Work", "Errand"])
        #expect(support.availableExcludeTagSummaries.map(\.name) == ["Admin", "Deep Work"])
        #expect(support.suggestedRelatedTags == ["Deep Work", "Errand"])
    }

    @Test
    func mutatesIncludedAndExcludedTags() {
        let support = makeSupport(selectedTags: ["Focus"], suggestionAnchor: nil)

        let added = support.toggledIncludedTag("Admin")
        #expect(added.selectedTags == ["Focus", "Admin"])
        #expect(added.suggestionAnchor == "Admin")

        let removed = support.toggledIncludedTag("focus")
        #expect(removed.selectedTags.isEmpty)
        #expect(removed.suggestionAnchor == nil)

        #expect(support.addedIncludedTag("focus") == nil)
        #expect(support.addedIncludedTag("Admin")?.selectedTags == ["Focus", "Admin"])

        let excluded = support.toggledExcludedTag("Focus", excludedTags: ["Errand"])
        #expect(excluded.selectedTags.isEmpty)
        #expect(excluded.excludedTags == ["Errand", "Focus"])

        let unexcluded = support.toggledExcludedTag("Errand", excludedTags: ["Errand"])
        #expect(unexcluded.selectedTags == ["Focus"])
        #expect(unexcluded.excludedTags.isEmpty)
    }

    private func makeSupport(
        selectedTags: Set<String>,
        suggestionAnchor: String? = nil,
        displays: [TagDisplay] = [],
        relatedTagRules: [RoutineRelatedTagRule] = []
    ) -> HomeTagFilterSupport<TagDisplay> {
        HomeTagFilterSupport(
            allDisplays: displays,
            matchesCurrentTaskListMode: \.isVisible,
            tags: \.tags,
            selectedTags: selectedTags,
            includeTagMatchMode: .all,
            relatedTagRules: relatedTagRules,
            suggestionAnchor: suggestionAnchor
        )
    }
}

private struct TagDisplay {
    let tags: [String]
    var isVisible = true
}

import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct StatsFilterPresentationTests {
    @Test
    func activeSheetFilterCountTracksEveryStatsFilterBucket() {
        let presentation = makePresentation(
            taskTypeFilter: .todos,
            advancedQuery: " tag:work ",
            selectedTags: ["Focus"],
            excludedTags: ["Low", "Errand"],
            selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell(importance: .level3, urgency: .level2)
        )

        #expect(presentation.hasActiveSheetFilters)
        #expect(presentation.activeSheetFilterCount == 6)
    }

    @Test
    func tagMutationsKeepIncludeAndExcludeFiltersExclusive() {
        let presentation = makePresentation(
            selectedTags: ["Focus", "Work"],
            excludedTags: ["Errand"]
        )

        let included = presentation.toggledIncludedTag("Health", currentSuggestionAnchor: nil)
        let excluded = presentation.toggledExcludedTag("Focus")

        #expect(included.selectedTags == ["Focus", "Health", "Work"])
        #expect(included.suggestionAnchor == "Health")
        #expect(excluded.selectedTags == ["Work"])
        #expect(excluded.excludedTags == ["Errand", "Focus"])
    }

    @Test
    func relatedTagsAndSummariesUseSharedStatsCopy() {
        let presentation = makePresentation(
            selectedTags: ["Focus"],
            includeTagMatchMode: .any,
            excludedTags: ["Errand"],
            availableTags: ["Focus", "Deep", "Errand"],
            relatedTagRules: [RoutineRelatedTagRule(tag: "Focus", relatedTags: ["Deep"])],
            tagColors: ["focus": "#112233"]
        )

        #expect(presentation.suggestedRelatedTags(suggestionAnchor: nil) == ["Deep"])
        #expect(presentation.tagSelectionSummary(tagCount: 3) == "Any of #Focus")
        #expect(presentation.excludedTagSummary == "Hiding tasks tagged: #Errand")

        let data = presentation.tagRuleData(
            suggestedRelatedTags: ["Deep"],
            availableExcludeTags: ["Deep", "Errand"]
        )
        #expect(data.selectedTags == ["Focus"])
        #expect(data.suggestedRelatedTags == ["Deep"])
        #expect(data.tagSummaries.first?.colorHex == "#112233")
    }

    private func makePresentation(
        taskTypeFilter: StatsTaskTypeFilter = .all,
        advancedQuery: String = "",
        selectedTags: Set<String> = [],
        includeTagMatchMode: RoutineTagMatchMode = .all,
        excludedTags: Set<String> = [],
        excludeTagMatchMode: RoutineTagMatchMode = .any,
        selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
        availableTags: [String] = [],
        relatedTagRules: [RoutineRelatedTagRule] = [],
        tagColors: [String: String] = [:]
    ) -> StatsFilterPresentation {
        StatsFilterPresentation(
            taskTypeFilter: taskTypeFilter,
            advancedQuery: advancedQuery,
            selectedTags: selectedTags,
            includeTagMatchMode: includeTagMatchMode,
            excludedTags: excludedTags,
            excludeTagMatchMode: excludeTagMatchMode,
            selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter,
            availableTags: availableTags,
            relatedTagRules: relatedTagRules,
            tagColors: tagColors
        )
    }
}

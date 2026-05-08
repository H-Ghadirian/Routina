import Foundation

struct TimelineFilterPresentation {
    let selectedTags: Set<String>
    let excludedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let availableTags: [String]
    let relatedTagRules: [RoutineRelatedTagRule]

    func suggestedRelatedTags(suggestionAnchor: String?) -> [String] {
        guard !selectedTags.isEmpty else { return [] }
        let suggestionSource = suggestionAnchor.map { [$0] } ?? Array(selectedTags)
        return RoutineTagRelations.relatedTags(
            for: suggestionSource,
            rules: relatedTagRules,
            availableTags: availableTags
        )
    }

    func availableExcludeTags() -> [String] {
        HomeTagFilterMutationSupport.availableExcludeTags(
            from: availableTags,
            selectedTags: selectedTags
        )
    }

    func availableExcludeTags(from entries: [TimelineEntry]) -> [String] {
        let includeScopedEntries = entries.filter { entry in
            HomeDisplayFilterSupport.matchesSelectedTags(
                selectedTags,
                mode: includeTagMatchMode,
                in: entry.tags
            )
        }

        return HomeTagFilterMutationSupport.availableExcludeTags(
            from: TimelineLogic.availableTags(from: includeScopedEntries),
            selectedTags: selectedTags
        )
    }

    func tagRuleData(
        suggestedRelatedTags: [String],
        availableExcludeTags: [String]
    ) -> HomeTagFilterData {
        HomeTagFilterData(
            selectedTags: selectedTags,
            excludedTags: excludedTags,
            tagSummaries: availableTags.map { RoutineTagSummary(name: $0, linkedRoutineCount: 0) },
            allTagTaskCount: 0,
            suggestedRelatedTags: suggestedRelatedTags,
            availableExcludeTagSummaries: availableExcludeTags.map {
                RoutineTagSummary(name: $0, linkedRoutineCount: 0)
            },
            showsTagCounts: false
        )
    }

    func isIncludedTagSelected(_ tag: String) -> Bool {
        HomeTagFilterMutationSupport.contains(tag, in: selectedTags)
    }

    func toggledIncludedTag(
        _ tag: String,
        currentSuggestionAnchor: String?
    ) -> HomeIncludedTagMutation {
        HomeTagFilterMutationSupport.toggledIncludedTag(
            tag,
            selectedTags: selectedTags,
            suggestionAnchor: currentSuggestionAnchor
        )
    }

    func addedIncludedTag(
        _ tag: String,
        currentSuggestionAnchor: String?
    ) -> HomeIncludedTagMutation? {
        HomeTagFilterMutationSupport.addedIncludedTag(
            tag,
            selectedTags: selectedTags,
            suggestionAnchor: currentSuggestionAnchor
        )
    }

    func toggledExcludedTag(_ tag: String) -> HomeExcludedTagMutation {
        HomeTagFilterMutationSupport.toggledExcludedTag(
            tag,
            selectedTags: selectedTags,
            excludedTags: excludedTags
        )
    }
}

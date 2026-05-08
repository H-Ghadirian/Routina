import Foundation

struct HomeTagFilterSupport<Display> {
    let allDisplays: [Display]
    let matchesCurrentTaskListMode: (Display) -> Bool
    let tags: (Display) -> [String]
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let relatedTagRules: [RoutineRelatedTagRule]
    let suggestionAnchor: String?

    private var modeScopedDisplays: [Display] {
        allDisplays.filter(matchesCurrentTaskListMode)
    }

    var tagSummaries: [RoutineTagSummary] {
        HomeDisplayFilterSupport.tagSummaries(from: modeScopedDisplays, tags: tags)
    }

    var allTagTaskCount: Int {
        modeScopedDisplays.count
    }

    var availableTags: [String] {
        tagSummaries.map(\.name)
    }

    var availableExcludeTagSummaries: [RoutineTagSummary] {
        let includeScopedDisplays = modeScopedDisplays.filter { display in
            HomeDisplayFilterSupport.matchesSelectedTags(
                selectedTags,
                mode: includeTagMatchMode,
                in: tags(display)
            )
        }

        return HomeDisplayFilterSupport.tagSummaries(from: includeScopedDisplays, tags: tags)
            .filter { summary in
                !HomeTagFilterMutationSupport.contains(summary.name, in: selectedTags)
            }
    }

    var suggestedRelatedTags: [String] {
        guard !selectedTags.isEmpty else { return [] }
        let suggestionSource = suggestionAnchor.map { [$0] } ?? Array(selectedTags)
        return RoutineTagRelations.relatedTags(
            for: suggestionSource,
            rules: relatedTagRules,
            availableTags: availableTags
        )
    }

    func clearedIncludedTags() -> HomeIncludedTagMutation {
        HomeTagFilterMutationSupport.clearedIncludedTags()
    }

    func toggledIncludedTag(_ tag: String) -> HomeIncludedTagMutation {
        HomeTagFilterMutationSupport.toggledIncludedTag(
            tag,
            selectedTags: selectedTags,
            suggestionAnchor: suggestionAnchor
        )
    }

    func addedIncludedTag(_ tag: String) -> HomeIncludedTagMutation? {
        HomeTagFilterMutationSupport.addedIncludedTag(
            tag,
            selectedTags: selectedTags,
            suggestionAnchor: suggestionAnchor
        )
    }

    func toggledExcludedTag(_ tag: String, excludedTags: Set<String>) -> HomeExcludedTagMutation {
        HomeTagFilterMutationSupport.toggledExcludedTag(
            tag,
            selectedTags: selectedTags,
            excludedTags: excludedTags
        )
    }
}

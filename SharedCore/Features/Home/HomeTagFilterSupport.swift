import Foundation

struct HomeIncludedTagMutation: Equatable {
    let selectedTags: Set<String>
    let suggestionAnchor: String?
}

struct HomeExcludedTagMutation: Equatable {
    let selectedTags: Set<String>
    let excludedTags: Set<String>
}

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
                !selectedTags.contains { RoutineTag.contains($0, in: [summary.name]) }
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
        HomeIncludedTagMutation(selectedTags: [], suggestionAnchor: nil)
    }

    func toggledIncludedTag(_ tag: String) -> HomeIncludedTagMutation {
        var updatedTags = selectedTags
        var updatedAnchor = suggestionAnchor

        if updatedTags.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
            updatedTags = updatedTags.filter { !RoutineTag.contains($0, in: [tag]) }
        } else {
            updatedTags.insert(tag)
            updatedAnchor = tag
        }

        if updatedTags.isEmpty {
            updatedAnchor = nil
        }

        return HomeIncludedTagMutation(selectedTags: updatedTags, suggestionAnchor: updatedAnchor)
    }

    func addedIncludedTag(_ tag: String) -> HomeIncludedTagMutation? {
        guard !selectedTags.contains(where: { RoutineTag.contains($0, in: [tag]) }) else {
            return nil
        }

        var updatedTags = selectedTags
        updatedTags.insert(tag)
        return HomeIncludedTagMutation(selectedTags: updatedTags, suggestionAnchor: suggestionAnchor)
    }

    func toggledExcludedTag(_ tag: String, excludedTags: Set<String>) -> HomeExcludedTagMutation {
        var updatedExcludedTags = excludedTags
        var updatedSelectedTags = selectedTags

        if updatedExcludedTags.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
            updatedExcludedTags = updatedExcludedTags.filter { !RoutineTag.contains($0, in: [tag]) }
        } else {
            updatedExcludedTags.insert(tag)
            updatedSelectedTags = updatedSelectedTags.filter { !RoutineTag.contains($0, in: [tag]) }
        }

        return HomeExcludedTagMutation(
            selectedTags: updatedSelectedTags,
            excludedTags: updatedExcludedTags
        )
    }
}

import Foundation

struct HomeIncludedTagMutation: Equatable {
    let selectedTags: Set<String>
    let suggestionAnchor: String?
}

struct HomeExcludedTagMutation: Equatable {
    let selectedTags: Set<String>
    let excludedTags: Set<String>
}

enum HomeTagFilterMutationSupport {
    static func contains(_ tag: String, in selectedTags: Set<String>) -> Bool {
        selectedTags.contains { RoutineTag.contains($0, in: [tag]) }
    }

    static func availableExcludeTags(
        from availableTags: [String],
        selectedTags: Set<String>
    ) -> [String] {
        availableTags.filter { tag in
            !contains(tag, in: selectedTags)
        }
    }

    static func clearedIncludedTags() -> HomeIncludedTagMutation {
        HomeIncludedTagMutation(selectedTags: [], suggestionAnchor: nil)
    }

    static func toggledIncludedTag(
        _ tag: String,
        selectedTags: Set<String>,
        suggestionAnchor: String?
    ) -> HomeIncludedTagMutation {
        var updatedTags = selectedTags
        var updatedAnchor = suggestionAnchor

        if contains(tag, in: updatedTags) {
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

    static func addedIncludedTag(
        _ tag: String,
        selectedTags: Set<String>,
        suggestionAnchor: String?
    ) -> HomeIncludedTagMutation? {
        guard !contains(tag, in: selectedTags) else {
            return nil
        }

        var updatedTags = selectedTags
        updatedTags.insert(tag)
        return HomeIncludedTagMutation(selectedTags: updatedTags, suggestionAnchor: suggestionAnchor)
    }

    static func toggledExcludedTag(
        _ tag: String,
        selectedTags: Set<String>,
        excludedTags: Set<String>
    ) -> HomeExcludedTagMutation {
        var updatedExcludedTags = excludedTags
        var updatedSelectedTags = selectedTags

        if contains(tag, in: updatedExcludedTags) {
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

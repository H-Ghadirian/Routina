import SwiftUI

struct HomeMacStatsTagFilterSection: View {
    let availableTags: [String]
    let suggestedRelatedTags: [String]
    let availableExcludeTags: [String]
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let selectedExcludedTags: Set<String>
    let excludeTagMatchMode: RoutineTagMatchMode
    let tagCount: (String) -> Int
    let tagColor: (String) -> Color?
    let onSelectTags: (Set<String>) -> Void
    let onIncludeTagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onSelectSuggestedTag: (String) -> Void
    let onExcludeTagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onToggleExcludedTag: (String) -> Void

    var body: some View {
        HomeMacCollapsibleFilterSection(
            title: "Tags",
            summaryText: summaryText,
            systemImage: "tag.fill",
            tint: .teal
        ) {
            HomeMacTimelineTagFiltersView(
                availableTags: availableTags,
                suggestedRelatedTags: suggestedRelatedTags,
                availableExcludeTags: availableExcludeTags,
                selectedTags: selectedTags,
                includeTagMatchMode: includeTagMatchMode,
                excludeTagMatchMode: excludeTagMatchMode,
                selectedExcludedTags: selectedExcludedTags,
                tagCount: tagCount,
                tagColor: tagColor,
                onSelectTags: onSelectTags,
                onIncludeTagMatchModeChange: onIncludeTagMatchModeChange,
                onSelectSuggestedTag: onSelectSuggestedTag,
                onExcludeTagMatchModeChange: onExcludeTagMatchModeChange,
                onToggleExcludedTag: onToggleExcludedTag
            )
        }
    }

    private var summaryText: String {
        guard !selectedTags.isEmpty || !selectedExcludedTags.isEmpty else {
            return "No tag filter"
        }

        var parts: [String] = []
        if !selectedTags.isEmpty {
            parts.append("Includes \(tagList(selectedTags))")
        }
        if !selectedExcludedTags.isEmpty {
            parts.append("Excludes \(tagList(selectedExcludedTags))")
        }
        return parts.joined(separator: " · ")
    }

    private func tagList(_ tags: Set<String>) -> String {
        tags.sorted().map { "#\($0)" }.joined(separator: ", ")
    }
}

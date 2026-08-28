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
            onToggleExcludedTag: onToggleExcludedTag,
            presentation: .compactActions
        )
    }
}

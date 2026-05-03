import SwiftUI

struct HomeMacStatsSidebarView: View {
    let selectedTaskTypeFilter: StatsTaskTypeFilter
    let onSelectTaskTypeFilter: (StatsTaskTypeFilter) -> Void
    let selectedRange: DoneChartRange
    let onSelectRange: (DoneChartRange) -> Void
    @Binding var advancedQuery: String
    let queryOptions: HomeAdvancedQueryOptions
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let importanceUrgencySummary: String
    let allTags: [String]
    let tagSummaries: [RoutineTagSummary]
    let suggestedRelatedTags: [String]
    let taskCountForSelectedTypeFilter: Int
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let onSelectTags: (Set<String>) -> Void
    let onIncludeTagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onSelectSuggestedTag: (String) -> Void
    let selectedExcludedTags: Set<String>
    let excludeTagMatchMode: RoutineTagMatchMode
    let onExcludeTagMatchModeChange: (RoutineTagMatchMode) -> Void
    let availableExcludeTags: [String]
    let excludedTagSummary: String
    let tagSelectionSummary: String
    let tagCount: (String) -> Int
    let onToggleExcludedTag: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HomeMacStatsQuerySection(
                    advancedQuery: $advancedQuery,
                    queryOptions: queryOptions
                )

                HomeMacStatsTaskTypeSection(
                    selectedTaskTypeFilter: selectedTaskTypeFilter,
                    onSelectTaskTypeFilter: onSelectTaskTypeFilter
                )

                HomeMacStatsRangeSection(
                    selectedRange: selectedRange,
                    onSelectRange: onSelectRange
                )

                HomeMacStatsImportanceUrgencySection(
                    selectedFilter: $selectedImportanceUrgencyFilter,
                    summaryText: importanceUrgencySummary
                )

                if !allTags.isEmpty {
                    HomeMacStatsIncludedTagSection(
                        tagSummaries: tagSummaries,
                        taskCountForSelectedTypeFilter: taskCountForSelectedTypeFilter,
                        selectedTags: selectedTags,
                        includeTagMatchMode: includeTagMatchMode,
                        tagSelectionSummary: tagSelectionSummary,
                        tagCount: tagCount,
                        onSelectTags: onSelectTags,
                        onIncludeTagMatchModeChange: onIncludeTagMatchModeChange
                    )

                    HomeMacStatsSuggestedRelatedTagSection(
                        suggestedRelatedTags: suggestedRelatedTags,
                        tagSummaries: tagSummaries,
                        tagCount: tagCount,
                        onSelectSuggestedTag: onSelectSuggestedTag
                    )

                    HomeMacStatsExcludedTagSection(
                        tagSummaries: tagSummaries,
                        selectedExcludedTags: selectedExcludedTags,
                        excludeTagMatchMode: excludeTagMatchMode,
                        availableExcludeTags: availableExcludeTags,
                        excludedTagSummary: excludedTagSummary,
                        tagCount: tagCount,
                        onToggleExcludedTag: onToggleExcludedTag,
                        onExcludeTagMatchModeChange: onExcludeTagMatchModeChange
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

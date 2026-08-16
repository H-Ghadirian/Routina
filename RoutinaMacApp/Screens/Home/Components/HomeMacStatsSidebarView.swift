import SwiftUI

struct HomeMacStatsSidebarView: View {
    @AppStorage(
        UserDefaultBoolValueKey.appSettingFilterQuerySectionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var showsFilterQuerySections = false

    let selectedTaskTypeFilter: StatsTaskTypeFilter
    let onSelectTaskTypeFilter: (StatsTaskTypeFilter) -> Void
    let availableDashboardScopes: [StatsDashboardScope]
    let selectedDashboardScope: StatsDashboardScope
    let onSelectDashboardScope: (StatsDashboardScope) -> Void
    let selectedRange: DoneChartRange
    let onSelectRange: (DoneChartRange) -> Void
    @Binding var advancedQuery: String
    let queryOptions: HomeAdvancedQueryOptions
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
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
    let availableFlags: [String]
    let selectedFlags: Set<String>
    let includeFlagMatchMode: RoutineTagMatchMode
    let excludedFlags: Set<String>
    let excludeFlagMatchMode: RoutineTagMatchMode
    let onIncludeFlagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onExcludeFlagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onToggleIncludedFlag: (String) -> Void
    let onToggleExcludedFlag: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if showsFilterQuerySections {
                    HomeMacStatsQuerySection(
                        advancedQuery: $advancedQuery,
                        queryOptions: queryOptions
                    )
                }

                if availableDashboardScopes.count > 1 {
                    HomeMacStatsDashboardScopeSection(
                        selectedDashboardScope: selectedDashboardScope,
                        availableDashboardScopes: availableDashboardScopes,
                        onSelectDashboardScope: onSelectDashboardScope
                    )
                }

                HomeMacStatsTaskTypeSection(
                    selectedTaskTypeFilter: selectedTaskTypeFilter,
                    onSelectTaskTypeFilter: onSelectTaskTypeFilter
                )

                HomeMacStatsRangeSection(
                    selectedRange: selectedRange,
                    onSelectRange: onSelectRange
                )

                HomeMacStatsImportanceFilterSection(
                    selectedFilter: $selectedImportanceUrgencyFilter
                )

                HomeMacStatsUrgencyFilterSection(
                    selectedFilter: $selectedImportanceUrgencyFilter
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

                if !availableFlags.isEmpty {
                    HomeMacStatsFlagFilterSection(
                        availableFlags: availableFlags,
                        selectedFlags: selectedFlags,
                        includeFlagMatchMode: includeFlagMatchMode,
                        excludedFlags: excludedFlags,
                        excludeFlagMatchMode: excludeFlagMatchMode,
                        onIncludeFlagMatchModeChange: onIncludeFlagMatchModeChange,
                        onExcludeFlagMatchModeChange: onExcludeFlagMatchModeChange,
                        onToggleIncludedFlag: onToggleIncludedFlag,
                        onToggleExcludedFlag: onToggleExcludedFlag
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

import SwiftUI

struct HomeMacStatsSidebarView: View {
    @AppStorage(
        UserDefaultBoolValueKey.appSettingFilterQuerySectionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var showsFilterQuerySections = false
    @State private var expandedSingleChoiceSection: HomeMacStatsSingleChoiceSection?

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
                        onSelectDashboardScope: onSelectDashboardScope,
                        isExpanded: expansionBinding(for: .scope),
                        onSelectionComplete: { collapse(.scope) }
                    )
                }

                HomeMacStatsTaskTypeSection(
                    selectedTaskTypeFilter: selectedTaskTypeFilter,
                    onSelectTaskTypeFilter: onSelectTaskTypeFilter,
                    isExpanded: expansionBinding(for: .taskType),
                    onSelectionComplete: { collapse(.taskType) }
                )

                HomeMacStatsRangeSection(
                    selectedRange: selectedRange,
                    onSelectRange: onSelectRange,
                    isExpanded: expansionBinding(for: .timeRange),
                    onPresetSelectionComplete: { collapse(.timeRange) }
                )

                HomeMacStatsImportanceFilterSection(
                    selectedFilter: $selectedImportanceUrgencyFilter,
                    isExpanded: expansionBinding(for: .importance),
                    onSelectionComplete: { collapse(.importance) }
                )

                HomeMacStatsUrgencyFilterSection(
                    selectedFilter: $selectedImportanceUrgencyFilter,
                    isExpanded: expansionBinding(for: .urgency),
                    onSelectionComplete: { collapse(.urgency) }
                )

                if !allTags.isEmpty {
                    HomeMacStatsTagFilterSection(
                        availableTags: allTags,
                        suggestedRelatedTags: suggestedRelatedTags,
                        availableExcludeTags: availableExcludeTags,
                        selectedTags: selectedTags,
                        includeTagMatchMode: includeTagMatchMode,
                        selectedExcludedTags: selectedExcludedTags,
                        excludeTagMatchMode: excludeTagMatchMode,
                        tagCount: tagCount,
                        tagColor: tagColor,
                        onSelectTags: onSelectTags,
                        onIncludeTagMatchModeChange: onIncludeTagMatchModeChange,
                        onSelectSuggestedTag: onSelectSuggestedTag,
                        onExcludeTagMatchModeChange: onExcludeTagMatchModeChange,
                        onToggleExcludedTag: onToggleExcludedTag
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

    private func expansionBinding(
        for section: HomeMacStatsSingleChoiceSection
    ) -> Binding<Bool> {
        Binding(
            get: { expandedSingleChoiceSection == section },
            set: { isExpanded in
                expandedSingleChoiceSection = isExpanded ? section : nil
            }
        )
    }

    private func collapse(_ section: HomeMacStatsSingleChoiceSection) {
        guard expandedSingleChoiceSection == section else { return }
        expandedSingleChoiceSection = nil
    }
}

private enum HomeMacStatsSingleChoiceSection: Hashable {
    case scope
    case taskType
    case timeRange
    case importance
    case urgency
}

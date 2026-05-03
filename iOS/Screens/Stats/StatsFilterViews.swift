import SwiftUI

struct StatsSidebarContent: View {
    let selectedRange: DoneChartRange
    let onSelectRange: (DoneChartRange) -> Void
    let showsTaskTypeFilter: Bool
    let selectedTaskTypeFilter: StatsTaskTypeFilter
    let filteredTaskCount: Int
    let onSelectTaskTypeFilter: (StatsTaskTypeFilter) -> Void
    let activeSheetFilterCount: Int
    let hasActiveSheetFilters: Bool
    let hasActiveFilters: Bool
    let onShowFilters: () -> Void
    let onClearFilters: () -> Void
    let isGitFeaturesEnabled: Bool
    let gitHubConnection: GitHubConnectionStatus
    let isGitHubStatsLoading: Bool
    let onRefreshGitHubStats: () -> Void

    var body: some View {
        List {
            Section("Range") {
                ForEach(DoneChartRange.allCases) { range in
                    sidebarButton(
                        title: range.rawValue,
                        subtitle: range.periodDescription,
                        systemImage: selectedRange == range ? "checkmark.circle.fill" : "circle"
                    ) {
                        onSelectRange(range)
                    }
                    .foregroundStyle(selectedRange == range ? Color.accentColor : Color.primary)
                }
            }

            if showsTaskTypeFilter {
                Section("Type") {
                    ForEach(StatsTaskTypeFilter.allCases) { filter in
                        sidebarButton(
                            title: filter.rawValue,
                            subtitle: taskTypeSubtitle(for: filter),
                            systemImage: filter.iosStatsIconName
                        ) {
                            onSelectTaskTypeFilter(filter)
                        }
                        .foregroundStyle(selectedTaskTypeFilter == filter ? Color.accentColor : Color.primary)
                    }
                }
            }

            Section("Filters") {
                Button(action: onShowFilters) {
                    Label(
                        activeSheetFilterCount == 0 ? "Filter Stats" : "\(activeSheetFilterCount) active filters",
                        systemImage: hasActiveSheetFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
                    )
                }

                if hasActiveFilters {
                    Button(role: .destructive, action: onClearFilters) {
                        Label("Clear All", systemImage: "xmark.circle")
                    }
                }
            }

            if isGitFeaturesEnabled {
                Section("Git") {
                    HStack {
                        Label("GitHub", systemImage: "arrow.triangle.branch")
                        Spacer()
                        Text(gitHubConnection.isConnected ? "Live" : "Off")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: onRefreshGitHubStats) {
                        Label("Refresh Activity", systemImage: "arrow.clockwise")
                    }
                    .disabled(!gitHubConnection.isConnected || isGitHubStatsLoading)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Stats")
    }

    private func sidebarButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }
        }
        .buttonStyle(.plain)
    }

    private func taskTypeSubtitle(for filter: StatsTaskTypeFilter) -> String {
        switch filter {
        case .all:
            return "\(filteredTaskCount) matching items"
        case .routines:
            return "Routine completions"
        case .todos:
            return "Todo completions"
        }
    }
}

struct StatsActiveFilterChipBar: View {
    let selectedTaskTypeFilter: StatsTaskTypeFilter
    let advancedQuery: String
    let selectedTags: Set<String>
    let selectedImportanceUrgencyFilterLabel: String?
    let excludedTags: Set<String>
    let onClearAll: () -> Void
    let onClearTaskType: () -> Void
    let onClearAdvancedQuery: () -> Void
    let onRemoveSelectedTag: (String) -> Void
    let onClearImportanceUrgency: () -> Void
    let onRemoveExcludedTag: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("Clear All", action: onClearAll)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)

                if selectedTaskTypeFilter != .all {
                    compactFilterChip(
                        title: selectedTaskTypeFilter.rawValue,
                        systemImage: selectedTaskTypeFilter.iosStatsIconName,
                        action: onClearTaskType
                    )
                }

                let trimmedAdvancedQuery = advancedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedAdvancedQuery.isEmpty {
                    compactFilterChip(title: trimmedAdvancedQuery, systemImage: "magnifyingglass", action: onClearAdvancedQuery)
                }

                ForEach(selectedTags.sorted(), id: \.self) { tag in
                    compactFilterChip(title: "#\(tag)") {
                        onRemoveSelectedTag(tag)
                    }
                }

                if let selectedImportanceUrgencyFilterLabel {
                    compactFilterChip(title: selectedImportanceUrgencyFilterLabel, action: onClearImportanceUrgency)
                }

                ForEach(excludedTags.sorted(), id: \.self) { tag in
                    compactFilterChip(title: "not #\(tag)", tintColor: .red) {
                        onRemoveExcludedTag(tag)
                    }
                }
            }
        }
    }

    private func compactFilterChip(
        title: String,
        systemImage: String? = nil,
        tintColor: Color = .secondary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2)
                }

                Text(title)
                    .font(.caption.weight(.medium))

                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .foregroundStyle(tintColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(tintColor.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

struct StatsFilterButton: View {
    let hasActiveFilters: Bool
    let onShowFilters: () -> Void

    var body: some View {
        Button(action: onShowFilters) {
            Image(
                systemName: hasActiveFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .foregroundStyle(hasActiveFilters ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filters")
    }
}

struct StatsFiltersSheet: View {
    @Binding var advancedQuery: String
    let advancedQueryOptions: HomeAdvancedQueryOptions
    let showsTaskTypeFilter: Bool
    @Binding var taskTypeFilter: StatsTaskTypeFilter
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let importanceUrgencyFilterSummary: String
    let tagRuleBindings: HomeTagRuleBindings
    let tagRuleData: HomeTagFilterData
    let tagRuleActions: HomeTagFilterActions
    let hasActiveFilters: Bool
    let selectedTags: Set<String>
    let availableTags: [String]
    let onClearFilters: () -> Void
    let onClose: () -> Void
    let onSelectedTagsPruned: (Set<String>) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Query") {
                    HomeAdvancedQueryBuilder(query: $advancedQuery, options: advancedQueryOptions)
                }

                if showsTaskTypeFilter {
                    Section("Type") {
                        Picker("Type", selection: $taskTypeFilter) {
                            ForEach(StatsTaskTypeFilter.allCases) { filter in
                                Label(filter.rawValue, systemImage: filter.iosStatsIconName)
                                    .tag(filter)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }

                HomeFiltersImportanceUrgencySection(
                    selectedImportanceUrgencyFilter: $selectedImportanceUrgencyFilter,
                    summary: importanceUrgencyFilterSummary
                )

                HomeFiltersTagRulesSection(
                    bindings: tagRuleBindings,
                    data: tagRuleData,
                    actions: tagRuleActions,
                    labels: HomeTagFilterSectionLabels(
                        includedTitle: "Show stats with",
                        includedPickerTitle: "Show stats with",
                        excludedTitle: "Hide stats with",
                        excludedPickerTitle: "Hide stats with"
                    )
                )

                HomeFiltersClearSection(
                    hasActiveOptionalFilters: hasActiveFilters,
                    onClearOptionalFilters: onClearFilters
                )
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onClose)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: availableTags) { _, newValue in
            let selected = selectedTags.filter { RoutineTag.contains($0, in: newValue) }
            onSelectedTagsPruned(selected)
        }
    }
}

extension StatsTaskTypeFilter {
    var iosStatsIconName: String {
        switch self {
        case .all:
            return "square.grid.2x2"
        case .routines:
            return "repeat"
        case .todos:
            return "checklist"
        }
    }
}

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
                            title: filter.title,
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
            return "Routine activity"
        case .todos:
            return "Todo activity"
        }
    }
}

struct StatsActiveFilterChipBar: View {
    let selectedTaskTypeFilter: StatsTaskTypeFilter
    let advancedQuery: String
    let selectedTags: Set<String>
    let selectedImportanceUrgencyFilterLabel: String?
    let excludedTags: Set<String>
    let selectedFlags: Set<String>
    let excludedFlags: Set<String>
    let onClearAll: () -> Void
    let onClearTaskType: () -> Void
    let onClearAdvancedQuery: () -> Void
    let onRemoveSelectedTag: (String) -> Void
    let onClearImportanceUrgency: () -> Void
    let onRemoveExcludedTag: (String) -> Void
    let onRemoveSelectedFlag: (String) -> Void
    let onRemoveExcludedFlag: (String) -> Void

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

                ForEach(selectedFlags.sorted(), id: \.self) { flag in
                    compactFilterChip(title: "flag: \(flag)", systemImage: "flag.fill") {
                        onRemoveSelectedFlag(flag)
                    }
                }

                ForEach(excludedFlags.sorted(), id: \.self) { flag in
                    compactFilterChip(title: "not flag: \(flag)", systemImage: "flag.fill", tintColor: .red) {
                        onRemoveExcludedFlag(flag)
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
            .routinaGlassPill(tint: tintColor, tintOpacity: 0.12, interactive: true)
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

struct StatsFiltersSheet<TagPicker: View>: View {
    @Binding var advancedQuery: String
    let advancedQueryOptions: HomeAdvancedQueryOptions
    let showsTaskTypeFilter: Bool
    @Binding var taskTypeFilter: StatsTaskTypeFilter
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let importanceUrgencyFilterSummary: String
    let hasActiveFilters: Bool
    @Binding var selectedTags: Set<String>
    @Binding var excludedTags: Set<String>
    @Binding var selectedFlags: Set<String>
    @Binding var includeFlagMatchMode: RoutineTagMatchMode
    @Binding var excludedFlags: Set<String>
    @Binding var excludeFlagMatchMode: RoutineTagMatchMode
    let availableTags: [String]
    let availableFlags: [String]
    let tagPicker: () -> TagPicker
    let onClearFilters: () -> Void
    let onClose: () -> Void
    let onSelectedTagsPruned: (Set<String>) -> Void

    @AppStorage(
        UserDefaultBoolValueKey.appSettingFilterQuerySectionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var showsFilterQuerySections = false

    var body: some View {
        NavigationStack {
            List {
                if showsFilterQuerySections {
                    HomeFiltersPickerEntry(
                        sectionTitle: "Query",
                        title: "Advanced query",
                        systemImage: "magnifyingglass",
                        value: advancedQuery.isEmpty ? "None" : "Active",
                        pickerTitle: "Advanced Query"
                    ) {
                        Section {
                            HomeAdvancedQueryBuilder(query: $advancedQuery, options: advancedQueryOptions)
                        }
                    }
                }

                if showsTaskTypeFilter {
                    HomeFiltersPickerEntry(
                        sectionTitle: "Type",
                        title: "Task type",
                        systemImage: "checklist",
                        value: taskTypeFilter.title,
                        pickerTitle: "Task Type"
                    ) {
                        Section {
                            Picker("Task type", selection: $taskTypeFilter) {
                                ForEach(StatsTaskTypeFilter.allCases) { filter in
                                    Label(filter.title, systemImage: filter.iosStatsIconName)
                                        .tag(filter)
                                }
                            }
                            .pickerStyle(.inline)
                        }
                    }
                }

                HomeFiltersImportanceUrgencySection(
                    selectedImportanceUrgencyFilter: $selectedImportanceUrgencyFilter,
                    summary: importanceUrgencyFilterSummary
                )

                HomeFiltersTagFilterEntrySection(
                    selectedTags: $selectedTags,
                    excludedTags: $excludedTags,
                    tagPicker: tagPicker
                )

                if !availableFlags.isEmpty {
                    HomeFiltersPickerEntry(
                        sectionTitle: "Flags",
                        title: "Flags",
                        systemImage: "flag.fill",
                        value: flagSelectionSummary,
                        pickerTitle: "Flags"
                    ) {
                        StatsFlagFilterPicker(
                            selectedFlags: $selectedFlags,
                            includeFlagMatchMode: $includeFlagMatchMode,
                            excludedFlags: $excludedFlags,
                            excludeFlagMatchMode: $excludeFlagMatchMode,
                            availableFlags: availableFlags
                        )
                    }
                }

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

    private var flagSelectionSummary: String {
        let count = selectedFlags.count + excludedFlags.count
        guard count > 0 else {
            return "\(availableFlags.count) \(availableFlags.count == 1 ? "flag" : "flags") available"
        }
        return "\(count) active \(count == 1 ? "filter" : "filters")"
    }
}

private struct StatsFlagFilterPicker: View {
    @Binding var selectedFlags: Set<String>
    @Binding var includeFlagMatchMode: RoutineTagMatchMode
    @Binding var excludedFlags: Set<String>
    @Binding var excludeFlagMatchMode: RoutineTagMatchMode
    let availableFlags: [String]

    var body: some View {
        Section {
            Picker("Show stats with", selection: $includeFlagMatchMode) {
                ForEach(RoutineTagMatchMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if selectedFlags.isEmpty {
                Text("All flags included")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedSelectedFlags, id: \.self) { flag in
                    Button("Remove \(flag)") {
                        apply(StatsFlagFilterMutationSupport.toggledIncluded(
                            flag,
                            selectedFlags: selectedFlags,
                            excludedFlags: excludedFlags
                        ))
                    }
                }
            }
        } header: {
            Text("Show stats with")
        } footer: {
            Text("Only task activity with every selected Flag or any selected Flag is included.")
        }

        Section {
            Picker("Hide stats with", selection: $excludeFlagMatchMode) {
                ForEach(RoutineTagMatchMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if excludedFlags.isEmpty {
                Text("No flags excluded")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedExcludedFlags, id: \.self) { flag in
                    Button("Stop hiding \(flag)") {
                        apply(StatsFlagFilterMutationSupport.toggledExcluded(
                            flag,
                            selectedFlags: selectedFlags,
                            excludedFlags: excludedFlags
                        ))
                    }
                }
            }
        } header: {
            Text("Hide stats with")
        } footer: {
            Text("Exclude every task with any selected Flag, or only tasks that have all selected Flags.")
        }

        Section {
            ForEach(availableFlags, id: \.self) { flag in
                Menu {
                    Button(isIncluded(flag) ? "Stop showing \(flag)" : "Show stats with \(flag)") {
                        apply(StatsFlagFilterMutationSupport.toggledIncluded(
                            flag,
                            selectedFlags: selectedFlags,
                            excludedFlags: excludedFlags
                        ))
                    }
                    Button(isExcluded(flag) ? "Stop hiding \(flag)" : "Hide stats with \(flag)") {
                        apply(StatsFlagFilterMutationSupport.toggledExcluded(
                            flag,
                            selectedFlags: selectedFlags,
                            excludedFlags: excludedFlags
                        ))
                    }
                    if isIncluded(flag) || isExcluded(flag) {
                        Divider()
                        Button("Clear \(flag) filter", role: .destructive) {
                            if isIncluded(flag) {
                                apply(StatsFlagFilterMutationSupport.toggledIncluded(
                                    flag,
                                    selectedFlags: selectedFlags,
                                    excludedFlags: excludedFlags
                                ))
                            } else {
                                apply(StatsFlagFilterMutationSupport.toggledExcluded(
                                    flag,
                                    selectedFlags: selectedFlags,
                                    excludedFlags: excludedFlags
                                ))
                            }
                        }
                    }
                } label: {
                    Label(flag, systemImage: statusIcon(for: flag))
                }
            }
        } header: {
            Text("All Flags")
        }
    }

    private var sortedSelectedFlags: [String] {
        selectedFlags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var sortedExcludedFlags: [String] {
        excludedFlags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func isIncluded(_ flag: String) -> Bool {
        StatsFlagFilterMutationSupport.contains(flag, in: selectedFlags)
    }

    private func isExcluded(_ flag: String) -> Bool {
        StatsFlagFilterMutationSupport.contains(flag, in: excludedFlags)
    }

    private func statusIcon(for flag: String) -> String {
        if isIncluded(flag) { return "checkmark.circle.fill" }
        if isExcluded(flag) { return "minus.circle.fill" }
        return "flag"
    }

    private func apply(_ mutation: StatsFlagFilterMutation) {
        selectedFlags = mutation.selectedFlags
        excludedFlags = mutation.excludedFlags
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

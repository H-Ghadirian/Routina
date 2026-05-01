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
                statsQuerySection
                statsTaskTypeSection
                statsRangeSection
                statsImportanceUrgencySection

                if !allTags.isEmpty {
                    statsTagSection
                    statsSuggestedRelatedTagSection
                    statsExcludedTagSection
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statsQuerySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Query")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HomeAdvancedQueryBuilder(
                query: $advancedQuery,
                usesFlowLayout: true,
                options: queryOptions
            )
        }
    }

    private var statsTaskTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Show")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(StatsTaskTypeFilter.allCases) { filter in
                    statsTaskTypeChip(filter)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statsRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Range")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(DoneChartRange.allCases) { range in
                    statsRangeChip(range)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statsImportanceUrgencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Importance & Urgency")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HomeMacImportanceUrgencyMatrixView(
                selectedFilter: $selectedImportanceUrgencyFilter,
                summaryText: importanceUrgencySummary
            )
            .padding(.horizontal, 4)
        }
    }

    private var statsTagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Show stats with")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Text(tagSelectionSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Picker("Show stats with", selection: Binding(
                get: { includeTagMatchMode },
                set: { newValue in onIncludeTagMatchModeChange(newValue) }
            )) {
                ForEach(RoutineTagMatchMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                if selectedTags.isEmpty {
                    HomeMacTagChipView(
                        title: "All Tags",
                        count: taskCountForSelectedTypeFilter,
                        systemImage: "tag.slash.fill",
                        isSelected: true
                    ) {
                        onSelectTags([])
                    }
                } else {
                    ForEach(selectedTags.sorted(), id: \.self) { tag in
                        let color = tagColor(for: tag)
                        HomeMacTagChipView(
                            title: "#\(tag)",
                            count: tagCount(tag),
                            systemImage: "tag.fill",
                            isSelected: true,
                            selectedColor: color ?? .accentColor,
                            unselectedColor: color
                        ) {
                            var newSelection = selectedTags
                            newSelection = newSelection.filter { !RoutineTag.contains($0, in: [tag]) }
                            onSelectTags(newSelection)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Add more")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(tagSummaries.filter { summary in
                    !selectedTags.contains { RoutineTag.contains($0, in: [summary.name]) }
                }) { summary in
                    HomeMacTagChipView(
                        title: "#\(summary.name)",
                        count: summary.linkedRoutineCount,
                        systemImage: "tag.fill",
                        isSelected: false,
                        selectedColor: summary.displayColor ?? .accentColor,
                        unselectedColor: summary.displayColor
                    ) {
                        var newSelection = selectedTags
                        newSelection.insert(summary.name)
                        onSelectTags(newSelection)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var statsSuggestedRelatedTagSection: some View {
        if !suggestedRelatedTags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Suggested Related Tags")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(suggestedRelatedTags, id: \.self) { tag in
                        let color = tagColor(for: tag)
                        HomeMacTagChipView(
                            title: "#\(tag)",
                            count: tagCount(tag),
                            systemImage: "tag.fill",
                            isSelected: false,
                            selectedColor: color ?? .accentColor,
                            unselectedColor: color
                        ) {
                            onSelectSuggestedTag(tag)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var statsExcludedTagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hide stats with")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Text(excludedTagSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Picker("Hide stats with", selection: Binding(
                get: { excludeTagMatchMode },
                set: { newValue in onExcludeTagMatchModeChange(newValue) }
            )) {
                ForEach(RoutineTagMatchMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                if selectedExcludedTags.isEmpty {
                    Text("No hidden tags")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(selectedExcludedTags.sorted(), id: \.self) { tag in
                        HomeMacTagChipView(
                            title: "#\(tag)",
                            count: tagCount(tag),
                            systemImage: "tag.slash.fill",
                            isSelected: true,
                            selectedColor: .red
                        ) {
                            onToggleExcludedTag(tag)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Add tags to hide")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(availableExcludeTags.filter { tag in
                    !selectedExcludedTags.contains { RoutineTag.contains($0, in: [tag]) }
                }, id: \.self) { tag in
                    let color = tagColor(for: tag)
                    HomeMacTagChipView(
                        title: "#\(tag)",
                        count: tagCount(tag),
                        systemImage: "tag.slash.fill",
                        isSelected: false,
                        selectedColor: .red,
                        unselectedColor: color
                    ) {
                        onToggleExcludedTag(tag)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func statsTaskTypeChip(_ filter: StatsTaskTypeFilter) -> some View {
        Button {
            onSelectTaskTypeFilter(filter)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: statsTaskTypeIcon(for: filter))
                    .font(.caption.weight(.semibold))

                Text(filter.rawValue)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(selectedTaskTypeFilter == filter ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selectedTaskTypeFilter == filter ? Color.accentColor : Color.secondary.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(selectedTaskTypeFilter == filter ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statsTaskTypeIcon(for filter: StatsTaskTypeFilter) -> String {
        switch filter {
        case .all: return "square.grid.2x2"
        case .routines: return "repeat"
        case .todos: return "checklist"
        }
    }

    @ViewBuilder
    private func statsRangeChip(_ range: DoneChartRange) -> some View {
        Button {
            onSelectRange(range)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: statsRangeIcon(for: range))
                    .font(.caption.weight(.semibold))

                Text(range.rawValue)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(selectedRange == range ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selectedRange == range ? Color.accentColor : Color.secondary.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(selectedRange == range ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statsRangeIcon(for range: DoneChartRange) -> String {
        switch range {
        case .today: return "calendar.badge.checkmark"
        case .week: return "calendar.badge.clock"
        case .month: return "calendar"
        case .year: return "calendar.badge.plus"
        }
    }

    private func tagColor(for tag: String) -> Color? {
        tagSummaries.first { RoutineTag.contains($0.name, in: [tag]) }?.displayColor
    }
}

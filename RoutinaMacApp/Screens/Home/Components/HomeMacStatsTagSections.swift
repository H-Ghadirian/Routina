import SwiftUI

struct HomeMacStatsIncludedTagSection: View {
    let tagSummaries: [RoutineTagSummary]
    let taskCountForSelectedTypeFilter: Int
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let tagSelectionSummary: String
    let tagCount: (String) -> Int
    let onSelectTags: (Set<String>) -> Void
    let onIncludeTagMatchModeChange: (RoutineTagMatchMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeMacStatsSectionTitle("Show stats with")

            Text(tagSelectionSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Picker("Show stats with", selection: Binding(
                get: { includeTagMatchMode },
                set: { onIncludeTagMatchModeChange($0) }
            )) {
                ForEach(RoutineTagMatchMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            selectedTagsView

            HomeMacStatsSectionTitle("Add more")

            availableTagsView
        }
    }

    @ViewBuilder
    private var selectedTagsView: some View {
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
    }

    private var availableTagsView: some View {
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

    private func tagColor(for tag: String) -> Color? {
        tagSummaries.first { RoutineTag.contains($0.name, in: [tag]) }?.displayColor
    }
}

struct HomeMacStatsSuggestedRelatedTagSection: View {
    let suggestedRelatedTags: [String]
    let tagSummaries: [RoutineTagSummary]
    let tagCount: (String) -> Int
    let onSelectSuggestedTag: (String) -> Void

    @ViewBuilder
    var body: some View {
        if !suggestedRelatedTags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HomeMacStatsSectionTitle("Suggested Related Tags")

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

    private func tagColor(for tag: String) -> Color? {
        tagSummaries.first { RoutineTag.contains($0.name, in: [tag]) }?.displayColor
    }
}

struct HomeMacStatsExcludedTagSection: View {
    let tagSummaries: [RoutineTagSummary]
    let selectedExcludedTags: Set<String>
    let excludeTagMatchMode: RoutineTagMatchMode
    let availableExcludeTags: [String]
    let excludedTagSummary: String
    let tagCount: (String) -> Int
    let onToggleExcludedTag: (String) -> Void
    let onExcludeTagMatchModeChange: (RoutineTagMatchMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeMacStatsSectionTitle("Hide stats with")

            Text(excludedTagSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Picker("Hide stats with", selection: Binding(
                get: { excludeTagMatchMode },
                set: { onExcludeTagMatchModeChange($0) }
            )) {
                ForEach(RoutineTagMatchMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            selectedExcludedTagsView

            HomeMacStatsSectionTitle("Add tags to hide")

            availableExcludedTagsView
        }
    }

    @ViewBuilder
    private var selectedExcludedTagsView: some View {
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
    }

    private var availableExcludedTagsView: some View {
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

    private func tagColor(for tag: String) -> Color? {
        tagSummaries.first { RoutineTag.contains($0.name, in: [tag]) }?.displayColor
    }
}

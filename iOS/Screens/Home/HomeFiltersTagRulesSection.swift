import SwiftUI

struct HomeFiltersTagRulesSection: View {
    @Binding var includeTagMatchMode: RoutineTagMatchMode
    @Binding var excludeTagMatchMode: RoutineTagMatchMode
    let selectedTags: Set<String>
    let excludedTags: Set<String>
    let tagSummaries: [RoutineTagSummary]
    let allTagTaskCount: Int
    let suggestedRelatedTags: [String]
    let availableExcludeTagSummaries: [RoutineTagSummary]
    let onResetIncludedTags: () -> Void
    let onToggleIncludedTag: (String) -> Void
    let onAddIncludedTag: (String) -> Void
    let onToggleExcludedTag: (String) -> Void
    let isIncludedTagSelected: (String) -> Bool

    @ViewBuilder
    var body: some View {
        if !tagSummaries.isEmpty {
            Section("Tag Rules") {
                HomeIncludedTagsFilterSection(
                    includeTagMatchMode: $includeTagMatchMode,
                    selectedTags: selectedTags,
                    tagSummaries: tagSummaries,
                    allTagTaskCount: allTagTaskCount,
                    suggestedRelatedTags: suggestedRelatedTags,
                    onResetIncludedTags: onResetIncludedTags,
                    onToggleIncludedTag: onToggleIncludedTag,
                    onAddIncludedTag: onAddIncludedTag,
                    isIncludedTagSelected: isIncludedTagSelected
                )

                HomeExcludedTagsFilterSection(
                    excludeTagMatchMode: $excludeTagMatchMode,
                    excludedTags: excludedTags,
                    availableExcludeTagSummaries: availableExcludeTagSummaries,
                    onToggleExcludedTag: onToggleExcludedTag
                )
            }
        }
    }
}

private struct HomeIncludedTagsFilterSection: View {
    @Binding var includeTagMatchMode: RoutineTagMatchMode
    let selectedTags: Set<String>
    let tagSummaries: [RoutineTagSummary]
    let allTagTaskCount: Int
    let suggestedRelatedTags: [String]
    let onResetIncludedTags: () -> Void
    let onToggleIncludedTag: (String) -> Void
    let onAddIncludedTag: (String) -> Void
    let isIncludedTagSelected: (String) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Show tasks with")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Show tasks with", selection: $includeTagMatchMode) {
                    ForEach(RoutineTagMatchMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }

            selectedIncludedTags
            suggestedTags
            addIncludedTags
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var selectedIncludedTags: some View {
        HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            if selectedTags.isEmpty {
                HomeFilterChipButton(title: "All Tags \(allTagTaskCount)", isSelected: true) {
                    onResetIncludedTags()
                }
            } else {
                ForEach(selectedTags.sorted(), id: \.self) { tag in
                    HomeFilterChipButton(title: "#\(tag)", isSelected: true) {
                        onToggleIncludedTag(tag)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var suggestedTags: some View {
        if !suggestedRelatedTags.isEmpty {
            Text("Suggested")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(suggestedRelatedTags, id: \.self) { tag in
                    HomeFilterChipButton(title: "#\(tag)", isSelected: false) {
                        onAddIncludedTag(tag)
                    }
                }
            }
        }
    }

    private var addIncludedTags: some View {
        Group {
            Text("Add more")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(tagSummaries.filter { !isIncludedTagSelected($0.name) }) { summary in
                    HomeFilterChipButton(
                        title: "#\(summary.name) \(summary.linkedRoutineCount)",
                        isSelected: false
                    ) {
                        onToggleIncludedTag(summary.name)
                    }
                }
            }
        }
    }
}

private struct HomeExcludedTagsFilterSection: View {
    @Binding var excludeTagMatchMode: RoutineTagMatchMode
    let excludedTags: Set<String>
    let availableExcludeTagSummaries: [RoutineTagSummary]
    let onToggleExcludedTag: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Hide tasks with")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Hide tasks with", selection: $excludeTagMatchMode) {
                    ForEach(RoutineTagMatchMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }

            selectedExcludedTags
            availableExcludedTags
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var selectedExcludedTags: some View {
        HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            if excludedTags.isEmpty {
                Text("No hidden tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(excludedTags.sorted(), id: \.self) { tag in
                    HomeFilterChipButton(
                        title: "#\(tag)",
                        isSelected: true,
                        selectedColor: .red
                    ) {
                        onToggleExcludedTag(tag)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var availableExcludedTags: some View {
        if !availableExcludeTagSummaries.isEmpty {
            Text("Add tags to hide")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(availableExcludeTagSummaries.filter { summary in
                    !excludedTags.contains { RoutineTag.contains($0, in: [summary.name]) }
                }) { summary in
                    HomeFilterChipButton(
                        title: "#\(summary.name) \(summary.linkedRoutineCount)",
                        isSelected: false,
                        selectedColor: .red
                    ) {
                        onToggleExcludedTag(summary.name)
                    }
                }
            }
        }
    }
}

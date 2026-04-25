import SwiftUI

struct HomeMacRoutineTagFiltersView: View {
    @Binding var includeTagMatchMode: RoutineTagMatchMode
    @Binding var excludeTagMatchMode: RoutineTagMatchMode
    let selectedTags: Set<String>
    let excludedTags: Set<String>
    let tagSummaries: [RoutineTagSummary]
    let allTagTaskCount: Int
    let suggestedRelatedTags: [String]
    let availableExcludeTagSummaries: [RoutineTagSummary]
    let onShowAllTags: () -> Void
    let onToggleIncludedTag: (String) -> Void
    let onAddIncludedTag: (String) -> Void
    let onToggleExcludedTag: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            includedTagsSection
            suggestedTagsSection
            addIncludedTagsSection
            excludedTagsSection
        }
    }

    private var includedTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Show tasks with")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Show tasks with", selection: $includeTagMatchMode) {
                ForEach(RoutineTagMatchMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                if selectedTags.isEmpty {
                    HomeMacTagChipView(
                        title: "All Tags",
                        count: allTagTaskCount,
                        systemImage: "tag.slash.fill",
                        isSelected: true,
                        action: onShowAllTags
                    )
                } else {
                    ForEach(selectedTags.sorted(), id: \.self) { tag in
                        HomeMacTagChipView(
                            title: "#\(tag)",
                            count: tagCount(for: tag),
                            systemImage: "tag.fill",
                            isSelected: true
                        ) {
                            onToggleIncludedTag(tag)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var suggestedTagsSection: some View {
        if !suggestedRelatedTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested Related Tags")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(suggestedRelatedTags, id: \.self) { tag in
                        HomeMacTagChipView(
                            title: "#\(tag)",
                            count: tagCount(for: tag),
                            systemImage: "tag.fill",
                            isSelected: false
                        ) {
                            onAddIncludedTag(tag)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var addIncludedTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add more")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(tagSummaries.filter { !isIncludedTagSelected($0.name) }) { summary in
                    HomeMacTagChipView(
                        title: "#\(summary.name)",
                        count: summary.linkedRoutineCount,
                        systemImage: "tag.fill",
                        isSelected: false
                    ) {
                        onToggleIncludedTag(summary.name)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var excludedTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hide tasks with")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Hide tasks with", selection: $excludeTagMatchMode) {
                ForEach(RoutineTagMatchMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            selectedExcludedTags
            addExcludedTagsSection
        }
    }

    @ViewBuilder
    private var selectedExcludedTags: some View {
        WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
            if excludedTags.isEmpty {
                Text("No hidden tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(excludedTags.sorted(), id: \.self) { tag in
                    HomeMacTagChipView(
                        title: "#\(tag)",
                        count: tagCount(for: tag),
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

    @ViewBuilder
    private var addExcludedTagsSection: some View {
        let availableTags = availableExcludeTagSummaries.filter { summary in
            !excludedTags.contains { RoutineTag.contains($0, in: [summary.name]) }
        }

        if !availableTags.isEmpty {
            Text("Add tags to hide")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(availableTags) { summary in
                    HomeMacTagChipView(
                        title: "#\(summary.name)",
                        count: summary.linkedRoutineCount,
                        systemImage: "tag.slash.fill",
                        isSelected: false,
                        selectedColor: .red
                    ) {
                        onToggleExcludedTag(summary.name)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func isIncludedTagSelected(_ tag: String) -> Bool {
        selectedTags.contains { RoutineTag.contains($0, in: [tag]) }
    }

    private func tagCount(for tag: String) -> Int {
        tagSummaries.first { RoutineTag.contains($0.name, in: [tag]) }?.linkedRoutineCount ?? 0
    }
}

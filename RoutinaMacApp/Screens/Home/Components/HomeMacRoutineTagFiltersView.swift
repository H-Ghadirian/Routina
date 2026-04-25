import SwiftUI

struct HomeMacRoutineTagFiltersView: View {
    let bindings: HomeTagRuleBindings
    let data: HomeTagFilterData
    let actions: HomeTagFilterActions

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

            Picker("Show tasks with", selection: bindings.includeTagMatchMode) {
                ForEach(RoutineTagMatchMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                if data.selectedTags.isEmpty {
                    HomeMacTagChipView(
                        title: "All Tags",
                        count: data.allTagTaskCount,
                        systemImage: "tag.slash.fill",
                        isSelected: true,
                        action: actions.onShowAllTags
                    )
                } else {
                    ForEach(data.selectedTags.sorted(), id: \.self) { tag in
                        HomeMacTagChipView(
                            title: "#\(tag)",
                            count: data.linkedTaskCount(for: tag),
                            systemImage: "tag.fill",
                            isSelected: true
                        ) {
                            actions.onToggleIncludedTag(tag)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var suggestedTagsSection: some View {
        if !data.suggestedRelatedTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested Related Tags")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(data.suggestedRelatedTags, id: \.self) { tag in
                        HomeMacTagChipView(
                            title: "#\(tag)",
                            count: data.linkedTaskCount(for: tag),
                            systemImage: "tag.fill",
                            isSelected: false
                        ) {
                            actions.onAddIncludedTag(tag)
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
                ForEach(data.tagSummaries.filter { !data.isIncludedTagSelected($0.name) }) { summary in
                    HomeMacTagChipView(
                        title: "#\(summary.name)",
                        count: summary.linkedRoutineCount,
                        systemImage: "tag.fill",
                        isSelected: false
                    ) {
                        actions.onToggleIncludedTag(summary.name)
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

            Picker("Hide tasks with", selection: bindings.excludeTagMatchMode) {
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
            if data.excludedTags.isEmpty {
                Text("No hidden tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(data.excludedTags.sorted(), id: \.self) { tag in
                    HomeMacTagChipView(
                        title: "#\(tag)",
                        count: data.linkedTaskCount(for: tag),
                        systemImage: "tag.slash.fill",
                        isSelected: true,
                        selectedColor: .red
                    ) {
                        actions.onToggleExcludedTag(tag)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var addExcludedTagsSection: some View {
        let availableTags = data.availableExcludeTagSummaries.filter { !data.isExcludedTagSelected($0.name) }

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
                        actions.onToggleExcludedTag(summary.name)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

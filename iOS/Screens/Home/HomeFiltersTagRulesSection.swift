import SwiftUI

struct HomeFiltersTagRulesSection: View {
    let bindings: HomeTagRuleBindings
    let data: HomeTagFilterData
    let actions: HomeTagFilterActions

    @ViewBuilder
    var body: some View {
        if data.hasTags {
            Section("Tag Rules") {
                HomeIncludedTagsFilterSection(
                    includeTagMatchMode: bindings.includeTagMatchMode,
                    data: data,
                    actions: actions
                )

                HomeExcludedTagsFilterSection(
                    excludeTagMatchMode: bindings.excludeTagMatchMode,
                    data: data,
                    actions: actions
                )
            }
        }
    }
}

private struct HomeIncludedTagsFilterSection: View {
    @Binding var includeTagMatchMode: RoutineTagMatchMode
    let data: HomeTagFilterData
    let actions: HomeTagFilterActions

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
            if data.selectedTags.isEmpty {
                HomeFilterChipButton(title: "All Tags \(data.allTagTaskCount)", isSelected: true) {
                    actions.onShowAllTags()
                }
            } else {
                ForEach(data.selectedTags.sorted(), id: \.self) { tag in
                    HomeFilterChipButton(title: "#\(tag)", isSelected: true) {
                        actions.onToggleIncludedTag(tag)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var suggestedTags: some View {
        if !data.suggestedRelatedTags.isEmpty {
            Text("Suggested")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(data.suggestedRelatedTags, id: \.self) { tag in
                    HomeFilterChipButton(title: "#\(tag)", isSelected: false) {
                        actions.onAddIncludedTag(tag)
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
                ForEach(data.tagSummaries.filter { !data.isIncludedTagSelected($0.name) }) { summary in
                    HomeFilterChipButton(
                        title: "#\(summary.name) \(summary.linkedRoutineCount)",
                        isSelected: false
                    ) {
                        actions.onToggleIncludedTag(summary.name)
                    }
                }
            }
        }
    }
}

private struct HomeExcludedTagsFilterSection: View {
    @Binding var excludeTagMatchMode: RoutineTagMatchMode
    let data: HomeTagFilterData
    let actions: HomeTagFilterActions

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
            if data.excludedTags.isEmpty {
                Text("No hidden tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(data.excludedTags.sorted(), id: \.self) { tag in
                    HomeFilterChipButton(
                        title: "#\(tag)",
                        isSelected: true,
                        selectedColor: .red
                    ) {
                        actions.onToggleExcludedTag(tag)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var availableExcludedTags: some View {
        if !data.availableExcludeTagSummaries.isEmpty {
            Text("Add tags to hide")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(data.availableExcludeTagSummaries.filter { !data.isExcludedTagSelected($0.name) }) { summary in
                    HomeFilterChipButton(
                        title: "#\(summary.name) \(summary.linkedRoutineCount)",
                        isSelected: false,
                        selectedColor: .red
                    ) {
                        actions.onToggleExcludedTag(summary.name)
                    }
                }
            }
        }
    }
}

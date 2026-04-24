import SwiftUI

struct HomeMacTimelineTagFiltersView: View {
    let allTagsCount: Int
    let availableTags: [String]
    let suggestedRelatedTags: [String]
    let availableExcludeTags: [String]
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let excludeTagMatchMode: RoutineTagMatchMode
    let selectedExcludedTags: Set<String>
    let tagSelectionSummary: String
    let excludedTagSummary: String
    let tagCount: (String) -> Int
    let onSelectTags: (Set<String>) -> Void
    let onIncludeTagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onSelectSuggestedTag: (String) -> Void
    let onExcludeTagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onToggleExcludedTag: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            includeTagSection

            if !suggestedRelatedTags.isEmpty {
                suggestedRelatedTagSection
            }

            if !availableExcludeTags.isEmpty {
                excludeTagSection
            }
        }
    }

    private var includeTagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Show tasks with")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Text(tagSelectionSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Picker("Show tasks with", selection: Binding(
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
                        count: allTagsCount,
                        systemImage: "tag.slash.fill",
                        isSelected: true
                    ) {
                        onSelectTags([])
                    }
                } else {
                    ForEach(selectedTags.sorted(), id: \.self) { tag in
                        HomeMacTagChipView(
                            title: "#\(tag)",
                            count: tagCount(tag),
                            systemImage: "tag.fill",
                            isSelected: true
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
                ForEach(availableTags.filter { tag in
                    !selectedTags.contains { RoutineTag.contains($0, in: [tag]) }
                }, id: \.self) { tag in
                    HomeMacTagChipView(
                        title: "#\(tag)",
                        count: tagCount(tag),
                        systemImage: "tag.fill",
                        isSelected: false
                    ) {
                        var newSelection = selectedTags
                        newSelection.insert(tag)
                        onSelectTags(newSelection)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var suggestedRelatedTagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Related Tags")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(suggestedRelatedTags, id: \.self) { tag in
                    HomeMacTagChipView(
                        title: "#\(tag)",
                        count: tagCount(tag),
                        systemImage: "tag.fill",
                        isSelected: false
                    ) {
                        onSelectSuggestedTag(tag)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var excludeTagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hide tasks with")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Text(excludedTagSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Picker("Hide tasks with", selection: Binding(
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
                    HomeMacTagChipView(
                        title: "#\(tag)",
                        count: tagCount(tag),
                        systemImage: "tag.slash.fill",
                        isSelected: false,
                        selectedColor: .red
                    ) {
                        onToggleExcludedTag(tag)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

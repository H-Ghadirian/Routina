import SwiftUI

struct HomeMacTimelineTagFiltersView: View {
    let allTagsCount: Int
    let availableTags: [String]
    let availableExcludeTags: [String]
    let selectedTag: String?
    let selectedExcludedTags: Set<String>
    let tagSelectionSummary: String
    let excludedTagSummary: String
    let tagCount: (String) -> Int
    let onSelectTag: (String?) -> Void
    let onToggleExcludedTag: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            includeTagSection

            if !availableExcludeTags.isEmpty {
                excludeTagSection
            }
        }
    }

    private var includeTagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Include Tag")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Text(tagSelectionSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                HomeMacTagChipView(
                    title: "All Tags",
                    count: allTagsCount,
                    systemImage: "tag.slash.fill",
                    isSelected: selectedTag == nil
                ) {
                    onSelectTag(nil)
                }

                ForEach(availableTags, id: \.self) { tag in
                    HomeMacTagChipView(
                        title: "#\(tag)",
                        count: tagCount(tag),
                        systemImage: "tag.fill",
                        isSelected: selectedTag.map { RoutineTag.contains($0, in: [tag]) } ?? false
                    ) {
                        onSelectTag(tag)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var excludeTagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exclude Tags")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Text(excludedTagSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(availableExcludeTags, id: \.self) { tag in
                    let isExcluded = selectedExcludedTags.contains { RoutineTag.contains($0, in: [tag]) }
                    HomeMacTagChipView(
                        title: "#\(tag)",
                        count: tagCount(tag),
                        systemImage: "tag.slash.fill",
                        isSelected: isExcluded,
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

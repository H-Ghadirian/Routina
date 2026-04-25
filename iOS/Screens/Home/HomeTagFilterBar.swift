import SwiftUI

struct HomeTagFilterBar: View {
    let allTagTaskCount: Int
    let tagSummaries: [RoutineTagSummary]
    let selectedTags: Set<String>
    let suggestedRelatedTags: [String]
    let onShowAllTags: () -> Void
    let onToggleIncludedTag: (String) -> Void
    let onAddIncludedTag: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            tagScroll {
                HomeFilterChipButton(
                    title: "All Tags \(allTagTaskCount)",
                    isSelected: selectedTags.isEmpty,
                    action: onShowAllTags
                )

                ForEach(tagSummaries) { summary in
                    HomeFilterChipButton(
                        title: "#\(summary.name) \(summary.linkedRoutineCount)",
                        isSelected: isIncludedTagSelected(summary.name)
                    ) {
                        onToggleIncludedTag(summary.name)
                    }
                }
            }

            if !suggestedRelatedTags.isEmpty {
                tagScroll {
                    Text("Suggested")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(suggestedRelatedTags, id: \.self) { tag in
                        HomeFilterChipButton(title: "#\(tag)", isSelected: false) {
                            onAddIncludedTag(tag)
                        }
                    }
                }
            }
        }
        .padding(.top, -2)
    }

    private func isIncludedTagSelected(_ tag: String) -> Bool {
        selectedTags.contains { RoutineTag.contains($0, in: [tag]) }
    }

    private func tagScroll<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content()
            }
            .padding(.horizontal)
        }
    }
}

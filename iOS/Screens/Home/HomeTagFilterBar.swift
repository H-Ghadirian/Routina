import SwiftUI

struct HomeTagFilterBar: View {
    let data: HomeTagFilterData
    let actions: HomeTagFilterActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            tagScroll {
                HomeFilterChipButton(
                    title: "All Tags \(data.allTagTaskCount)",
                    isSelected: data.selectedTags.isEmpty,
                    action: actions.onShowAllTags
                )

                ForEach(data.tagSummaries) { summary in
                    HomeFilterChipButton(
                        title: "#\(summary.name) \(summary.linkedRoutineCount)",
                        isSelected: data.isIncludedTagSelected(summary.name)
                    ) {
                        actions.onToggleIncludedTag(summary.name)
                    }
                }
            }

            if !data.suggestedRelatedTags.isEmpty {
                tagScroll {
                    Text("Suggested")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(data.suggestedRelatedTags, id: \.self) { tag in
                        HomeFilterChipButton(title: "#\(tag)", isSelected: false) {
                            actions.onAddIncludedTag(tag)
                        }
                    }
                }
            }
        }
        .padding(.top, -2)
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

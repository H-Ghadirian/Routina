import SwiftUI

enum TaskFormIOSTagSuggestionPresentation {
    static let collapsedLimit = 6

    struct Data: Equatable {
        let relatedTags: [String]
        let suggestedTags: [String]
        let remainingTagCount: Int
    }

    static func make(
        routineTags: [String],
        relatedTagRules: [RoutineRelatedTagRule],
        availableTags: [String]
    ) -> Data {
        let selectedTagIDs = Set(routineTags.map { RoutineTag.normalized($0) ?? $0 })
        let relatedTags = RoutineTagRelations.relatedTags(
            for: routineTags,
            rules: relatedTagRules,
            availableTags: availableTags
        ).filter { !selectedTagIDs.contains(RoutineTag.normalized($0) ?? $0) }
        let relatedTagIDs = Set(relatedTags.map { RoutineTag.normalized($0) ?? $0 })
        var suggestedTags: [String] = []
        var remainingTagCount = 0

        for tag in availableTags {
            let tagID = RoutineTag.normalized(tag) ?? tag
            guard !selectedTagIDs.contains(tagID), !relatedTagIDs.contains(tagID) else {
                continue
            }

            remainingTagCount += 1
            if suggestedTags.count < collapsedLimit {
                suggestedTags.append(tag)
            }
        }

        return Data(
            relatedTags: relatedTags,
            suggestedTags: suggestedTags,
            remainingTagCount: remainingTagCount
        )
    }
}

struct TaskFormIOSTagPicker: View {
    let availableTags: [String]
    let selectedTags: [String]
    let availableTagSummaries: [RoutineTagSummary]
    let tagCounterDisplayMode: TagCounterDisplayMode
    let onToggleTagSelection: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var displayedTags: [String] = []
    @State private var selectedTagIDs = Set<String>()
    @State private var tagTitlesByID = [String: String]()

    var body: some View {
        NavigationStack {
            List {
                if displayedTags.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(displayedTags, id: \.self) { tag in
                        tagRow(tag)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Tags")
            .searchable(text: $searchText, prompt: "Search tags")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear(perform: refreshDisplayedTags)
            .onAppear(perform: refreshSelectedTagIDs)
            .onAppear(perform: refreshTagTitles)
            .onChange(of: searchText) { _, _ in
                refreshDisplayedTags()
            }
            .onChange(of: availableTags) { _, _ in
                refreshDisplayedTags()
                refreshTagTitles()
            }
            .onChange(of: selectedTags) { _, _ in
                refreshSelectedTagIDs()
            }
            .onChange(of: availableTagSummaries) { _, _ in
                refreshTagTitles()
            }
            .onChange(of: tagCounterDisplayMode) { _, _ in
                refreshTagTitles()
            }
        }
    }

    private func tagRow(_ tag: String) -> some View {
        let isSelected = selectedTagIDs.contains(tagID(for: tag))
        let tint = Color.accentColor

        return Button {
            onToggleTagSelection(tag)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(isSelected ? tint : .secondary)
                Text(tagChipTitle(tag))
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Text("Selected")
                        .font(.caption)
                        .foregroundStyle(tint)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Remove tag \(tag)" : "Add tag \(tag)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func refreshDisplayedTags() {
        guard let normalizedQuery = RoutineTag.normalized(searchText) else {
            displayedTags = availableTags
            return
        }

        displayedTags = availableTags.filter { tag in
            RoutineTag.normalized(tag)?.localizedCaseInsensitiveContains(normalizedQuery) == true
        }
    }

    private func tagChipTitle(_ tag: String) -> String {
        tagTitlesByID[tagID(for: tag)] ?? "#\(tag)"
    }

    private func refreshSelectedTagIDs() {
        selectedTagIDs = Set(selectedTags.map(tagID(for:)))
    }

    private func refreshTagTitles() {
        let summariesByID = Dictionary(
            availableTagSummaries.map { summary in
                (summary.id, summary)
            },
            uniquingKeysWith: { existing, _ in existing }
        )
        tagTitlesByID = Dictionary(
            availableTags.map { tag in
                (
                    tagID(for: tag),
                    TagCounterFormatting.chipTitle(
                        tag: tag,
                        summary: summariesByID[tagID(for: tag)],
                        mode: tagCounterDisplayMode
                    )
                )
            },
            uniquingKeysWith: { existing, _ in existing }
        )
    }

    private func tagID(for tag: String) -> String {
        RoutineTag.normalized(tag) ?? tag
    }
}

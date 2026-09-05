import SwiftUI

struct HomeMacTagFilterPicker: View {
    let title: String
    let availableTags: [String]
    let suggestedTags: [String]
    let selectedTags: Set<String>
    let tagCount: (String) -> Int
    let tagColor: (String) -> Color?
    let selectedTint: Color
    let onToggle: (String) -> Void

    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            TextField("Search tags", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if !selectedTagList.isEmpty {
                        pickerSection("Selected", tags: selectedTagList, isSelected: true)
                    }

                    if !suggestedTagList.isEmpty {
                        pickerSection("Suggested", tags: suggestedTagList, isSelected: false)
                    }

                    if !browseTagList.isEmpty {
                        pickerSection("Browse", tags: browseTagList, isSelected: false)
                    } else if selectedTagList.isEmpty && suggestedTagList.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 360, height: 480)
    }

    private func pickerSection(_ sectionTitle: String, tags: [String], isSelected: Bool) -> some View {
        Section {
            ForEach(tags, id: \.self) { tag in
                Button {
                    onToggle(tag)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(isSelected ? selectedTint : (tagColor(tag) ?? .secondary))
                            .frame(width: 18)

                        Text("#\(tag)")
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(tagCount(tag).formatted())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundStyle(isSelected ? selectedTint : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(sectionTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 6)
        }
    }

    private var selectedTagList: [String] {
        selectedTags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var suggestedTagList: [String] {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return RoutineTag.deduplicated(suggestedTags)
            .filter { !contains($0, in: selectedTags) }
            .prefix(6)
            .map { $0 }
    }

    private var browseTagList: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return RoutineTag.deduplicated(availableTags + Array(selectedTags))
            .filter { !contains($0, in: selectedTags) }
            .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
            .sorted { lhs, rhs in
                let lhsCount = tagCount(lhs)
                let rhsCount = tagCount(rhs)
                if query.isEmpty, lhsCount != rhsCount { return lhsCount > rhsCount }
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
    }

    private func contains(_ tag: String, in tags: Set<String>) -> Bool {
        tags.contains { RoutineTag.contains($0, in: [tag]) }
    }
}

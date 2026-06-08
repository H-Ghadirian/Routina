import SwiftUI

struct AddRoutineAvailableTagSuggestionsView: View {
    let availableTags: [String]
    let selectedTags: [String]
    let onToggleTag: (String) -> Void

    var body: some View {
        if !unselectedAvailableTags.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(unselectedAvailableTags, id: \.self) { tag in
                    Button {
                        onToggleTag(tag)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.caption)
                            Text("#\(tag)")
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .routinaGlassPill(
                            tint: .secondary,
                            tintOpacity: 0.10,
                            interactive: true
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add tag \(tag)")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var unselectedAvailableTags: [String] {
        availableTags.filter { !RoutineTag.contains($0, in: selectedTags) }
    }
}

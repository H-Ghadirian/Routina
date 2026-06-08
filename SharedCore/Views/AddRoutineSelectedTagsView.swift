import SwiftUI

struct AddRoutineSelectedTagsView: View {
    let selectedTags: [String]
    let isAvailableTagsEmpty: Bool
    let onRemoveTag: (String) -> Void

    var body: some View {
        if !selectedTags.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(selectedTags, id: \.self) { tag in
                    Button {
                        onRemoveTag(tag)
                    } label: {
                        HStack(spacing: 6) {
                            Text("#\(tag)")
                                .lineLimit(1)
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .routinaGlassPill(tint: .accentColor, tintOpacity: 0.14, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove tag \(tag)")
                }
            }
            .padding(.vertical, 4)
        }
    }
}

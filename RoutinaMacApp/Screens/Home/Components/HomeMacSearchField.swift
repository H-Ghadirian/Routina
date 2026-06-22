import SwiftUI

struct HomeMacSearchField: View {
    let placeholder: String
    @Binding var text: String
    let tagSuggestion: String?
    let onAcceptTagSuggestion: (() -> Void)?

    init(
        placeholder: String,
        text: Binding<String>,
        tagSuggestion: String? = nil,
        onAcceptTagSuggestion: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.tagSuggestion = tagSuggestion
        self.onAcceptTagSuggestion = onAcceptTagSuggestion
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .onKeyPress(SwiftUI.KeyEquivalent.tab) {
                    guard tagSuggestion != nil, let onAcceptTagSuggestion else {
                        return SwiftUI.KeyPress.Result.ignored
                    }
                    onAcceptTagSuggestion()
                    return SwiftUI.KeyPress.Result.handled
                }

            tagSuggestionButton

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassCard(cornerRadius: 12, tint: .secondary, tintOpacity: 0.08, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var tagSuggestionButton: some View {
        if let tagSuggestion, let onAcceptTagSuggestion {
            Button {
                onAcceptTagSuggestion()
            } label: {
                HStack(spacing: 6) {
                    Text("#\(tagSuggestion)")
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 160, alignment: .leading)

                    Text("Tab")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .routinaGlassCard(cornerRadius: 4, tint: .secondary, tintOpacity: 0.08)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .routinaGlassPill(interactive: true)
                .overlay {
                    Capsule()
                        .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                }
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.tab, modifiers: [])
            .help("Press Tab to select #\(tagSuggestion)")
            .accessibilityLabel("Select tag \(tagSuggestion)")
        }
    }
}

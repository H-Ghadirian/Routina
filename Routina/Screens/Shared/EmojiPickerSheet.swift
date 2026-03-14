import SwiftUI

struct EmojiPickerSheet: View {
    @Binding var selectedEmoji: String
    let emojis: [EmojiCatalog.Option]

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)

    private var filteredEmojis: [EmojiCatalog.Option] {
        EmojiCatalog.filter(emojis, matching: searchText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Group {
                    if filteredEmojis.isEmpty {
                        VStack(spacing: 12) {
                            Text("No Emoji Found")
                                .font(.headline)
                            Text("Try a different word or paste an emoji to narrow the list.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(filteredEmojis) { option in
                                    Button {
                                        selectedEmoji = option.emoji
                                        dismiss()
                                    } label: {
                                        Text(option.emoji)
                                            .font(.title2)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(selectedEmoji == option.emoji ? Color.blue.opacity(0.2) : Color.clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text(option.accessibilityLabel))
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Choose Emoji")
            .routinaInlineTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search emoji", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
    }
}

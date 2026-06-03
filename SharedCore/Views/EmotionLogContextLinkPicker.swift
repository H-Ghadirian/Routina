import SwiftUI

struct EmotionLogContextLinkPicker<Item: Identifiable>: View where Item.ID == UUID {
    let title: String
    let pluralTitle: String
    let systemImage: String
    let tint: Color
    @Binding var selection: UUID?
    let items: [Item]
    let label: (Item) -> String

    @State private var isPickerPresented = false
    @State private var searchText = ""

    var body: some View {
        Button {
            guard isEnabled else { return }
            searchText = ""
            isPickerPresented = true
        } label: {
            contextLinkLabel
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(isEnabled ? "Link \(title.lowercased())" : "No \(pluralTitle) available")
        .popover(isPresented: $isPickerPresented) {
            pickerContent
                .frame(minWidth: 320, idealWidth: 420, maxWidth: 460, minHeight: 320, maxHeight: 460)
                .padding(14)
        }
    }

    private var isEnabled: Bool {
        !items.isEmpty || selection != nil
    }

    private var selectedTitle: String {
        guard let selection else {
            return items.isEmpty ? "No \(pluralTitle)" : "Choose \(title.lowercased())"
        }
        guard let selectedItem = items.first(where: { $0.id == selection }) else {
            return "Missing \(title.lowercased())"
        }
        return label(selectedItem)
    }

    private var filteredItems: [Item] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return items }

        let normalizedSearch = normalized(trimmedSearch)
        return items.filter { item in
            normalized(label(item)).contains(normalizedSearch)
        }
    }

    private var pickerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose \(title.lowercased())")
                        .font(.headline)
                    Text("\(items.count) \(items.count == 1 ? title.lowercased() : pluralTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search \(pluralTitle)", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            if selection != nil {
                Button {
                    selection = nil
                    isPickerPresented = false
                } label: {
                    pickerRow(title: "Remove \(title.lowercased()) link", systemImage: "xmark.circle", isSelected: false)
                }
                .buttonStyle(.plain)

                Divider()
            }

            if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("No \(pluralTitle) found")
                        .font(.subheadline.weight(.semibold))
                    Text("Try a shorter search.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(filteredItems) { item in
                            Button {
                                selection = item.id
                                isPickerPresented = false
                            } label: {
                                pickerRow(
                                    title: label(item),
                                    systemImage: systemImage,
                                    isSelected: selection == item.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var contextLinkLabel: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(isEnabled ? 0.14 : 0.06))
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isEnabled ? tint : .secondary)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(selectedTitle)
                    .font(.subheadline.weight(selection == nil ? .medium : .semibold))
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 8)

            Image(systemName: isEnabled ? "magnifyingglass" : "minus.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isEnabled ? tint : Color.secondary.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassCard(
            cornerRadius: 12,
            tint: selection == nil ? .secondary : tint,
            tintOpacity: selection == nil ? 0.07 : 0.16,
            interactive: isEnabled
        )
        .contentShape(Rectangle())
    }

    private func pickerRow(title: String, systemImage: String, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isSelected ? tint : .secondary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? tint.opacity(0.14) : Color.secondary.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

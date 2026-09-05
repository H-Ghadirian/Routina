import SwiftUI

enum RecurrenceTimeZoneCatalog {
    struct Option: Equatable, Identifiable, Sendable {
        let id: String
        let title: String
    }

    static let options: [Option] = TimeZone.knownTimeZoneIdentifiers
        .sorted()
        .map {
            Option(
                id: $0,
                title: $0.replacingOccurrences(of: "_", with: " ")
            )
        }

    static func title(for identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: " ")
    }

    static func options(including identifier: String) -> [Option] {
        guard !options.contains(where: { $0.id == identifier }) else {
            return options
        }
        return [Option(id: identifier, title: title(for: identifier))] + options
    }
}

struct RecurrenceTimeZoneField: View {
    @Binding var selection: String
    @State private var isPickerPresented = false

    var body: some View {
        Button {
            isPickerPresented = true
        } label: {
            HStack(spacing: 10) {
                Text("Time zone")
                Spacer(minLength: 12)
                Text(RecurrenceTimeZoneCatalog.title(for: selection))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPickerPresented) {
            RecurrenceTimeZoneSelectionView(selection: $selection)
        }
    }
}

struct RecurrenceTimeZoneSelectionView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var options: [RecurrenceTimeZoneCatalog.Option] {
        let options = RecurrenceTimeZoneCatalog.options(including: selection)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return options }
        return options.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.id.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(options) { option in
                Button {
                    selection = option.id
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(option.title)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 12)
                        if option.id == selection {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Time Zone")
            .searchable(text: $searchText, prompt: "Search time zones")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minHeight: 420)
    }
}

import SwiftUI

struct HomeMacFlagFilterPicker: View {
    let title: String
    let options: [HomeMacFlagFilterPickerOption]
    let selectedFlags: Set<String>
    let tint: Color
    let onToggleFlag: (String) -> Void

    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            TextField("Search flags", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if !selectedOptions.isEmpty {
                        pickerSection("Selected", options: selectedOptions, isSelected: true)
                    }

                    if !availableOptions.isEmpty {
                        pickerSection("Browse", options: availableOptions, isSelected: false)
                    } else if selectedOptions.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 340, height: 400)
    }

    private func pickerSection(
        _ sectionTitle: String,
        options: [HomeMacFlagFilterPickerOption],
        isSelected: Bool
    ) -> some View {
        Section {
            ForEach(options) { option in
                Button {
                    onToggleFlag(option.name)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(isSelected ? tint : Color.secondary)
                            .frame(width: 18)

                        Text(option.name)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        if let count = option.count {
                            Text(count.formatted())
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundStyle(isSelected ? tint : Color.secondary)
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

    private var selectedOptions: [HomeMacFlagFilterPickerOption] {
        allOptions.filter { option in
            HomeFlagFilterMutationSupport.contains(option.name, in: selectedFlags)
        }
    }

    private var availableOptions: [HomeMacFlagFilterPickerOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return allOptions.filter { option in
            !HomeFlagFilterMutationSupport.contains(option.name, in: selectedFlags)
                && (query.isEmpty || option.name.localizedCaseInsensitiveContains(query))
        }
    }

    private var allOptions: [HomeMacFlagFilterPickerOption] {
        var merged = options
        for flag in selectedFlags
        where !merged.contains(where: {
            HomeFlagFilterMutationSupport.contains($0.name, in: [flag])
        }) {
            merged.append(HomeMacFlagFilterPickerOption(name: flag, count: nil))
        }
        return merged.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

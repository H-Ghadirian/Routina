import SwiftUI

struct HomeMacFlagFilterPickerOption: Identifiable {
    let name: String
    let count: Int?

    var id: String {
        RoutineFlag.normalized(name) ?? name
    }
}

struct HomeMacCompactFlagFiltersView: View {
    let actionTitle: String
    let actionSystemImage: String
    let pickerTitle: String
    let accessibilityLabel: String
    let tint: Color
    let options: [HomeMacFlagFilterPickerOption]
    let selectedFlags: Set<String>
    let includeFlagMatchMode: Binding<RoutineTagMatchMode>
    let onToggleFlag: (String) -> Void

    @State private var isPickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isPickerPresented = true
            } label: {
                Label(actionTitle, systemImage: actionSystemImage)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.18))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(tint.opacity(0.34), lineWidth: 1)
            }
            .popover(isPresented: $isPickerPresented, arrowEdge: .trailing) {
                HomeMacFlagFilterPicker(
                    title: pickerTitle,
                    options: options,
                    selectedFlags: selectedFlags,
                    tint: tint,
                    onToggleFlag: onToggleFlag
                )
            }

            if !selectedFlags.isEmpty {
                WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(sortedSelectedFlags, id: \.self) { flag in
                        selectedFlagChip(flag)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transaction { transaction in
                    transaction.animation = nil
                }

                if selectedFlags.count > 1 {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: accessibilityLabel,
                        options: RoutineTagMatchMode.allCases,
                        selection: includeFlagMatchMode,
                        fillsAvailableWidth: true
                    ) { mode in
                        Text(mode.rawValue)
                    }
                }
            }
        }
    }

    private var sortedSelectedFlags: [String] {
        selectedFlags.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    @ViewBuilder
    private func selectedFlagChip(_ flag: String) -> some View {
        if let count = option(for: flag)?.count {
            HomeMacTagChipView(
                title: flag,
                count: count,
                systemImage: "flag.fill",
                isSelected: true,
                selectedColor: tint,
                action: { onToggleFlag(flag) }
            )
        } else {
            Button {
                onToggleFlag(flag)
            } label: {
                Label(flag, systemImage: "flag.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .routinaGlassPill(tint: tint, tintOpacity: 0.16, interactive: true)
                    .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func option(for flag: String) -> HomeMacFlagFilterPickerOption? {
        options.first { HomeFlagFilterMutationSupport.contains($0.name, in: [flag]) }
    }
}

struct HomeMacRoutineFlagFiltersView: View {
    let includeFlagMatchMode: Binding<RoutineTagMatchMode>
    let data: HomeFlagFilterData
    let actions: HomeFlagFilterActions

    var body: some View {
        if data.hasFlags {
            HomeMacCompactFlagFiltersView(
                actionTitle: "Include flags",
                actionSystemImage: "plus",
                pickerTitle: "Include flags",
                accessibilityLabel: "Show tasks with flags",
                tint: .orange,
                options: data.visibleOptions.map {
                    HomeMacFlagFilterPickerOption(
                        name: $0.name,
                        count: $0.taskCount(for: data.taskListKind)
                    )
                },
                selectedFlags: data.selectedFlags,
                includeFlagMatchMode: includeFlagMatchMode,
                onToggleFlag: actions.onToggleFlag
            )
        }
    }
}

struct HomeMacSharedFlagFiltersView: View {
    let availableFlags: [String]
    let selectedFlags: Set<String>
    let excludedFlags: Set<String>
    let includeFlagMatchMode: RoutineTagMatchMode
    let excludeFlagMatchMode: RoutineTagMatchMode
    let onSelectIncludedFlags: (Set<String>) -> Void
    let onIncludeFlagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onSelectExcludedFlags: (Set<String>) -> Void
    let onExcludeFlagMatchModeChange: (RoutineTagMatchMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeMacCompactFlagFiltersView(
                actionTitle: "Include flags",
                actionSystemImage: "plus",
                pickerTitle: "Include flags",
                accessibilityLabel: "Include tasks with flags",
                tint: .orange,
                options: options,
                selectedFlags: selectedFlags,
                includeFlagMatchMode: Binding(
                    get: { includeFlagMatchMode },
                    set: onIncludeFlagMatchModeChange
                ),
                onToggleFlag: { flag in
                    onSelectIncludedFlags(
                        HomeFlagFilterMutationSupport.toggled(flag, in: selectedFlags)
                    )
                }
            )

            HomeMacCompactFlagFiltersView(
                actionTitle: "Exclude flags",
                actionSystemImage: "minus",
                pickerTitle: "Exclude flags",
                accessibilityLabel: "Exclude tasks with flags",
                tint: .red,
                options: options,
                selectedFlags: excludedFlags,
                includeFlagMatchMode: Binding(
                    get: { excludeFlagMatchMode },
                    set: onExcludeFlagMatchModeChange
                ),
                onToggleFlag: { flag in
                    onSelectExcludedFlags(
                        HomeFlagFilterMutationSupport.toggled(flag, in: excludedFlags)
                    )
                }
            )
        }
    }

    private var options: [HomeMacFlagFilterPickerOption] {
        availableFlags.map { HomeMacFlagFilterPickerOption(name: $0, count: nil) }
    }
}

private struct HomeMacFlagFilterPicker: View {
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
        for flag in selectedFlags where !merged.contains(where: {
            HomeFlagFilterMutationSupport.contains($0.name, in: [flag])
        }) {
            merged.append(HomeMacFlagFilterPickerOption(name: flag, count: nil))
        }
        return merged.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

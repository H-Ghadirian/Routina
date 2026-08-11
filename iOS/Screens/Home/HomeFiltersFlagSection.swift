import SwiftUI

struct HomeFiltersFlagSection: View {
    @Binding var includeFlagMatchMode: RoutineTagMatchMode
    let data: HomeFlagFilterData
    let actions: HomeFlagFilterActions
    let onPresent: (IOSFilterDetailDestination) -> Void

    @ViewBuilder
    var body: some View {
        if data.hasFlags {
            Section("Flags") {
                HomeFiltersDetailEntry(
                    title: "Filter flags",
                    systemImage: "flag",
                    value: selectionSummary
                ) {
                    onPresent(.flags)
                }
            }
        }
    }

    private var selectionSummary: String {
        let flags = data.selectedFlags.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        guard let firstFlag = flags.first else { return "All flags" }

        let suffix = flags.count > 1 ? " +\(flags.count - 1)" : ""
        return "\(includeFlagMatchMode.rawValue): \(firstFlag)\(suffix)"
    }
}

struct HomeFiltersFlagPickerSheet: View {
    @Binding var includeFlagMatchMode: RoutineTagMatchMode
    let data: HomeFlagFilterData
    let actions: HomeFlagFilterActions

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var displayedFlagOptions: [HomeFlagFilterOption] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Show tasks with", selection: $includeFlagMatchMode) {
                        ForEach(RoutineTagMatchMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if !data.selectedFlags.isEmpty {
                        Button("Show all flags", action: actions.onShowAllFlags)
                    }
                } footer: {
                    Text("Select flags to include in the Home task list.")
                }

                if !data.selectedFlags.isEmpty {
                    Section("Selected flags") {
                        ForEach(sortedSelectedFlags, id: \.self) { flag in
                            selectedFlagRow(flag)
                        }
                    }
                }

                if !displayedFlagOptions.isEmpty {
                    Section("Flags") {
                        ForEach(displayedFlagOptions) { option in
                            flagOptionRow(option)
                        }
                    }
                } else if data.selectedFlags.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Filter Flags")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search flags")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear(perform: refreshDisplayedFlagOptions)
            .onChange(of: searchText) { _, _ in
                refreshDisplayedFlagOptions()
            }
            .onChange(of: data.flagOptions) { _, _ in
                refreshDisplayedFlagOptions()
            }
            .onChange(of: data.taskListKind) { _, _ in
                refreshDisplayedFlagOptions()
            }
            .onChange(of: data.selectedFlags) { _, _ in
                refreshDisplayedFlagOptions()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var sortedSelectedFlags: [String] {
        data.selectedFlags.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private func selectedFlagRow(_ flag: String) -> some View {
        Button {
            actions.onToggleFlag(flag)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                Text(flag)
                    .foregroundStyle(.primary)
                Spacer()
                Text("Selected")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(flag) from flag filters")
        .accessibilityValue("Selected")
    }

    private func flagOptionRow(_ option: HomeFlagFilterOption) -> some View {
        Button {
            actions.onToggleFlag(option.name)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
                Text(option.name)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(option.taskCount(for: data.taskListKind))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(option.name) to flag filters")
        .accessibilityValue("\(option.taskCount(for: data.taskListKind)) tasks")
    }

    private func refreshDisplayedFlagOptions() {
        let unselectedOptions = data.visibleOptions.filter { !data.isSelected($0.name) }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            displayedFlagOptions = unselectedOptions
            return
        }

        displayedFlagOptions = unselectedOptions.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }
}

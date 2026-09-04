import ComposableArchitecture
import SwiftUI

struct BacklogIOSFlagFilterPicker: View {
    let store: StoreOf<BacklogFeature>

    @Environment(\.dismiss) private var dismiss
    @State private var rule = Rule.include
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Select flags to") {
                        Picker("Select flags to", selection: $rule) {
                            ForEach(Rule.allCases) { rule in
                                Text(rule.title).tag(rule)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    LabeledContent("Match") {
                        Picker("Match", selection: matchModeBinding) {
                            ForEach(RoutineTagMatchMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                } footer: {
                    Text(rule.footer)
                }

                if displayedFlags.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    Section("Flags") {
                        ForEach(displayedFlags, id: \.self) { flag in
                            flagRow(flag)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Filter Backlog Flags")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search flags")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func flagRow(_ flag: String) -> some View {
        let selectedRule = selectedRule(for: flag)
        return Button {
            toggle(flag, selectedRule: selectedRule)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedRule?.selectedSymbol ?? "plus.circle")
                    .foregroundStyle(selectedRule?.tint ?? .secondary)

                Text(flag)
                    .foregroundStyle(.primary)

                Spacer()

                if let selectedRule {
                    Text(selectedRule.selectedTitle)
                        .font(.caption)
                        .foregroundStyle(selectedRule.tint)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: flag, selectedRule: selectedRule))
        .accessibilityValue(selectedRule?.selectedTitle ?? "Not selected")
    }

    private var displayedFlags: [String] {
        let selected = availableFlags.filter { selectedRule(for: $0) != nil }
        let unselected = availableFlags.filter { selectedRule(for: $0) == nil }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return selected + unselected }
        return selected
            + unselected.filter {
                $0.localizedCaseInsensitiveContains(query)
            }
    }

    private var availableFlags: [String] {
        RoutineFlag.iOSVisible(
            RoutineFlag.allFlags(
                from: [
                    store.presentation.filterCatalog.flags,
                    Array(store.filters.selectedFlags),
                    Array(store.filters.excludedFlags),
                ]
            )
        )
    }

    private var bindings: BacklogIOSFilterBindings {
        BacklogIOSFilterBindings(store: store)
    }

    private var matchModeBinding: Binding<RoutineTagMatchMode> {
        switch rule {
        case .include:
            return bindings.binding(\.includeFlagMatchMode)
        case .exclude:
            return bindings.binding(\.excludeFlagMatchMode)
        }
    }

    private func selectedRule(for flag: String) -> Rule? {
        if HomeFlagFilterMutationSupport.contains(flag, in: store.filters.excludedFlags) {
            return .exclude
        }
        if HomeFlagFilterMutationSupport.contains(flag, in: store.filters.selectedFlags) {
            return .include
        }
        return nil
    }

    private func toggle(_ flag: String, selectedRule: Rule?) {
        bindings.update { filters in
            switch selectedRule ?? rule {
            case .include:
                filters.selectedFlags = HomeFlagFilterMutationSupport.toggled(
                    flag,
                    in: filters.selectedFlags
                )
                if selectedRule == nil {
                    filters.excludedFlags = removing(flag, from: filters.excludedFlags)
                }
            case .exclude:
                filters.excludedFlags = HomeFlagFilterMutationSupport.toggled(
                    flag,
                    in: filters.excludedFlags
                )
                if selectedRule == nil {
                    filters.selectedFlags = removing(flag, from: filters.selectedFlags)
                }
            }
        }
    }

    private func removing(_ flag: String, from flags: Set<String>) -> Set<String> {
        flags.filter { !RoutineFlag.contains($0, in: [flag]) }
    }

    private func accessibilityLabel(for flag: String, selectedRule: Rule?) -> String {
        if let selectedRule {
            return "Remove \(flag) from \(selectedRule.selectedTitle.lowercased()) flags"
        }
        return "Add \(flag) to \(rule.selectedTitle.lowercased()) flags"
    }
}

private enum Rule: CaseIterable, Identifiable {
    case include
    case exclude

    var id: Self { self }

    var title: String {
        switch self {
        case .include: return "Show"
        case .exclude: return "Hide"
        }
    }

    var selectedTitle: String {
        switch self {
        case .include: return "Included"
        case .exclude: return "Hidden"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .include: return "checkmark.circle.fill"
        case .exclude: return "minus.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .include: return .accentColor
        case .exclude: return .red
        }
    }

    var footer: String {
        switch self {
        case .include:
            return "Included flags deliberately reveal matching Backlog tasks."
        case .exclude:
            return "Excluded flags hide matching tasks and win when rules overlap."
        }
    }
}

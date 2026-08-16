import SwiftUI

struct HomeFiltersTagFilterEntrySection: View {
    @Binding var selectedTags: Set<String>
    @Binding var excludedTags: Set<String>
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersDetailEntry(
            title: "Filter tags",
            systemImage: "tag",
            value: selectionSummary
        ) {
            onPresent(.tags)
        }
        .accessibilityHint("Choose tags to show or hide")
    }

    private var selectionSummary: String {
        let summaries = [
            namedSummary(for: excludedTags, action: "Hiding"),
            namedSummary(for: selectedTags, action: "Showing")
        ].compactMap { $0 }

        return summaries.isEmpty ? "All tags" : summaries.joined(separator: " • ")
    }

    private func namedSummary(for tags: Set<String>, action: String) -> String? {
        let names = tags.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        guard let firstName = names.first else { return nil }

        let remainingCount = names.count - 1
        let suffix = remainingCount > 0 ? " +\(remainingCount)" : ""
        return "\(action) #\(firstName)\(suffix)"
    }
}

struct HomeTagFilterPickerSheet: View {
    let data: HomeTagFilterData
    let bindings: HomeTagRuleBindings
    let actions: HomeTagFilterActions
    let labels: HomeTagFilterPickerLabels

    @Environment(\.dismiss) private var dismiss
    @State private var rule: Rule
    @State private var searchText = ""
    @State private var displayedTagSummaries: [RoutineTagSummary] = []
    @State private var selectedRuleByTagID: [String: Rule] = [:]

    init(
        data: HomeTagFilterData,
        bindings: HomeTagRuleBindings,
        actions: HomeTagFilterActions,
        labels: HomeTagFilterPickerLabels = .init()
    ) {
        self.data = data
        self.bindings = bindings
        self.actions = actions
        self.labels = labels
        _rule = State(initialValue: data.excludedTags.isEmpty ? .include : .exclude)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Select tags to") {
                        Picker("Select tags to", selection: $rule) {
                            ForEach(Rule.allCases) { rule in
                                Text(rule.title).tag(rule)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    tagMatchModePicker
                } footer: {
                    Text(currentRuleFooter)
                }

                if displayedTagSummaries.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    Section {
                        ForEach(displayedTagSummaries) { summary in
                            tagRow(summary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(labels.navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search tags")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear(perform: refreshPresentation)
            .onChange(of: rule) { _, _ in
                refreshPresentation()
            }
            .onChange(of: searchText) { _, _ in
                refreshDisplayedTagSummaries()
            }
            .onChange(of: data.tagSummaries) { _, _ in
                refreshPresentation()
            }
            .onChange(of: data.availableExcludeTagSummaries) { _, _ in
                refreshPresentation()
            }
            .onChange(of: data.selectedTags) { _, _ in
                refreshPresentation()
            }
            .onChange(of: data.excludedTags) { _, _ in
                refreshPresentation()
            }
        }
    }

    private func tagRow(_ summary: RoutineTagSummary) -> some View {
        let selectedRule = selectedRuleByTagID[summary.id]

        return Button {
            switch selectedRule ?? rule {
            case .include:
                actions.onToggleIncludedTag(summary.name)
            case .exclude:
                actions.onToggleExcludedTag(summary.name)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedRule?.selectedSymbol ?? "plus.circle")
                    .foregroundStyle(selectedRule?.tint ?? .secondary)

                Text(tagTitle(for: summary))
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
        .accessibilityLabel(accessibilityLabel(for: summary, selectedRule: selectedRule))
        .accessibilityValue(selectedRule?.selectedTitle ?? "Not selected")
    }

    private var matchModeBinding: Binding<RoutineTagMatchMode> {
        switch rule {
        case .include:
            bindings.includeTagMatchMode
        case .exclude:
            bindings.excludeTagMatchMode
        }
    }

    private var tagMatchModePicker: some View {
        LabeledContent("Match") {
            Picker("Match", selection: matchModeBinding) {
                ForEach(RoutineTagMatchMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var currentRuleFooter: String {
        rule == .include ? labels.includeFooter : labels.excludeFooter
    }

    private func refreshPresentation() {
        refreshSelectedRules()
        refreshDisplayedTagSummaries()
    }

    private func refreshSelectedRules() {
        var rulesByTagID: [String: Rule] = [:]
        for tag in data.excludedTags {
            rulesByTagID[tagID(for: tag)] = .exclude
        }
        for tag in data.selectedTags where rulesByTagID[tagID(for: tag)] == nil {
            rulesByTagID[tagID(for: tag)] = .include
        }
        selectedRuleByTagID = rulesByTagID
    }

    private func refreshDisplayedTagSummaries() {
        let catalog = tagCatalog()
        let selected = catalog.filter { selectedRuleByTagID[$0.id] != nil }
            .sorted(by: selectedTagSort)
        let unselected = catalog.filter { selectedRuleByTagID[$0.id] == nil }

        guard let query = RoutineTag.normalized(searchText) else {
            displayedTagSummaries = selected + unselected
            return
        }

        displayedTagSummaries = selected + unselected.filter { summary in
            RoutineTag.normalized(summary.name)?
                .localizedCaseInsensitiveContains(query) == true
        }
    }

    private func tagCatalog() -> [RoutineTagSummary] {
        var summariesByID = Dictionary(
            (data.tagSummaries + data.availableExcludeTagSummaries).map { summary in
                (summary.id, summary)
            },
            uniquingKeysWith: { existing, _ in existing }
        )

        for selectedTag in data.selectedTags.union(data.excludedTags) {
            let id = tagID(for: selectedTag)
            if summariesByID[id] == nil {
                summariesByID[id] = RoutineTagSummary(name: selectedTag, linkedRoutineCount: 0)
            }
        }

        return summariesByID.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func tagTitle(for summary: RoutineTagSummary) -> String {
        guard data.showsTagCounts else { return "#\(summary.name)" }
        return "#\(summary.name) \(summary.linkedRoutineCount)"
    }

    private func selectedTagSort(_ lhs: RoutineTagSummary, _ rhs: RoutineTagSummary) -> Bool {
        let lhsRank = selectedRuleByTagID[lhs.id] == .exclude ? 0 : 1
        let rhsRank = selectedRuleByTagID[rhs.id] == .exclude ? 0 : 1
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func accessibilityLabel(
        for summary: RoutineTagSummary,
        selectedRule: Rule?
    ) -> String {
        if let selectedRule {
            return "Remove \(summary.name) from \(selectedRule.selectedTitle.lowercased()) tags"
        }
        return "Add \(summary.name) to \(rule.selectedTitle.lowercased()) tags"
    }

    private func tagID(for tag: String) -> String {
        RoutineTag.normalized(tag) ?? tag
    }
}

struct HomeTagFilterPickerLabels {
    let navigationTitle: String
    let includeFooter: String
    let excludeFooter: String

    init(
        navigationTitle: String = "Filter Tags",
        includeFooter: String = "Select tags to include in the Home task list.",
        excludeFooter: String = "Select tags to hide from the Home task list."
    ) {
        self.navigationTitle = navigationTitle
        self.includeFooter = includeFooter
        self.excludeFooter = excludeFooter
    }
}

private enum Rule: CaseIterable, Identifiable {
    case include
    case exclude

    var id: Self { self }

    var title: String {
        switch self {
        case .include: "Show"
        case .exclude: "Hide"
        }
    }

    var selectedTitle: String {
        switch self {
        case .include: "Included"
        case .exclude: "Hidden"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .include: "checkmark.circle.fill"
        case .exclude: "minus.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .include: .accentColor
        case .exclude: .red
        }
    }
}

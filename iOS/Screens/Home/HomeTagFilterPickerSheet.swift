import SwiftUI

struct HomeFiltersTagFilterEntrySection: View {
    @Binding var selectedTags: Set<String>
    @Binding var excludedTags: Set<String>
    let onShowTagPicker: () -> Void

    var body: some View {
        Section("Tags") {
            Button(action: onShowTagPicker) {
                HStack(spacing: 12) {
                    Label("Filter tags", systemImage: "tag")
                    Spacer()
                    Text(selectionSummary)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filter tags")
            .accessibilityValue(selectionSummary)
            .accessibilityHint("Choose tags to show or hide")
        }
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

    @Environment(\.dismiss) private var dismiss
    @State private var rule: Rule
    @State private var searchText = ""
    @State private var displayedTagSummaries: [RoutineTagSummary] = []
    @State private var selectedTagIDs = Set<String>()
    @State private var selectedTagSelections: [TagSelection] = []

    init(
        data: HomeTagFilterData,
        bindings: HomeTagRuleBindings,
        actions: HomeTagFilterActions
    ) {
        self.data = data
        self.bindings = bindings
        self.actions = actions
        _rule = State(initialValue: data.excludedTags.isEmpty ? .include : .exclude)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Rule", selection: $rule) {
                        ForEach(Rule.allCases) { rule in
                            Text(rule.title).tag(rule)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Match", selection: matchModeBinding) {
                        ForEach(RoutineTagMatchMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(rule.footer)
                }

                if !selectedTagSelections.isEmpty {
                    Section("Selected tags") {
                        ForEach(selectedTagSelections) { selection in
                            selectedTagRow(selection)
                        }
                    }
                }

                if displayedTagSummaries.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    Section(rule.catalogTitle) {
                        ForEach(displayedTagSummaries) { summary in
                            tagRow(summary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Filter Tags")
            .navigationBarTitleDisplayMode(.inline)
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
                refreshSelectedTagIDs()
                refreshSelectedTagSelections()
                refreshDisplayedTagSummaries()
            }
            .onChange(of: data.excludedTags) { _, _ in
                refreshSelectedTagIDs()
                refreshSelectedTagSelections()
                refreshDisplayedTagSummaries()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func tagRow(_ summary: RoutineTagSummary) -> some View {
        let isSelected = selectedTagIDs.contains(summary.id)

        return Button {
            switch rule {
            case .include:
                actions.onToggleIncludedTag(summary.name)
            case .exclude:
                actions.onToggleExcludedTag(summary.name)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? rule.tint : .secondary)

                Text(tagTitle(for: summary))
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Text(rule.selectedTitle)
                        .font(.caption)
                        .foregroundStyle(rule.tint)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: summary, isSelected: isSelected))
        .accessibilityValue(isSelected ? rule.selectedTitle : "Not selected")
    }

    private func selectedTagRow(_ selection: TagSelection) -> some View {
        Button {
            switch selection.rule {
            case .include:
                actions.onToggleIncludedTag(selection.name)
            case .exclude:
                actions.onToggleExcludedTag(selection.name)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selection.rule.selectedSymbol)
                    .foregroundStyle(selection.rule.tint)

                Text("#\(selection.name)")
                    .foregroundStyle(.primary)

                Spacer()

                Text(selection.rule.selectedTitle)
                    .font(.caption)
                    .foregroundStyle(selection.rule.tint)

                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(selection.name) from \(selection.rule.selectedTitle.lowercased()) tags")
        .accessibilityValue(selection.rule.selectedTitle)
    }

    private var matchModeBinding: Binding<RoutineTagMatchMode> {
        switch rule {
        case .include:
            bindings.includeTagMatchMode
        case .exclude:
            bindings.excludeTagMatchMode
        }
    }

    private var currentSelectedTags: Set<String> {
        switch rule {
        case .include:
            data.selectedTags
        case .exclude:
            data.excludedTags
        }
    }

    private func refreshPresentation() {
        refreshSelectedTagIDs()
        refreshSelectedTagSelections()
        refreshDisplayedTagSummaries()
    }

    private func refreshSelectedTagIDs() {
        selectedTagIDs = Set(currentSelectedTags.compactMap(RoutineTag.normalized))
    }

    private func refreshSelectedTagSelections() {
        selectedTagSelections = selections(from: data.excludedTags, for: .exclude)
            + selections(from: data.selectedTags, for: .include)
    }

    private func selections(from tags: Set<String>, for rule: Rule) -> [TagSelection] {
        tags.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }.map { tag in
            TagSelection(name: tag, rule: rule)
        }
    }

    private func refreshDisplayedTagSummaries() {
        let catalog = tagCatalog()

        guard let query = RoutineTag.normalized(searchText) else {
            displayedTagSummaries = catalog
            return
        }

        displayedTagSummaries = catalog.filter { summary in
            RoutineTag.normalized(summary.name)?
                .localizedCaseInsensitiveContains(query) == true
        }
    }

    private func tagCatalog() -> [RoutineTagSummary] {
        let summaries = switch rule {
        case .include:
            data.tagSummaries
        case .exclude:
            data.availableExcludeTagSummaries
        }

        var summariesByID = Dictionary(
            summaries.map { summary in
                (summary.id, summary)
            },
            uniquingKeysWith: { existing, _ in existing }
        )

        for selectedTag in currentSelectedTags {
            let id = RoutineTag.normalized(selectedTag) ?? selectedTag
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

    private func accessibilityLabel(for summary: RoutineTagSummary, isSelected: Bool) -> String {
        let action = isSelected ? "Remove" : "Add"
        let preposition = isSelected ? "from" : "to"
        return "\(action) \(summary.name) \(preposition) \(rule.selectedTitle.lowercased()) tags"
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

    var catalogTitle: String {
        switch self {
        case .include: "Show tasks with"
        case .exclude: "Hide tasks with"
        }
    }

    var footer: String {
        switch self {
        case .include: "Select tags to include in the Home task list."
        case .exclude: "Select tags to hide from the Home task list."
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

private struct TagSelection: Identifiable {
    let name: String
    let rule: Rule

    var id: String {
        "\(rule.id)-\(RoutineTag.normalized(name) ?? name)"
    }
}

import SwiftUI

enum HomeMacTagFiltersPresentation {
    case detailed
    case compactActions
}

struct HomeMacTimelineTagFiltersView: View {
    let availableTags: [String]
    let suggestedRelatedTags: [String]
    let availableExcludeTags: [String]
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let excludeTagMatchMode: RoutineTagMatchMode
    let selectedExcludedTags: Set<String>
    let tagCount: (String) -> Int
    let tagColor: (String) -> Color?
    let onSelectTags: (Set<String>) -> Void
    let onIncludeTagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onSelectSuggestedTag: (String) -> Void
    let onExcludeTagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onToggleExcludedTag: (String) -> Void
    var presentation = HomeMacTagFiltersPresentation.detailed

    @State private var isIncludePickerPresented = false
    @State private var isExcludePickerPresented = false
    @State private var isCompactPickerPresented = false
    @State private var compactRuleSide = HomeMacFilterRuleSide.include

    var body: some View {
        switch presentation {
        case .detailed:
            VStack(alignment: .leading, spacing: 20) {
                includeTagSection
                excludeTagSection
            }
        case .compactActions:
            HomeMacDirectFilterGroup(
                title: "Tags",
                systemImage: "tag.fill",
                tint: .teal
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    compactTagRuleSummary
                    compactTagFilterEditButton
                }
            }
        }
    }

    @ViewBuilder
    private var compactTagRuleSummary: some View {
        if !selectedTags.isEmpty || !selectedExcludedTags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !selectedTags.isEmpty {
                    compactTagRule(
                        title: compactRuleTitle(
                            "Include",
                            count: selectedTags.count,
                            matchMode: includeTagMatchMode
                        ),
                        tags: selectedTags,
                        isExcluded: false
                    )
                }

                if !selectedExcludedTags.isEmpty {
                    compactTagRule(
                        title: compactRuleTitle(
                            "Exclude",
                            count: selectedExcludedTags.count,
                            matchMode: excludeTagMatchMode
                        ),
                        tags: selectedExcludedTags,
                        isExcluded: true
                    )
                }
            }
        }
    }

    private func compactTagRule(
        title: String,
        tags: Set<String>,
        isExcluded: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isExcluded ? Color.red : Color.teal)

            selectedTagChips(tags: tags, isExcluded: isExcluded)
        }
    }

    private var compactTagFilterEditButton: some View {
        Button {
            if selectedTags.isEmpty && !selectedExcludedTags.isEmpty {
                compactRuleSide = .exclude
            }
            isCompactPickerPresented = true
        } label: {
            Label("Edit tag filters…", systemImage: "slider.horizontal.3")
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.teal.opacity(0.18))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.teal.opacity(0.34), lineWidth: 1)
        }
        .popover(isPresented: $isCompactPickerPresented, arrowEdge: .trailing) {
            HomeMacCombinedTagFilterPicker(
                ruleSide: $compactRuleSide,
                availableTags: availableTags,
                suggestedTags: suggestedRelatedTags,
                availableExcludeTags: availableExcludeTags,
                selectedTags: selectedTags,
                selectedExcludedTags: selectedExcludedTags,
                includeMatchMode: includeTagMatchMode,
                excludeMatchMode: excludeTagMatchMode,
                tagCount: tagCount,
                tagColor: tagColor,
                onToggleIncludedTag: toggleIncludedTag,
                onToggleExcludedTag: onToggleExcludedTag,
                onIncludeMatchModeChange: onIncludeTagMatchModeChange,
                onExcludeMatchModeChange: onExcludeTagMatchModeChange
            )
        }
    }

    private func compactRuleTitle(
        _ title: String,
        count: Int,
        matchMode: RoutineTagMatchMode
    ) -> String {
        count > 1 ? "\(title) · \(matchMode.rawValue)" : title
    }

    private var includeTagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Include tags")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if selectedTags.isEmpty {
                Text("No tag filter")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                selectedTagChips(tags: selectedTags, isExcluded: false)
            }

            if selectedTags.count > 1 {
                matchModeControl(
                    title: "Include when a task has",
                    selection: includeTagMatchMode,
                    onSelect: onIncludeTagMatchModeChange
                )
            }

            Button {
                isIncludePickerPresented = true
            } label: {
                Label("Add tags…", systemImage: "plus")
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $isIncludePickerPresented, arrowEdge: .trailing) {
                HomeMacTagFilterPicker(
                    title: "Include tags",
                    availableTags: availableTags,
                    suggestedTags: suggestedRelatedTags,
                    selectedTags: selectedTags,
                    tagCount: tagCount,
                    tagColor: tagColor,
                    selectedTint: .accentColor,
                    onToggle: toggleIncludedTag
                )
            }
        }
    }

    private var excludeTagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exclude tags")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if selectedExcludedTags.isEmpty {
                Text("No excluded tags")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                selectedTagChips(tags: selectedExcludedTags, isExcluded: true)
            }

            if selectedExcludedTags.count > 1 {
                matchModeControl(
                    title: "Exclude when a task has",
                    selection: excludeTagMatchMode,
                    onSelect: onExcludeTagMatchModeChange
                )
            }

            Button {
                isExcludePickerPresented = true
            } label: {
                Label("Add tags to exclude…", systemImage: "plus")
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $isExcludePickerPresented, arrowEdge: .trailing) {
                HomeMacTagFilterPicker(
                    title: "Exclude tags",
                    availableTags: availableExcludeTags,
                    suggestedTags: [],
                    selectedTags: selectedExcludedTags,
                    tagCount: tagCount,
                    tagColor: tagColor,
                    selectedTint: .red,
                    onToggle: onToggleExcludedTag
                )
            }
        }
    }

    private func selectedTagChips(tags: Set<String>, isExcluded: Bool) -> some View {
        WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(tags.sorted(), id: \.self) { tag in
                HomeMacTagChipView(
                    title: "#\(tag)",
                    count: tagCount(tag),
                    systemImage: isExcluded ? "tag.slash.fill" : "tag.fill",
                    isSelected: true,
                    selectedColor: isExcluded ? .red : (tagColor(tag) ?? .accentColor),
                    unselectedColor: tagColor(tag)
                ) {
                    if isExcluded {
                        onToggleExcludedTag(tag)
                    } else {
                        toggleIncludedTag(tag)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func matchModeControl(
        title: String,
        selection: RoutineTagMatchMode,
        onSelect: @escaping (RoutineTagMatchMode) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            RoutinaGlassSegmentedControl(
                accessibilityLabel: title,
                options: RoutineTagMatchMode.allCases,
                selection: selection,
                onSelect: onSelect,
                fillsAvailableWidth: true
            ) { mode in
                Text(mode.rawValue)
            }
        }
    }

    private func toggleIncludedTag(_ tag: String) {
        if selectedTags.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
            onSelectTags(selectedTags.filter { !RoutineTag.contains($0, in: [tag]) })
        } else if suggestedRelatedTags.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
            onSelectSuggestedTag(tag)
        } else {
            var updated = selectedTags
            updated.insert(tag)
            onSelectTags(updated)
        }
    }
}

private struct HomeMacCombinedTagFilterPicker: View {
    @Binding var ruleSide: HomeMacFilterRuleSide
    let availableTags: [String]
    let suggestedTags: [String]
    let availableExcludeTags: [String]
    let selectedTags: Set<String>
    let selectedExcludedTags: Set<String>
    let includeMatchMode: RoutineTagMatchMode
    let excludeMatchMode: RoutineTagMatchMode
    let tagCount: (String) -> Int
    let tagColor: (String) -> Color?
    let onToggleIncludedTag: (String) -> Void
    let onToggleExcludedTag: (String) -> Void
    let onIncludeMatchModeChange: (RoutineTagMatchMode) -> Void
    let onExcludeMatchModeChange: (RoutineTagMatchMode) -> Void

    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tag filters")
                .font(.headline)

            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Tag filter rule",
                options: HomeMacFilterRuleSide.allCases,
                selection: ruleSide,
                onSelect: { ruleSide = $0 },
                fillsAvailableWidth: true
            ) { side in
                Text(side.rawValue)
            }

            if activeSelectedTags.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(ruleSide.rawValue) when a task has")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "\(ruleSide.rawValue) tag match mode",
                        options: RoutineTagMatchMode.allCases,
                        selection: activeMatchMode,
                        onSelect: selectMatchMode,
                        fillsAvailableWidth: true
                    ) { mode in
                        Text(mode.rawValue)
                    }
                }
            }

            TextField("Search tags", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if !selectedTagList.isEmpty {
                        pickerSection("Selected", tags: selectedTagList, isSelected: true)
                    }

                    if !suggestedTagList.isEmpty {
                        pickerSection("Suggested", tags: suggestedTagList, isSelected: false)
                    }

                    if !browseTagList.isEmpty {
                        pickerSection("Browse", tags: browseTagList, isSelected: false)
                    } else if selectedTagList.isEmpty && suggestedTagList.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 360, height: 520)
    }

    private func pickerSection(_ sectionTitle: String, tags: [String], isSelected: Bool) -> some View {
        Section {
            ForEach(tags, id: \.self) { tag in
                Button {
                    toggle(tag)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: ruleSide == .exclude ? "tag.slash.fill" : "tag.fill")
                            .foregroundStyle(isSelected ? selectedTint : (tagColor(tag) ?? .secondary))
                            .frame(width: 18)

                        Text("#\(tag)")
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(tagCount(tag).formatted())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundStyle(isSelected ? selectedTint : .secondary)
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

    private var activeSelectedTags: Set<String> {
        ruleSide == .include ? selectedTags : selectedExcludedTags
    }

    private var activeAvailableTags: [String] {
        ruleSide == .include ? availableTags : availableExcludeTags
    }

    private var activeSuggestedTags: [String] {
        ruleSide == .include ? suggestedTags : []
    }

    private var activeMatchMode: RoutineTagMatchMode {
        ruleSide == .include ? includeMatchMode : excludeMatchMode
    }

    private var selectedTint: Color {
        ruleSide == .include ? .accentColor : .red
    }

    private var selectedTagList: [String] {
        activeSelectedTags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var suggestedTagList: [String] {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return RoutineTag.deduplicated(activeSuggestedTags)
            .filter { !contains($0, in: activeSelectedTags) }
            .prefix(6)
            .map { $0 }
    }

    private var browseTagList: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return RoutineTag.deduplicated(activeAvailableTags + Array(activeSelectedTags))
            .filter { !contains($0, in: activeSelectedTags) }
            .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
            .sorted { lhs, rhs in
                let lhsCount = tagCount(lhs)
                let rhsCount = tagCount(rhs)
                if query.isEmpty, lhsCount != rhsCount { return lhsCount > rhsCount }
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
    }

    private func contains(_ tag: String, in tags: Set<String>) -> Bool {
        tags.contains { RoutineTag.contains($0, in: [tag]) }
    }

    private func toggle(_ tag: String) {
        if ruleSide == .include {
            onToggleIncludedTag(tag)
        } else {
            onToggleExcludedTag(tag)
        }
    }

    private func selectMatchMode(_ mode: RoutineTagMatchMode) {
        if ruleSide == .include {
            onIncludeMatchModeChange(mode)
        } else {
            onExcludeMatchModeChange(mode)
        }
    }
}

private struct HomeMacTagFilterPicker: View {
    let title: String
    let availableTags: [String]
    let suggestedTags: [String]
    let selectedTags: Set<String>
    let tagCount: (String) -> Int
    let tagColor: (String) -> Color?
    let selectedTint: Color
    let onToggle: (String) -> Void

    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            TextField("Search tags", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if !selectedTagList.isEmpty {
                        pickerSection("Selected", tags: selectedTagList, isSelected: true)
                    }

                    if !suggestedTagList.isEmpty {
                        pickerSection("Suggested", tags: suggestedTagList, isSelected: false)
                    }

                    if !browseTagList.isEmpty {
                        pickerSection("Browse", tags: browseTagList, isSelected: false)
                    } else if selectedTagList.isEmpty && suggestedTagList.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 360, height: 480)
    }

    private func pickerSection(_ sectionTitle: String, tags: [String], isSelected: Bool) -> some View {
        Section {
            ForEach(tags, id: \.self) { tag in
                Button {
                    onToggle(tag)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(isSelected ? selectedTint : (tagColor(tag) ?? .secondary))
                            .frame(width: 18)

                        Text("#\(tag)")
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(tagCount(tag).formatted())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundStyle(isSelected ? selectedTint : .secondary)
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

    private var selectedTagList: [String] {
        selectedTags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var suggestedTagList: [String] {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return RoutineTag.deduplicated(suggestedTags)
            .filter { !contains($0, in: selectedTags) }
            .prefix(6)
            .map { $0 }
    }

    private var browseTagList: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return RoutineTag.deduplicated(availableTags + Array(selectedTags))
            .filter { !contains($0, in: selectedTags) }
            .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
            .sorted { lhs, rhs in
                let lhsCount = tagCount(lhs)
                let rhsCount = tagCount(rhs)
                if query.isEmpty, lhsCount != rhsCount { return lhsCount > rhsCount }
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
    }

    private func contains(_ tag: String, in tags: Set<String>) -> Bool {
        tags.contains { RoutineTag.contains($0, in: [tag]) }
    }
}

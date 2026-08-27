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

    @State private var isPickerPresented = false
    @State private var ruleSide = HomeMacFilterRuleSide.include

    var body: some View {
        HomeMacDirectFilterGroup(
            title: "Flags",
            systemImage: "flag.fill",
            tint: .orange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                flagRuleSummary
                editFlagFiltersButton
            }
        }
    }

    @ViewBuilder
    private var flagRuleSummary: some View {
        if !selectedFlags.isEmpty || !excludedFlags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !selectedFlags.isEmpty {
                    selectedFlagRule(
                        title: ruleTitle(
                            "Include",
                            count: selectedFlags.count,
                            matchMode: includeFlagMatchMode
                        ),
                        flags: selectedFlags,
                        isExcluded: false
                    )
                }

                if !excludedFlags.isEmpty {
                    selectedFlagRule(
                        title: ruleTitle(
                            "Exclude",
                            count: excludedFlags.count,
                            matchMode: excludeFlagMatchMode
                        ),
                        flags: excludedFlags,
                        isExcluded: true
                    )
                }
            }
        }
    }

    private func selectedFlagRule(
        title: String,
        flags: Set<String>,
        isExcluded: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isExcluded ? Color.red : Color.orange)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(sorted(flags), id: \.self) { flag in
                    Button {
                        toggle(flag, on: isExcluded ? .exclude : .include)
                    } label: {
                        Label(
                            flag,
                            systemImage: isExcluded ? "flag.slash.fill" : "flag.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isExcluded ? Color.red : Color.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .routinaGlassPill(
                            tint: isExcluded ? .red : .orange,
                            tintOpacity: 0.16,
                            interactive: true
                        )
                        .contentShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transaction { transaction in
                transaction.animation = nil
            }
        }
    }

    private var editFlagFiltersButton: some View {
        Button {
            if selectedFlags.isEmpty && !excludedFlags.isEmpty {
                ruleSide = .exclude
            }
            isPickerPresented = true
        } label: {
            Label("Edit flag filters…", systemImage: "slider.horizontal.3")
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.18))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.34), lineWidth: 1)
        }
        .popover(isPresented: $isPickerPresented, arrowEdge: .trailing) {
            HomeMacSharedFlagFilterPicker(
                ruleSide: $ruleSide,
                options: options,
                selectedFlags: selectedFlags,
                excludedFlags: excludedFlags,
                includeMatchMode: includeFlagMatchMode,
                excludeMatchMode: excludeFlagMatchMode,
                onToggleIncludedFlag: { toggle($0, on: .include) },
                onToggleExcludedFlag: { toggle($0, on: .exclude) },
                onIncludeMatchModeChange: onIncludeFlagMatchModeChange,
                onExcludeMatchModeChange: onExcludeFlagMatchModeChange
            )
        }
    }

    private func ruleTitle(
        _ title: String,
        count: Int,
        matchMode: RoutineTagMatchMode
    ) -> String {
        count > 1 ? "\(title) · \(matchMode.rawValue)" : title
    }

    private func sorted(_ flags: Set<String>) -> [String] {
        flags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func toggle(_ flag: String, on side: HomeMacFilterRuleSide) {
        if side == .include {
            onSelectIncludedFlags(
                HomeFlagFilterMutationSupport.toggled(flag, in: selectedFlags)
            )
        } else {
            onSelectExcludedFlags(
                HomeFlagFilterMutationSupport.toggled(flag, in: excludedFlags)
            )
        }
    }

    private var options: [HomeMacFlagFilterPickerOption] {
        availableFlags.map { HomeMacFlagFilterPickerOption(name: $0, count: nil) }
    }
}

private struct HomeMacSharedFlagFilterPicker: View {
    @Binding var ruleSide: HomeMacFilterRuleSide
    let options: [HomeMacFlagFilterPickerOption]
    let selectedFlags: Set<String>
    let excludedFlags: Set<String>
    let includeMatchMode: RoutineTagMatchMode
    let excludeMatchMode: RoutineTagMatchMode
    let onToggleIncludedFlag: (String) -> Void
    let onToggleExcludedFlag: (String) -> Void
    let onIncludeMatchModeChange: (RoutineTagMatchMode) -> Void
    let onExcludeMatchModeChange: (RoutineTagMatchMode) -> Void

    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flag filters")
                .font(.headline)

            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Flag filter rule",
                options: HomeMacFilterRuleSide.allCases,
                selection: ruleSide,
                onSelect: { ruleSide = $0 },
                fillsAvailableWidth: true
            ) { side in
                Text(side.rawValue)
            }

            if activeSelectedFlags.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(ruleSide.rawValue) when a task has")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "\(ruleSide.rawValue) flag match mode",
                        options: RoutineTagMatchMode.allCases,
                        selection: activeMatchMode,
                        onSelect: selectMatchMode,
                        fillsAvailableWidth: true
                    ) { mode in
                        Text(mode.rawValue)
                    }
                }
            }

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
        .frame(width: 340, height: 460)
    }

    private func pickerSection(
        _ sectionTitle: String,
        options: [HomeMacFlagFilterPickerOption],
        isSelected: Bool
    ) -> some View {
        Section {
            ForEach(options) { option in
                Button {
                    toggle(option.name)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: ruleSide == .exclude ? "flag.slash.fill" : "flag.fill")
                            .foregroundStyle(isSelected ? selectedTint : Color.secondary)
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
                            .foregroundStyle(isSelected ? selectedTint : Color.secondary)
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

    private var activeSelectedFlags: Set<String> {
        ruleSide == .include ? selectedFlags : excludedFlags
    }

    private var activeMatchMode: RoutineTagMatchMode {
        ruleSide == .include ? includeMatchMode : excludeMatchMode
    }

    private var selectedTint: Color {
        ruleSide == .include ? .orange : .red
    }

    private var selectedOptions: [HomeMacFlagFilterPickerOption] {
        allOptions.filter { option in
            HomeFlagFilterMutationSupport.contains(option.name, in: activeSelectedFlags)
        }
    }

    private var availableOptions: [HomeMacFlagFilterPickerOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return allOptions.filter { option in
            !HomeFlagFilterMutationSupport.contains(option.name, in: activeSelectedFlags)
                && (query.isEmpty || option.name.localizedCaseInsensitiveContains(query))
        }
    }

    private var allOptions: [HomeMacFlagFilterPickerOption] {
        var merged = options
        for flag in activeSelectedFlags where !merged.contains(where: {
            HomeFlagFilterMutationSupport.contains($0.name, in: [flag])
        }) {
            merged.append(HomeMacFlagFilterPickerOption(name: flag, count: nil))
        }
        return merged.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func toggle(_ flag: String) {
        if ruleSide == .include {
            onToggleIncludedFlag(flag)
        } else {
            onToggleExcludedFlag(flag)
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

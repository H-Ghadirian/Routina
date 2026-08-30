import SwiftUI

struct TaskFormIOSOrganizationSection: View {
    let model: TaskFormModel
    let tagColor: (String) -> Color?
    let onManageTags: () -> Void

    @Binding var isTagPickerPresented: Bool
    @State private var showsAllAvailableFlags = false
    @State private var tagSuggestionPresentation: TaskFormIOSTagSuggestionPresentation.Data
    @State private var tagAutocompleteSuggestion: String?
    @State private var tagSummariesByID: [String: RoutineTagSummary]
    @AppStorage(
        UserDefaultStringValueKey.appSettingCustomTaskSections.rawValue,
        store: SharedDefaults.app
    ) private var customTaskSectionsRawValue = ""

    init(
        model: TaskFormModel,
        tagColor: @escaping (String) -> Color?,
        isTagPickerPresented: Binding<Bool>,
        onManageTags: @escaping () -> Void
    ) {
        self.model = model
        self.tagColor = tagColor
        _isTagPickerPresented = isTagPickerPresented
        self.onManageTags = onManageTags
        _tagSuggestionPresentation = State(
            initialValue: TaskFormIOSTagSuggestionPresentation.make(
                routineTags: model.routineTags,
                relatedTagRules: model.relatedTagRules,
                availableTags: model.availableTags
            )
        )
        _tagAutocompleteSuggestion = State(
            initialValue: RoutineTag.autocompleteSuggestion(
                for: model.tagDraft.wrappedValue,
                availableTags: model.availableTags,
                selectedTags: model.routineTags
            )
        )
        _tagSummariesByID = State(
            initialValue: Self.makeTagSummariesByID(
                model.availableTagSummaries,
                for: TaskFormIOSTagSuggestionPresentation.make(
                    routineTags: model.routineTags,
                    relatedTagRules: model.relatedTagRules,
                    availableTags: model.availableTags
                ).suggestedTags
            )
        )
    }

    var body: some View {
        Section(header: Text("Organization")) {
            pathPicker

            VStack(alignment: .leading, spacing: 10) {
                Text("Tags")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                tagComposer
                tagChipsContent
                browseTagsButton
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Flags")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                flagEditor
            }

            if model.taskType.wrappedValue == .routine {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Task Ladder group")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Toggle("Use as Task Ladder group", isOn: model.taskLadderGroupEnabled)
                        .disabled(
                            model.taskLadderGroupEnabled.wrappedValue
                                && !model.canDisableTaskLadderGroup
                        )
                    Text(taskLadderGroupHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)
            }
        }
        .onAppear {
            clearMissingPath()
            refreshTagSuggestionPresentationAndSummaries()
            refreshTagAutocompleteSuggestion()
        }
        .onChange(of: model.routineTags) { _, _ in
            refreshTagSuggestionPresentationAndSummaries()
            refreshTagAutocompleteSuggestion()
        }
        .onChange(of: model.relatedTagRules) { _, _ in
            refreshTagSuggestionPresentationAndSummaries()
        }
        .onChange(of: model.availableTags) { _, _ in
            refreshTagSuggestionPresentationAndSummaries()
            refreshTagAutocompleteSuggestion()
        }
        .onChange(of: model.tagDraft.wrappedValue) { _, _ in
            refreshTagAutocompleteSuggestion()
        }
        .onChange(of: model.availableTagSummaries) { _, _ in
            refreshTagSummaries()
        }
        .onChange(of: customTaskSectionsRawValue) { _, _ in
            clearMissingPath()
        }
    }

    private var pathPicker: some View {
        Picker("Path", selection: model.customTaskSectionID) {
            Text("Automatic").tag(Optional<UUID>.none)
            ForEach(customTaskSections) { section in
                Text(pathTitle(for: section))
                    .tag(Optional(section.id))
                    .disabled(section.isPaused)
            }
        }
        .pickerStyle(.navigationLink)
        .accessibilityHint("Choose where the task appears, or let Routina place it automatically")
    }

    private var customTaskSections: [HomeCustomTaskSection] {
        HomeCustomTaskSectionStorage.decoded(from: customTaskSectionsRawValue)
    }

    private func pathTitle(for section: HomeCustomTaskSection) -> String {
        HomeCustomTaskSectionStorage.pathTitles(for: section.id, in: customTaskSections)?
            .joined(separator: " › ")
            ?? section.title
    }

    private func clearMissingPath() {
        guard let sectionID = model.customTaskSectionID.wrappedValue,
              HomeCustomTaskSectionStorage.pathTitles(for: sectionID, in: customTaskSections) == nil
        else { return }
        model.customTaskSectionID.wrappedValue = nil
    }

    private var taskLadderGroupHelpText: String {
        if model.taskLadderGroupEnabled.wrappedValue && !model.canDisableTaskLadderGroup {
            return "Move its nested tasks elsewhere before turning this group off."
        }
        return "Give this repeating task its own nested ladder without changing its schedule."
    }

    private var tagComposer: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .trailing) {
                TextField("health, focus, morning", text: model.tagDraft)
                    .onSubmit { model.onAddTag() }
                    .padding(.trailing, tagAutocompleteSuggestion == nil ? 0 : 88)

                if let suggestion = tagAutocompleteSuggestion {
                    Button {
                        acceptTagAutocompleteSuggestion()
                    } label: {
                        let tint = tagColor(suggestion) ?? .secondary
                        Text("#\(suggestion)")
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .foregroundStyle(tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .routinaGlassPill(tint: tint, tintOpacity: 0.12, interactive: true)
                            .overlay {
                                Capsule()
                                    .stroke(tint.opacity(0.28), lineWidth: 1)
                            }
                        }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.tab, modifiers: [])
                }
            }

            Button { model.onAddTag() } label: {
                Image(systemName: "plus")
            }
            .disabled(RoutineTag.parseDraft(model.tagDraft.wrappedValue).isEmpty)
            .accessibilityLabel("Add tag")

            Button(action: onManageTags) {
                Image(systemName: "slider.horizontal.3")
            }
            .accessibilityLabel("Manage Tags")
        }
    }

    @ViewBuilder
    private var tagChipsContent: some View {
        if !model.routineTags.isEmpty
            || !tagSuggestionPresentation.relatedTags.isEmpty
            || tagSuggestionPresentation.remainingTagCount > 0 {
            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(model.routineTags, id: \.self) { tag in
                    selectedTagButton(tag)
                }

                ForEach(tagSuggestionPresentation.relatedTags, id: \.self) { tag in
                    relatedTagButton(tag)
                }

                ForEach(visibleAvailableTags, id: \.self) { tag in
                    availableTagButton(tag)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var browseTagsButton: some View {
        if tagSuggestionPresentation.remainingTagCount
            > TaskFormIOSTagSuggestionPresentation.collapsedLimit {
            Button {
                isTagPickerPresented = true
            } label: {
                HStack(spacing: 12) {
                    Label("Browse all tags", systemImage: "magnifyingglass")
                    Spacer()
                    Text("\(tagSuggestionPresentation.remainingTagCount)")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Search and select saved tags")
        }
    }

    private var flagEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !visibleRoutineFlags.isEmpty {
                HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(visibleRoutineFlags, id: \.self) { flag in
                        Button { model.onRemoveFlag(flag) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "flag.fill")
                                Text(flag).lineLimit(1)
                                Image(systemName: "xmark.circle.fill").font(.caption)
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .routinaGlassPill(tint: .orange, tintOpacity: 0.14, interactive: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove flag \(flag)")
                    }
                }
            }

            if let message = model.flagSelectionValidationMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !unselectedAvailableFlags.isEmpty {
                HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(visibleAvailableFlags, id: \.self) { flag in
                        availableFlagButton(flag)
                    }

                    if canToggleAvailableFlags {
                        availableFlagsExpansionButton
                    }
                }
            }
        }
    }

    private var visibleRoutineFlags: [String] {
        RoutineFlag.iOSVisible(model.routineFlags)
    }

    private var unselectedAvailableFlags: [String] {
        RoutineFlag.iOSVisible(model.availableFlags)
            .filter { !RoutineFlag.contains($0, in: model.routineFlags) }
    }

    private var visibleAvailableFlags: [String] {
        TaskFormFlagSuggestionPresentation.visibleAvailableFlags(
            unselectedAvailableFlags,
            showsAll: showsAllAvailableFlags
        )
    }

    private var canToggleAvailableFlags: Bool {
        unselectedAvailableFlags.count > TaskFormFlagSuggestionPresentation.collapsedLimit
    }

    private var availableFlagsExpansionButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showsAllAvailableFlags.toggle()
            }
        } label: {
            Label(
                showsAllAvailableFlags ? "Show less" : "Show all (\(unselectedAvailableFlags.count))",
                systemImage: showsAllAvailableFlags ? "chevron.up" : "chevron.down"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsAllAvailableFlags ? "Show fewer flags" : "Show all flags")
    }

    private func availableFlagButton(_ flag: String) -> some View {
        Button { model.onToggleFlagSelection(flag) } label: {
            HStack(spacing: 6) {
                Image(systemName: "flag")
                    .font(.caption)
                Text(flag).lineLimit(1)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .routinaGlassPill(tint: .orange, tintOpacity: 0.10, interactive: true)
            .overlay {
                Capsule()
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add flag \(flag)")
    }

    private func selectedTagButton(_ tag: String) -> some View {
        let tint = tagColor(tag) ?? .accentColor
        return Button { model.onRemoveTag(tag) } label: {
            HStack(spacing: 6) {
                Text("#\(tag)").lineLimit(1)
                Image(systemName: "xmark.circle.fill").font(.caption)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .routinaGlassPill(tint: tint, tintOpacity: 0.14, interactive: true)
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove tag \(tag)")
    }

    private func relatedTagButton(_ tag: String) -> some View {
        let tint = tagColor(tag) ?? .orange
        return Button { model.onToggleTagSelection(tag) } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                Text("#\(tag)").lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .routinaGlassPill(tint: tint, tintOpacity: 0.10, interactive: true)
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add suggested related tag \(tag)")
    }

    private func availableTagButton(_ tag: String) -> some View {
        let summary = tagSummariesByID[tagID(for: tag)]
        let tint = tagColor(tag) ?? .secondary

        return Button { model.onToggleTagSelection(tag) } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.caption)
                Text(tagChipTitle(tag: tag, summary: summary)).lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .routinaGlassPill(
                tint: tint,
                tintOpacity: 0.10,
                interactive: true
            )
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add tag \(tag)")
    }

    private var visibleAvailableTags: [String] {
        tagSuggestionPresentation.suggestedTags
    }

    private func tagChipTitle(tag: String, summary: RoutineTagSummary?) -> String {
        TagCounterFormatting.chipTitle(
            tag: tag,
            summary: summary,
            mode: model.tagCounterDisplayMode
        )
    }

    private func refreshTagSuggestionPresentationAndSummaries() {
        tagSuggestionPresentation = TaskFormIOSTagSuggestionPresentation.make(
            routineTags: model.routineTags,
            relatedTagRules: model.relatedTagRules,
            availableTags: model.availableTags
        )
        refreshTagSummaries()
    }

    private func refreshTagAutocompleteSuggestion() {
        tagAutocompleteSuggestion = RoutineTag.autocompleteSuggestion(
            for: model.tagDraft.wrappedValue,
            availableTags: model.availableTags,
            selectedTags: model.routineTags
        )
    }

    private func acceptTagAutocompleteSuggestion() {
        guard let tagAutocompleteSuggestion else { return }
        model.tagDraft.wrappedValue = RoutineTag.acceptingAutocompleteSuggestion(
            tagAutocompleteSuggestion,
            in: model.tagDraft.wrappedValue
        )
    }

    private func refreshTagSummaries() {
        tagSummariesByID = Self.makeTagSummariesByID(
            model.availableTagSummaries,
            for: tagSuggestionPresentation.suggestedTags
        )
    }

    private func tagID(for tag: String) -> String {
        RoutineTag.normalized(tag) ?? tag
    }

    private static func makeTagSummariesByID(
        _ summaries: [RoutineTagSummary],
        for tags: [String]
    ) -> [String: RoutineTagSummary] {
        let tagIDs = Set(tags.map { RoutineTag.normalized($0) ?? $0 })
        return summaries.reduce(into: [String: RoutineTagSummary]()) { results, summary in
            guard tagIDs.contains(summary.id), results[summary.id] == nil else { return }
            results[summary.id] = summary
        }
    }
}

enum TaskFormIOSTagSuggestionPresentation {
    static let collapsedLimit = 6

    struct Data: Equatable {
        let relatedTags: [String]
        let suggestedTags: [String]
        let remainingTagCount: Int
    }

    static func make(
        routineTags: [String],
        relatedTagRules: [RoutineRelatedTagRule],
        availableTags: [String]
    ) -> Data {
        let selectedTagIDs = Set(routineTags.map { RoutineTag.normalized($0) ?? $0 })
        let relatedTags = RoutineTagRelations.relatedTags(
            for: routineTags,
            rules: relatedTagRules,
            availableTags: availableTags
        ).filter { !selectedTagIDs.contains(RoutineTag.normalized($0) ?? $0) }
        let relatedTagIDs = Set(relatedTags.map { RoutineTag.normalized($0) ?? $0 })
        var suggestedTags: [String] = []
        var remainingTagCount = 0

        for tag in availableTags {
            let tagID = RoutineTag.normalized(tag) ?? tag
            guard !selectedTagIDs.contains(tagID), !relatedTagIDs.contains(tagID) else {
                continue
            }

            remainingTagCount += 1
            if suggestedTags.count < collapsedLimit {
                suggestedTags.append(tag)
            }
        }

        return Data(
            relatedTags: relatedTags,
            suggestedTags: suggestedTags,
            remainingTagCount: remainingTagCount
        )
    }
}

struct TaskFormIOSTagPicker: View {
    let availableTags: [String]
    let selectedTags: [String]
    let availableTagSummaries: [RoutineTagSummary]
    let tagCounterDisplayMode: TagCounterDisplayMode
    let onToggleTagSelection: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var displayedTags: [String] = []
    @State private var selectedTagIDs = Set<String>()
    @State private var tagTitlesByID = [String: String]()

    var body: some View {
        NavigationStack {
            List {
                if displayedTags.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(displayedTags, id: \.self) { tag in
                        tagRow(tag)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Tags")
            .searchable(text: $searchText, prompt: "Search tags")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear(perform: refreshDisplayedTags)
            .onAppear(perform: refreshSelectedTagIDs)
            .onAppear(perform: refreshTagTitles)
            .onChange(of: searchText) { _, _ in
                refreshDisplayedTags()
            }
            .onChange(of: availableTags) { _, _ in
                refreshDisplayedTags()
                refreshTagTitles()
            }
            .onChange(of: selectedTags) { _, _ in
                refreshSelectedTagIDs()
            }
            .onChange(of: availableTagSummaries) { _, _ in
                refreshTagTitles()
            }
            .onChange(of: tagCounterDisplayMode) { _, _ in
                refreshTagTitles()
            }
        }
    }

    private func tagRow(_ tag: String) -> some View {
        let isSelected = selectedTagIDs.contains(tagID(for: tag))
        let tint = Color.accentColor

        return Button {
            onToggleTagSelection(tag)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(isSelected ? tint : .secondary)
                Text(tagChipTitle(tag))
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Text("Selected")
                        .font(.caption)
                        .foregroundStyle(tint)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Remove tag \(tag)" : "Add tag \(tag)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func refreshDisplayedTags() {
        guard let normalizedQuery = RoutineTag.normalized(searchText) else {
            displayedTags = availableTags
            return
        }

        displayedTags = availableTags.filter { tag in
            RoutineTag.normalized(tag)?.localizedCaseInsensitiveContains(normalizedQuery) == true
        }
    }

    private func tagChipTitle(_ tag: String) -> String {
        tagTitlesByID[tagID(for: tag)] ?? "#\(tag)"
    }

    private func refreshSelectedTagIDs() {
        selectedTagIDs = Set(selectedTags.map(tagID(for:)))
    }

    private func refreshTagTitles() {
        let summariesByID = Dictionary(
            availableTagSummaries.map { summary in
                (summary.id, summary)
            },
            uniquingKeysWith: { existing, _ in existing }
        )
        tagTitlesByID = Dictionary(
            availableTags.map { tag in
                (
                    tagID(for: tag),
                    TagCounterFormatting.chipTitle(
                        tag: tag,
                        summary: summariesByID[tagID(for: tag)],
                        mode: tagCounterDisplayMode
                    )
                )
            },
            uniquingKeysWith: { existing, _ in existing }
        )
    }

    private func tagID(for tag: String) -> String {
        RoutineTag.normalized(tag) ?? tag
    }
}

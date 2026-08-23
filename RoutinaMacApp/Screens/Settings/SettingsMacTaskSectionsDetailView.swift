import SwiftData
import SwiftUI

struct SettingsMacTaskSectionsDetailView: View {
    let availableTagSummaries: [RoutineTagSummary]

    @Environment(\.modelContext) private var modelContext
    @AppStorage(
        UserDefaultStringValueKey.appSettingCustomTaskSections.rawValue,
        store: SharedDefaults.app
    ) private var customTaskSectionsRawValue = ""
    @AppStorage(
        UserDefaultStringValueKey.appSettingCollapsedTagTaskListSections.rawValue,
        store: SharedDefaults.app
    ) private var collapsedTaskListSectionIDsStorage = ""

    @State private var newSectionTitle = ""
    @State private var newSubsectionTitles: [UUID: String] = [:]
    @State private var drafts = HomeCustomTaskSectionDraftState()
    @State private var selectedSurface: HomeTaskSectionSurface = .radar
    @State private var expandedSectionID: UUID?
    @State private var didInitializeExpansion = false
    @State private var pendingDeleteSection: HomeCustomTaskSection?
    @State private var isDeleteConfirmationPresented = false
    @State private var statusMessage = ""
    @State private var tagRuleInputs: [UUID: String] = [:]

    var body: some View {
        SettingsMacDetailShell(
            title: "Sections",
            subtitle: "Organize the task list with custom sections and subsections."
        ) {
            SettingsMacDetailCard(title: "Custom Sections") {
                newSectionComposer

                if superSections.isEmpty {
                    emptySectionsView
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(superSections) { section in
                            sectionCard(for: section)
                        }
                    }
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear(perform: prepareSectionEditor)
        .onChange(of: customTaskSectionsRawValue) { _, _ in
            syncRenameDrafts()
            normalizeExpandedSection()
        }
        .onChange(of: selectedSurface) { _, _ in
            normalizeExpandedSection()
        }
        .alert(deleteConfirmationTitle, isPresented: $isDeleteConfirmationPresented) {
            Button("Delete", role: .destructive) {
                confirmDeleteSection()
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteSection = nil
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    private var customTaskSections: [HomeCustomTaskSection] {
        HomeCustomTaskSectionStorage.decoded(from: customTaskSectionsRawValue)
    }

    private var superSections: [HomeCustomTaskSection] {
        HomeCustomTaskSectionStorage.topLevelSections(
            in: customTaskSections,
            surface: selectedSurface
        )
    }

    private var canCreateSection: Bool {
        guard let result = HomeCustomTaskSectionStorage.upsertingSection(
            title: newSectionTitle,
            surface: selectedSurface,
            in: customTaskSections
        ) else {
            return false
        }
        return result.sections.count > customTaskSections.count
    }

    private var newSectionComposer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Section destination", selection: $selectedSurface) {
                Text("Main task list")
                    .tag(HomeTaskSectionSurface.radar)
                Text("Backlog")
                    .tag(HomeTaskSectionSurface.backlog)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Section destination")

            HStack(spacing: 10) {
                TextField(newSectionPlaceholder, text: $newSectionTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(createSection)

                Button {
                    createSection()
                } label: {
                    Label("Add Section", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreateSection)
            }

            if let newSectionValidationMessage {
                Text(newSectionValidationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var newSectionValidationMessage: String? {
        guard HomeCustomTaskSectionStorage.sanitizedTitle(newSectionTitle) != nil,
              !canCreateSection else {
            return nil
        }
        return "A section with this name already exists."
    }

    private var emptySectionsView: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.3.group")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.secondary.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("No \(selectedSurface.displayName) sections")
                    .font(.subheadline.weight(.semibold))

                Text("Add one above to create a new section in this area.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var deleteConfirmationTitle: String {
        pendingDeleteSection?.parentSectionID == nil
            ? "Delete Section?"
            : "Delete Subsection?"
    }

    private var deleteConfirmationMessage: String {
        guard let pendingDeleteSection else {
            return "Assigned tasks will return to their automatic task-list placement."
        }

        let subsections = HomeCustomTaskSectionStorage.subsections(
            of: pendingDeleteSection.id,
            in: customTaskSections
        )
        let descendantText: String
        if subsections.isEmpty {
            descendantText = ""
        } else if subsections.count == 1 {
            descendantText = " and its subsection"
        } else {
            descendantText = " and its \(subsections.count) subsections"
        }

        return "Delete \"\(pendingDeleteSection.title)\"\(descendantText)? Assigned tasks will return to their automatic task-list placement."
    }

    @ViewBuilder
    private func sectionCard(for section: HomeCustomTaskSection) -> some View {
        let isExpanded = expandedSectionID == section.id

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Button {
                    toggleSection(section.id)
                } label: {
                    sectionHeader(for: section, isExpanded: isExpanded)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title)
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

                sectionActionsMenu(for: section)
            }
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .padding(.vertical, 6)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                sectionDetails(for: section)
                    .padding(14)
                    // Keep the editor's contents stationary while the card's
                    // layout height animates. A move+opacity transition lets
                    // controls escape the card and produces ghosted frames.
                    .transition(.identity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(isExpanded ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    sectionTint(for: section).opacity(isExpanded ? 0.28 : 0.12),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut(duration: 0.16), value: isExpanded)
    }

    private func sectionHeader(
        for section: HomeCustomTaskSection,
        isExpanded: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 12)

            Circle()
                .fill(sectionTint(for: section))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(sectionSummary(for: section))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func sectionActionsMenu(for section: HomeCustomTaskSection) -> some View {
        Menu {
            Button {
                moveSection(section, by: -1)
            } label: {
                Label("Move Up", systemImage: "arrow.up")
            }
            .disabled(!canMoveSection(section, by: -1))

            Button {
                moveSection(section, by: 1)
            } label: {
                Label("Move Down", systemImage: "arrow.down")
            }
            .disabled(!canMoveSection(section, by: 1))

            Divider()

            Button(role: .destructive) {
                requestDelete(section)
            } label: {
                Label("Delete Section…", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Section actions")
        .accessibilityLabel("More actions for \(section.title)")
    }

    private func sectionDetails(for section: HomeCustomTaskSection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionNameEditor(for: section)
            sectionColorEditor(for: section)

            Divider()

            tagRuleEditor(for: section)

            Divider()

            subsectionEditor(for: section)
        }
    }

    private func sectionNameEditor(for section: HomeCustomTaskSection) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                settingsFieldLabel("Name")

                TextField("Section name", text: titleDraftBinding(for: section))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveTitle(for: section) }

                if hasTitleChanges(for: section) {
                    Button {
                        drafts.titleDrafts[section.id] = section.title
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .help("Discard name change")

                    Button {
                        saveTitle(for: section)
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSaveTitle(for: section))
                }
            }

            if let titleValidationMessage = titleValidationMessage(for: section) {
                Text(titleValidationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 80)
            }
        }
    }

    private func sectionColorEditor(for section: HomeCustomTaskSection) -> some View {
        HStack(spacing: 8) {
            settingsFieldLabel("Color")

            ColorPicker(
                "Section color",
                selection: colorBinding(for: section),
                supportsOpacity: false
            )
            .labelsHidden()

            Text(section.colorHex == nil ? "Default" : "Custom")
                .font(.caption)
                .foregroundStyle(.secondary)

            if section.colorHex != nil {
                Button("Reset") {
                    setColor(nil, for: section.id)
                }
                .buttonStyle(.borderless)
            }

            Spacer()
        }
    }

    private func tagRuleEditor(for section: HomeCustomTaskSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Label("Automatic tags", systemImage: "tag")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Picker(
                    "Tag matching",
                    selection: tagMatchModeBinding(for: section)
                ) {
                    Text("Any").tag(RoutineTagMatchMode.any)
                    Text("All").tag(RoutineTagMatchMode.all)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 136)
                .accessibilityLabel("Automatic tag matching")
            }

            Text(tagMatchModeDescription(for: section))
                .font(.caption)
                .foregroundStyle(.secondary)

            tagRuleComposer(for: section)
            tagRuleChips(for: section)

            if hasTagRuleChanges(for: section) {
                HStack(spacing: 8) {
                    Button {
                        discardTagRuleChanges(for: section)
                    } label: {
                        Label("Revert", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        saveTagRule(for: section)
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if !section.rules.tagNames.isEmpty {
                Button("Clear all") {
                    clearTagRule(for: section)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func tagRuleComposer(for section: HomeCustomTaskSection) -> some View {
        HStack(spacing: 8) {
            ZStack(alignment: .trailing) {
                MacTagAutocompleteTextField(
                    placeholder: "Add a tag",
                    text: tagRuleInputBinding(for: section),
                    suggestion: tagAutocompleteSuggestion(for: section),
                    onSubmit: { addTagRuleInput(for: section) },
                    onAcceptSuggestion: {
                        acceptTagAutocompleteSuggestion(for: section)
                    }
                )
                .frame(height: 28)

                if let suggestion = tagAutocompleteSuggestion(for: section) {
                    Button {
                        acceptTagAutocompleteSuggestion(for: section)
                    } label: {
                        HStack(spacing: 6) {
                            Text("#\(suggestion)")
                                .lineLimit(1)
                            Text("Tab")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .routinaGlassCard(
                                    cornerRadius: 4,
                                    tint: .secondary,
                                    tintOpacity: 0.08
                                )
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(tagTint(for: suggestion))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .routinaGlassPill(
                            tint: tagTint(for: suggestion),
                            tintOpacity: 0.12,
                            interactive: true
                        )
                        .overlay {
                            Capsule()
                                .stroke(tagTint(for: suggestion).opacity(0.28), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 5)
                    .help("Press Tab to complete #\(suggestion)")
                }
            }

            Button {
                addTagRuleInput(for: section)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.bordered)
            .disabled(
                RoutineTag.parseDraft(tagRuleInputs[section.id] ?? "").isEmpty
            )
            .accessibilityLabel("Add automatic tag")
            .help("Add automatic tag")
        }
    }

    @ViewBuilder
    private func tagRuleChips(for section: HomeCustomTaskSection) -> some View {
        let tags = parsedTagRuleDraft(for: section)

        if !tags.isEmpty {
            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button {
                        removeTagRuleDraftTag(tag, from: section)
                    } label: {
                        HStack(spacing: 6) {
                            Text("#\(tag)")
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                        .foregroundStyle(tagTint(for: tag))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .routinaGlassPill(
                            tint: tagTint(for: tag),
                            tintOpacity: 0.14,
                            interactive: true
                        )
                        .overlay {
                            Capsule()
                                .stroke(tagTint(for: tag).opacity(0.28), lineWidth: 1)
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityLabel("Remove automatic tag \(tag)")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func subsectionEditor(for section: HomeCustomTaskSection) -> some View {
        let subsections = HomeCustomTaskSectionStorage.subsections(
            of: section.id,
            in: customTaskSections
        )

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Subsections", systemImage: "rectangle.inset.filled")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if !subsections.isEmpty {
                    Text("\(subsections.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if subsections.isEmpty {
                Text("No subsections")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(subsections) { subsection in
                    subsectionRow(subsection)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                TextField(
                    "New subsection name",
                    text: newSubsectionTitleBinding(for: section.id)
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit { createSubsection(in: section.id) }

                Button("Add") {
                    createSubsection(in: section.id)
                }
                .buttonStyle(.bordered)
                .disabled(!canCreateSubsection(in: section.id))
            }

            if let message = newSubsectionValidationMessage(in: section.id) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28)
            }
        }
    }

    private func subsectionRow(_ subsection: HomeCustomTaskSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.inset.filled")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                TextField("Subsection name", text: titleDraftBinding(for: subsection))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveTitle(for: subsection) }

                if hasTitleChanges(for: subsection) {
                    Button {
                        drafts.titleDrafts[subsection.id] = subsection.title
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .help("Discard name change")

                    Button {
                        saveTitle(for: subsection)
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSaveTitle(for: subsection))
                }

                subsectionActionsMenu(for: subsection)
            }

            if let titleValidationMessage = titleValidationMessage(for: subsection) {
                Text(titleValidationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28)
            }
        }
    }

    private func subsectionActionsMenu(for subsection: HomeCustomTaskSection) -> some View {
        Menu {
            Button {
                moveSection(subsection, by: -1)
            } label: {
                Label("Move Up", systemImage: "arrow.up")
            }
            .disabled(!canMoveSection(subsection, by: -1))

            Button {
                moveSection(subsection, by: 1)
            } label: {
                Label("Move Down", systemImage: "arrow.down")
            }
            .disabled(!canMoveSection(subsection, by: 1))

            Divider()

            Button(role: .destructive) {
                requestDelete(subsection)
            } label: {
                Label("Delete Subsection…", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Subsection actions")
        .accessibilityLabel("More actions for \(subsection.title)")
    }

    private func settingsFieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(width: 64, alignment: .leading)
    }

    private func newSubsectionTitleBinding(for sectionID: UUID) -> Binding<String> {
        Binding(
            get: { newSubsectionTitles[sectionID] ?? "" },
            set: { newSubsectionTitles[sectionID] = $0 }
        )
    }

    private func titleDraftBinding(for section: HomeCustomTaskSection) -> Binding<String> {
        Binding(
            get: { drafts.titleDrafts[section.id] ?? section.title },
            set: { drafts.titleDrafts[section.id] = $0 }
        )
    }

    private func tagRuleInputBinding(for section: HomeCustomTaskSection) -> Binding<String> {
        Binding(
            get: { tagRuleInputs[section.id] ?? "" },
            set: { tagRuleInputs[section.id] = $0 }
        )
    }

    private func tagMatchModeBinding(
        for section: HomeCustomTaskSection
    ) -> Binding<RoutineTagMatchMode> {
        Binding(
            get: {
                customTaskSections.first(where: { $0.id == section.id })?
                    .rules.tagMatchMode ?? section.rules.tagMatchMode
            },
            set: { setTagMatchMode($0, for: section.id) }
        )
    }

    private func colorBinding(for section: HomeCustomTaskSection) -> Binding<Color> {
        Binding(
            get: { Color(routineTagHex: section.colorHex) ?? .accentColor },
            set: { setColor($0.routineTagHex, for: section.id) }
        )
    }

    private func sectionTint(for section: HomeCustomTaskSection) -> Color {
        Color(routineTagHex: section.colorHex) ?? .secondary
    }

    private func sectionSummary(for section: HomeCustomTaskSection) -> String {
        let subsections = HomeCustomTaskSectionStorage.subsections(
            of: section.id,
            in: customTaskSections
        )
        var summaryParts: [String] = []

        if section.isPaused {
            summaryParts.append("Paused")
        }

        if !section.rules.tagNames.isEmpty {
            let visibleTags = section.rules.tagNames.prefix(2).joined(separator: ", ")
            let remainingCount = section.rules.tagNames.count - 2
            let suffix = remainingCount > 0 ? " +\(remainingCount)" : ""
            summaryParts.append(
                "\(section.rules.tagMatchMode.rawValue) tags: \(visibleTags)\(suffix)"
            )
        }

        if !subsections.isEmpty {
            summaryParts.append(
                subsections.count == 1
                    ? "1 subsection"
                    : "\(subsections.count) subsections"
            )
        }

        return summaryParts.isEmpty
            ? "No automatic tags or subsections"
            : summaryParts.joined(separator: " • ")
    }

    private func toggleSection(_ sectionID: UUID) {
        withAnimation(.easeInOut(duration: 0.16)) {
            expandedSectionID = expandedSectionID == sectionID ? nil : sectionID
        }
    }

    private func canMoveSection(
        _ section: HomeCustomTaskSection,
        by offset: Int
    ) -> Bool {
        HomeCustomTaskSectionStorage.movingSection(
            section.id,
            by: offset,
            surface: section.parentSectionID == nil ? section.surface : nil,
            in: customTaskSections
        ) != nil
    }

    private func moveSection(
        _ section: HomeCustomTaskSection,
        by offset: Int
    ) {
        guard let sections = HomeCustomTaskSectionStorage.movingSection(
            section.id,
            by: offset,
            surface: section.parentSectionID == nil ? section.surface : nil,
            in: customTaskSections
        ) else {
            return
        }

        persistSections(sections)
        statusMessage = ""
    }

    private func hasTitleChanges(for section: HomeCustomTaskSection) -> Bool {
        (drafts.titleDrafts[section.id] ?? section.title) != section.title
    }

    private func titleValidationMessage(
        for section: HomeCustomTaskSection
    ) -> String? {
        guard hasTitleChanges(for: section) else { return nil }
        let draft = drafts.titleDrafts[section.id] ?? section.title

        guard let sanitizedTitle = HomeCustomTaskSectionStorage.sanitizedTitle(draft) else {
            return "A name is required."
        }
        guard sanitizedTitle != section.title else {
            return "No name change to save."
        }
        guard HomeCustomTaskSectionStorage.renamingSection(
            section.id,
            title: draft,
            in: customTaskSections
        ) != nil else {
            return section.parentSectionID == nil
                ? "Another section already uses this name."
                : "Another subsection already uses this name."
        }
        return nil
    }

    private func canSaveTitle(for section: HomeCustomTaskSection) -> Bool {
        let draft = drafts.titleDrafts[section.id] ?? section.title
        guard HomeCustomTaskSectionStorage.sanitizedTitle(draft) != section.title else {
            return false
        }
        return HomeCustomTaskSectionStorage.renamingSection(
            section.id,
            title: draft,
            in: customTaskSections
        ) != nil
    }

    private func hasTagRuleChanges(for section: HomeCustomTaskSection) -> Bool {
        parsedTagRuleDraft(for: section) != section.rules.tagNames
    }

    private func tagMatchModeDescription(for section: HomeCustomTaskSection) -> String {
        switch (section.surface, section.rules.tagMatchMode) {
        case (.radar, .any):
            return "Main task list tasks with any one of these tags appear here unless assigned to another Main task list section."
        case (.radar, .all):
            return "Main task list tasks containing every one of these tags appear here unless assigned to another Main task list section."
        case (.backlog, .any):
            return "Hidden tasks with any one of these tags appear here unless assigned to another Backlog section."
        case (.backlog, .all):
            return "Hidden tasks containing every one of these tags appear here unless assigned to another Backlog section."
        }
    }

    private var availableTags: [String] {
        availableTagSummaries.map(\.name)
    }

    private func tagAutocompleteSuggestion(
        for section: HomeCustomTaskSection
    ) -> String? {
        RoutineTag.autocompleteSuggestion(
            for: tagRuleInputs[section.id] ?? "",
            availableTags: availableTags,
            selectedTags: parsedTagRuleDraft(for: section)
        )
    }

    private func acceptTagAutocompleteSuggestion(
        for section: HomeCustomTaskSection
    ) {
        guard let suggestion = tagAutocompleteSuggestion(for: section) else {
            return
        }

        tagRuleInputs[section.id] = RoutineTag.acceptingAutocompleteSuggestion(
            suggestion,
            in: tagRuleInputs[section.id] ?? ""
        )
    }

    private func addTagRuleInput(for section: HomeCustomTaskSection) {
        let input = tagRuleInputs[section.id] ?? ""
        guard !RoutineTag.parseDraft(input).isEmpty else { return }

        let tags = RoutineTag.appending(
            input,
            to: parsedTagRuleDraft(for: section),
            availableTags: availableTags
        )
        drafts.tagRuleDrafts[section.id] = tagRuleDraftText(for: tags)
        tagRuleInputs[section.id] = ""
    }

    private func removeTagRuleDraftTag(
        _ tag: String,
        from section: HomeCustomTaskSection
    ) {
        let tags = RoutineTag.removing(tag, from: parsedTagRuleDraft(for: section))
        drafts.tagRuleDrafts[section.id] = tagRuleDraftText(for: tags)
    }

    private func discardTagRuleChanges(for section: HomeCustomTaskSection) {
        drafts.tagRuleDrafts[section.id] = tagRuleDraftText(
            for: section.rules.tagNames
        )
        tagRuleInputs[section.id] = ""
    }

    private func tagTint(for tag: String) -> Color {
        availableTagSummaries.first {
            RoutineTag.normalized($0.name) == RoutineTag.normalized(tag)
        }?.displayColor ?? .accentColor
    }

    private func newSubsectionValidationMessage(in sectionID: UUID) -> String? {
        let draft = newSubsectionTitles[sectionID] ?? ""
        guard HomeCustomTaskSectionStorage.sanitizedTitle(draft) != nil,
              !canCreateSubsection(in: sectionID) else {
            return nil
        }
        return "A subsection with this name already exists."
    }

    private func createSection() {
        guard let result = HomeCustomTaskSectionStorage.upsertingSection(
            title: newSectionTitle,
            surface: selectedSurface,
            in: customTaskSections
        ),
              result.sections.count > customTaskSections.count else {
            return
        }

        persistSections(result.sections)
        drafts.titleDrafts[result.section.id] = result.section.title
        drafts.tagRuleDrafts[result.section.id] = ""
        newSectionTitle = ""
        expandedSectionID = result.section.id
        statusMessage = ""
    }

    private func canCreateSubsection(in sectionID: UUID) -> Bool {
        guard let result = HomeCustomTaskSectionStorage.upsertingSection(
            title: newSubsectionTitles[sectionID] ?? "",
            parentSectionID: sectionID,
            in: customTaskSections
        ) else {
            return false
        }
        return result.sections.count > customTaskSections.count
    }

    private func createSubsection(in sectionID: UUID) {
        guard let result = HomeCustomTaskSectionStorage.upsertingSection(
            title: newSubsectionTitles[sectionID] ?? "",
            parentSectionID: sectionID,
            in: customTaskSections
        ),
              result.sections.count > customTaskSections.count else {
            return
        }
        persistSections(result.sections)
        newSubsectionTitles[sectionID] = ""
        statusMessage = ""
    }

    private func saveTitle(for section: HomeCustomTaskSection) {
        let draft = drafts.titleDrafts[section.id] ?? section.title
        guard let sections = HomeCustomTaskSectionStorage.renamingSection(
            section.id,
            title: draft,
            in: customTaskSections
        ) else {
            return
        }

        persistSections(sections)
        statusMessage = ""
    }

    private func saveTagRule(for section: HomeCustomTaskSection) {
        let tagNames = parsedTagRuleDraft(for: section)
        guard let sections = HomeCustomTaskSectionStorage.settingTagNames(
            tagNames,
            for: section.id,
            in: customTaskSections
        ) else {
            return
        }

        persistSections(sections)
        tagRuleInputs[section.id] = ""
        statusMessage = ""
    }

    private func clearTagRule(for section: HomeCustomTaskSection) {
        drafts.tagRuleDrafts[section.id] = ""
        tagRuleInputs[section.id] = ""
        saveTagRule(for: section)
    }

    private func setTagMatchMode(
        _ tagMatchMode: RoutineTagMatchMode,
        for sectionID: UUID
    ) {
        guard let sections = HomeCustomTaskSectionStorage.settingTagMatchMode(
            tagMatchMode,
            for: sectionID,
            in: customTaskSections
        ) else {
            return
        }

        persistSections(sections)
        statusMessage = ""
    }

    private func setColor(_ colorHex: String?, for sectionID: UUID) {
        guard let sections = HomeCustomTaskSectionStorage.settingColor(
            colorHex,
            for: sectionID,
            in: customTaskSections
        ) else {
            return
        }

        persistSections(sections)
        statusMessage = ""
    }

    private func requestDelete(_ section: HomeCustomTaskSection) {
        pendingDeleteSection = section
        isDeleteConfirmationPresented = true
    }

    private func confirmDeleteSection() {
        guard let section = pendingDeleteSection else { return }
        let deletedSectionIDs = HomeCustomTaskSectionStorage.sectionAndDescendantIDs(
            for: section.id,
            in: customTaskSections
        )
        persistSections(
            HomeCustomTaskSectionStorage.deletingSection(section.id, from: customTaskSections)
        )
        for sectionID in deletedSectionIDs {
            removeCollapseState(for: sectionID)
        }
        if expandedSectionID.map(deletedSectionIDs.contains) == true {
            expandedSectionID = nil
        }
        statusMessage = ""
        clearDeletedSectionAssignments(deletedSectionIDs)
        pendingDeleteSection = nil
    }

    private func persistSections(_ sections: [HomeCustomTaskSection]) {
        customTaskSectionsRawValue = HomeCustomTaskSectionStorage.encoded(sections)
        AppSettingsPersistenceMirror.schedule()
        syncRenameDrafts(with: sections)
    }

    private func syncRenameDrafts() {
        syncRenameDrafts(with: customTaskSections)
    }

    private func syncRenameDrafts(with sections: [HomeCustomTaskSection]) {
        drafts.sync(with: sections)
        let validSectionIDs = Set(sections.map(\.id))
        tagRuleInputs = tagRuleInputs.filter { validSectionIDs.contains($0.key) }
    }

    private func prepareSectionEditor() {
        syncRenameDrafts()
        guard !didInitializeExpansion else { return }
        expandedSectionID = superSections.first?.id
        didInitializeExpansion = true
    }

    private var newSectionPlaceholder: String {
        "New \(selectedSurface.displayName.lowercased()) section"
    }

    private func normalizeExpandedSection() {
        guard let expandedSectionID else { return }
        if !superSections.contains(where: { $0.id == expandedSectionID }) {
            self.expandedSectionID = nil
        }
    }

    private func parsedTagRuleDraft(for section: HomeCustomTaskSection) -> [String] {
        HomeCustomTaskSectionRules.sanitizedTagNames(
            RoutineTag.parseDraft(
                drafts.tagRuleDrafts[section.id] ?? tagRuleDraftText(for: section.rules.tagNames)
            )
        )
    }

    private func tagRuleDraftText(for tagNames: [String]) -> String {
        tagNames.joined(separator: ", ")
    }

    private func removeCollapseState(for sectionID: UUID) {
        let deletedPresentationID = "\(HomeTaskListPresentationSectionKind.custom.rawValue):\(HomeCustomTaskSectionStorage.manualOrderSectionKey(for: sectionID))"
        var collapsedIDs = Set(collapsedTaskListSectionIDsStorage.split(separator: "\n").map(String.init))
        collapsedIDs.remove(deletedPresentationID)
        collapsedTaskListSectionIDsStorage = collapsedIDs.sorted().joined(separator: "\n")
    }

    private func clearDeletedSectionAssignments(_ sectionIDs: Set<UUID>) {
        let sectionKeys = Set(sectionIDs.map(HomeCustomTaskSectionStorage.manualOrderSectionKey(for:)))

        do {
            let tasks = try modelContext.fetch(FetchDescriptor<RoutineTask>())
            var didChangeTasks = false

            for task in tasks {
                var didChangeTask = false

                if task.customTaskSectionID.map(sectionIDs.contains) == true {
                    task.customTaskSectionID = nil
                    didChangeTask = true
                }

                var manualSectionOrders = task.manualSectionOrders
                let originalCount = manualSectionOrders.count
                manualSectionOrders = manualSectionOrders.filter { !sectionKeys.contains($0.key) }
                if manualSectionOrders.count != originalCount {
                    task.manualSectionOrders = manualSectionOrders
                    didChangeTask = true
                }

                guard didChangeTask else { continue }
                didChangeTasks = true
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: task.id,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: "Removed task from deleted custom section",
                    in: modelContext
                )
            }

            guard didChangeTasks else { return }
            try modelContext.save()
            NotificationCenter.default.postRoutineDidUpdate()
        } catch {
            statusMessage = "Section was removed, but task assignments could not be refreshed."
        }
    }
}

private extension HomeTaskSectionSurface {
    var displayName: String {
        switch self {
        case .radar:
            return "Main task list"
        case .backlog:
            return "Backlog"
        }
    }
}

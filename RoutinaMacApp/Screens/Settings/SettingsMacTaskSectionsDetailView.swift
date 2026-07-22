import SwiftData
import SwiftUI

struct SettingsMacTaskSectionsDetailView: View {
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
    @State private var renameDrafts: [UUID: String] = [:]
    @State private var tagRuleDrafts: [UUID: String] = [:]
    @State private var pendingDeleteSection: HomeCustomTaskSection?
    @State private var isDeleteConfirmationPresented = false
    @State private var statusMessage = ""

    var body: some View {
        SettingsMacDetailShell(
            title: "Sections",
            subtitle: "Manage custom task-list sections and automatic section rules."
        ) {
            SettingsMacDetailCard(title: "Custom Sections") {
                HStack(spacing: 10) {
                    TextField("Section name", text: $newSectionTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(createSection)

                    Button {
                        createSection()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreateSection)
                }

                if customTaskSections.isEmpty {
                    Text("No custom sections")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(customTaskSections.enumerated()), id: \.element.id) { index, section in
                            sectionEditor(for: section)

                            if index < customTaskSections.count - 1 {
                                Divider()
                            }
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
        .onAppear(perform: syncRenameDrafts)
        .onChange(of: customTaskSectionsRawValue) { _, _ in
            syncRenameDrafts()
        }
        .alert("Delete Section?", isPresented: $isDeleteConfirmationPresented) {
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

    private var canCreateSection: Bool {
        guard let result = HomeCustomTaskSectionStorage.upsertingSection(
            title: newSectionTitle,
            in: customTaskSections
        ) else {
            return false
        }
        return result.sections.count > customTaskSections.count
    }

    private var deleteConfirmationMessage: String {
        guard let pendingDeleteSection else {
            return "Tasks in this section will move back to their built-in sections or matching custom rules."
        }
        return "Delete \"\(pendingDeleteSection.title)\"? Tasks in this section will move back to their built-in sections or matching custom rules."
    }

    @ViewBuilder
    private func sectionEditor(for section: HomeCustomTaskSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.3.group")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)

                TextField("Section name", text: titleDraftBinding(for: section))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        saveTitle(for: section)
                    }

                Button {
                    saveTitle(for: section)
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .buttonStyle(.bordered)
                .disabled(!canSaveTitle(for: section))

                Button(role: .destructive) {
                    requestDelete(section)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            HStack(spacing: 10) {
                Text("Color")
                    .font(.subheadline.weight(.semibold))

                ColorPicker(
                    "Section color",
                    selection: colorBinding(for: section),
                    supportsOpacity: false
                )
                .labelsHidden()

                if section.colorHex != nil {
                    Button("Reset") {
                        setColor(nil, for: section.id)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.leading, 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("Rules")
                    .font(.subheadline.weight(.semibold))

                ForEach(HomeCustomTaskSectionRule.allCases) { rule in
                    Toggle(rule.title, isOn: ruleBinding(sectionID: section.id, rule: rule))
                        .toggleStyle(.checkbox)
                }

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Tags", text: tagRuleDraftBinding(for: section))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            saveTagRule(for: section)
                        }

                    HStack(spacing: 8) {
                        Button {
                            saveTagRule(for: section)
                        } label: {
                            Label("Save Tags", systemImage: "tag")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canSaveTagRule(for: section))

                        if !section.rules.tagNames.isEmpty {
                            Text(section.rules.tagNames.joined(separator: ", "))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.leading, 32)
        }
    }

    private func titleDraftBinding(for section: HomeCustomTaskSection) -> Binding<String> {
        Binding(
            get: { renameDrafts[section.id] ?? section.title },
            set: { renameDrafts[section.id] = $0 }
        )
    }

    private func ruleBinding(
        sectionID: UUID,
        rule: HomeCustomTaskSectionRule
    ) -> Binding<Bool> {
        Binding(
            get: {
                customTaskSections.first { $0.id == sectionID }?.rules.contains(rule) ?? false
            },
            set: { isEnabled in
                setRule(rule, isEnabled: isEnabled, for: sectionID)
            }
        )
    }

    private func tagRuleDraftBinding(for section: HomeCustomTaskSection) -> Binding<String> {
        Binding(
            get: { tagRuleDrafts[section.id] ?? tagRuleDraftText(for: section.rules.tagNames) },
            set: { tagRuleDrafts[section.id] = $0 }
        )
    }

    private func colorBinding(for section: HomeCustomTaskSection) -> Binding<Color> {
        Binding(
            get: { Color(routineTagHex: section.colorHex) ?? .accentColor },
            set: { setColor($0.routineTagHex, for: section.id) }
        )
    }

    private func canSaveTitle(for section: HomeCustomTaskSection) -> Bool {
        let draft = renameDrafts[section.id] ?? section.title
        guard HomeCustomTaskSectionStorage.sanitizedTitle(draft) != section.title else {
            return false
        }
        return HomeCustomTaskSectionStorage.renamingSection(
            section.id,
            title: draft,
            in: customTaskSections
        ) != nil
    }

    private func canSaveTagRule(for section: HomeCustomTaskSection) -> Bool {
        parsedTagRuleDraft(for: section) != section.rules.tagNames
    }

    private func createSection() {
        guard let result = HomeCustomTaskSectionStorage.upsertingSection(
            title: newSectionTitle,
            in: customTaskSections
        ),
              result.sections.count > customTaskSections.count else {
            return
        }

        persistSections(result.sections)
        renameDrafts[result.section.id] = result.section.title
        tagRuleDrafts[result.section.id] = ""
        newSectionTitle = ""
        statusMessage = ""
    }

    private func saveTitle(for section: HomeCustomTaskSection) {
        let draft = renameDrafts[section.id] ?? section.title
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
        statusMessage = ""
    }

    private func setRule(
        _ rule: HomeCustomTaskSectionRule,
        isEnabled: Bool,
        for sectionID: UUID
    ) {
        guard let sections = HomeCustomTaskSectionStorage.settingRule(
            rule,
            isEnabled: isEnabled,
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
        persistSections(
            HomeCustomTaskSectionStorage.deletingSection(section.id, from: customTaskSections)
        )
        removeCollapseState(for: section.id)
        statusMessage = ""
        clearDeletedSectionAssignments(section.id)
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
        var drafts: [UUID: String] = [:]
        var tagDrafts: [UUID: String] = [:]
        for section in sections {
            drafts[section.id] = section.title
            tagDrafts[section.id] = tagRuleDraftText(for: section.rules.tagNames)
        }
        renameDrafts = drafts
        tagRuleDrafts = tagDrafts
    }

    private func parsedTagRuleDraft(for section: HomeCustomTaskSection) -> [String] {
        HomeCustomTaskSectionRules.sanitizedTagNames(
            RoutineTag.parseDraft(
                tagRuleDrafts[section.id] ?? tagRuleDraftText(for: section.rules.tagNames)
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

    private func clearDeletedSectionAssignments(_ sectionID: UUID) {
        let sectionKey = HomeCustomTaskSectionStorage.manualOrderSectionKey(for: sectionID)

        do {
            let tasks = try modelContext.fetch(FetchDescriptor<RoutineTask>())
            var didChangeTasks = false

            for task in tasks {
                var didChangeTask = false

                if task.customTaskSectionID == sectionID {
                    task.customTaskSectionID = nil
                    didChangeTask = true
                }

                var manualSectionOrders = task.manualSectionOrders
                if manualSectionOrders.removeValue(forKey: sectionKey) != nil {
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

import ComposableArchitecture
import SwiftUI

struct SettingsTagsDetailView: View {
    let store: StoreOf<SettingsFeature>
    @State private var selectedTagID: String?
    @AppStorage(
        UserDefaultBoolValueKey.appSettingRelatedTagRulesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isRelatedTagRulesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isNotesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isGoalsTabEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areEventEmotionActionsEnabled = false

    var body: some View {
        List {
            if !store.tags.savedTags.isEmpty {
                Section("Tag Counters") {
                    Picker("Display", selection: tagCounterDisplayModeBinding) {
                        ForEach(TagCounterDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(store.appearance.tagCounterDisplayMode.subtitle)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Saved Tags") {
                if store.tags.savedTags.isEmpty {
                    Text(emptyTagsText)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.tags.savedTags) { tag in
                        SettingsTagRow(
                            store: store,
                            tag: tag,
                            isRelatedTagRulesEnabled: isRelatedTagRulesEnabled,
                            isSelected: selectedTagID == tag.id,
                            select: { selectTag(tag.id) }
                        )
                    }
                }
            }

            if !store.tags.tagStatusMessage.isEmpty {
                Section("Status") {
                    Text(store.tags.tagStatusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tags")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Delete Tag?",
            isPresented: deleteTagConfirmationBinding
        ) {
            Button("Delete", role: .destructive) {
                store.send(.deleteTagConfirmed)
            }
            Button("Cancel", role: .cancel) {
                store.send(.setDeleteTagConfirmation(false))
            }
        } message: {
            Text(store.tags.deleteConfirmationMessage)
        }
        .sheet(isPresented: renameTagSheetBinding) {
            SettingsTagRenameSheet(store: store)
                .presentationDetents([.height(240)])
        }
        .onChange(of: store.tags.savedTags.map(\.id)) { _, tagIDs in
            guard let selectedTagID, !tagIDs.contains(selectedTagID) else { return }
            self.selectedTagID = nil
        }
    }

    private var emptyTagsText: String {
        let sources = SettingsTagSourcePresentation.pluralSourceList(
            includesGoals: isGoalsTabEnabled,
            includesNotes: isNotesEnabled,
            includesEvents: areEventEmotionActionsEnabled,
            conjunction: "or"
        )
        return "No tags yet. Tags you add to \(sources) will appear here."
    }

    private var tagCounterDisplayModeBinding: Binding<TagCounterDisplayMode> {
        Binding(
            get: { store.appearance.tagCounterDisplayMode },
            set: { store.send(.tagCounterDisplayModeChanged($0)) }
        )
    }

    private var deleteTagConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.tags.isDeleteTagConfirmationPresented },
            set: { store.send(.setDeleteTagConfirmation($0)) }
        )
    }

    private var renameTagSheetBinding: Binding<Bool> {
        Binding(
            get: { store.tags.isTagRenameSheetPresented },
            set: { store.send(.setTagRenameSheet($0)) }
        )
    }

    private func selectTag(_ tagID: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTagID = selectedTagID == tagID ? nil : tagID
        }
    }
}

struct SettingsFlagsDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        List {
            Section {
                Text("Built-in behavior flags keep task behavior predictable. Assign any combination while editing a task; ordinary labels belong in Tags.")
                    .foregroundStyle(.secondary)
            }

            Section("Built-in Flags") {
                ForEach(RoutineFlagRuleKind.iOSVisibleCases) { kind in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: kind.systemImage)
                            .foregroundStyle(.tint)
                            .frame(width: 20, height: 22)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(kind.builtInFlagName)
                                .font(.body.weight(.medium))
                            Text(kind.title)
                            Text(kind.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Flags")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsTagRow: View {
    let store: StoreOf<SettingsFeature>
    let tag: RoutineTagSummary
    let isRelatedTagRulesEnabled: Bool
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: select) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        RoutineTagPill(tag: tag)
                        Text(tag.settingsSubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(tag.name), \(tag.settingsSubtitle)")
            .accessibilityHint(isSelected ? "Hide tag options" : "Show tag options")

            if isSelected {
                tagOptions
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                store.send(.renameTagTapped(tag.name))
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)

            Button(role: .destructive) {
                store.send(.deleteTagTapped(tag.name))
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var tagOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            tagActionsMenu

            if isRelatedTagRulesEnabled {
                relatedTagsEditor
            }
            tagColorEditor
        }
        .padding(.bottom, 4)
    }

    private var tagActionsMenu: some View {
        Menu {
            Button {
                store.send(.renameTagTapped(tag.name))
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button(role: .destructive) {
                store.send(.deleteTagTapped(tag.name))
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .disabled(store.tags.isTagOperationInProgress)
    }

    private var relatedTagsEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Related tags", text: relatedTagDraftBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(store.tags.isTagOperationInProgress)

            Button {
                store.send(.saveRelatedTagsTapped(tag.name))
            } label: {
                Label("Save related tags", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderless)
            .disabled(store.tags.isTagOperationInProgress)

            Text("Separate related tags with commas.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var tagColorEditor: some View {
        HStack(spacing: 12) {
            ColorPicker(
                "Tag color",
                selection: tagColorBinding,
                supportsOpacity: false
            )
            .disabled(store.tags.isTagOperationInProgress)

            Spacer()

            if tag.colorHex != nil {
                Button {
                    store.send(.tagColorChanged(tagName: tag.name, colorHex: nil))
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .disabled(store.tags.isTagOperationInProgress)
            }
        }
    }

    private var relatedTagDraftBinding: Binding<String> {
        Binding(
            get: {
                guard let key = RoutineTag.normalized(tag.name) else { return "" }
                return store.tags.relatedTagDrafts[key] ?? ""
            },
            set: { store.send(.relatedTagDraftChanged(tagName: tag.name, draft: $0)) }
        )
    }

    private var tagColorBinding: Binding<Color> {
        Binding(
            get: { Color(routineTagHex: tag.colorHex) ?? .accentColor },
            set: { store.send(.tagColorChanged(tagName: tag.name, colorHex: $0.routineTagHex)) }
        )
    }
}

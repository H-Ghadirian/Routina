import ComposableArchitecture
import SwiftUI

struct SettingsMacTagsDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
SettingsMacDetailShell(
    title: "Tags"
) {
    SettingsMacDetailCard(title: "Tag Counters") {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Tag counter display",
            options: TagCounterDisplayMode.allCases,
            selection: tagCounterDisplayModeBinding,
            minimumSegmentWidth: 104
        ) { mode in
            Text(mode.summaryText)
        }

        Text(store.appearance.tagCounterDisplayMode.subtitle)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    SettingsMacDetailCard(title: "All Tags") {
        SettingsMacTagsListContent(store: store)
    }

    if !store.tags.normalizationSuggestions.isEmpty {
        SettingsMacDetailCard(title: "Possible duplicate tags") {
            SettingsMacTagNormalizationList(store: store)
        }
    }

    if !store.tags.tagStatusMessage.isEmpty {
        SettingsMacDetailCard(title: "Status") {
            Text(store.tags.tagStatusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

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
}
.alert(
    "Merge similar tags?",
    isPresented: normalizationConfirmationBinding
) {
    Button("Merge tags", role: .destructive) {
        store.send(.normalizeTagSuggestionConfirmed)
    }
    Button("Not now", role: .cancel) {
        store.send(.setTagNormalizationConfirmation(false))
    }
} message: {
    Text(store.tags.normalizationConfirmationMessage)
}
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

    private var normalizationConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.tags.isTagNormalizationConfirmationPresented },
            set: { store.send(.setTagNormalizationConfirmation($0)) }
        )
    }

    private var tagCounterDisplayModeBinding: Binding<TagCounterDisplayMode> {
        Binding(
            get: { store.appearance.tagCounterDisplayMode },
            set: { store.send(.tagCounterDisplayModeChanged($0)) }
        )
    }
}

struct SettingsMacFlagsDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        SettingsMacDetailShell(title: "Flags") {
            SettingsMacDetailCard(title: "Create a Flag") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Flags add behavior to tasks without changing your tag organization.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        TextField("New flag", text: draftBinding)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { store.send(.addFlagTapped) }

                        Button("Add") {
                            store.send(.addFlagTapped)
                        }
                        .buttonStyle(.bordered)
                        .disabled(RoutineFlag.parseDraft(store.flags.draft).isEmpty)
                    }
                }
            }

            SettingsMacDetailCard(title: "Your Flags") {
                if store.flags.definedFlags.isEmpty {
                    Text("No flags yet. Add one here, then assign it while editing a task.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(store.flags.definedFlags.enumerated()), id: \.element) { index, flag in
                            flagRow(flag)
                            if index < store.flags.definedFlags.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }

            if !store.flags.statusMessage.isEmpty {
                SettingsMacDetailCard(title: "Status") {
                    Text(store.flags.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func flagRow(_ flag: String) -> some View {
        let assignedRuleKinds = store.flags.assignedRuleKinds(for: flag)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Label(flag, systemImage: "flag.fill")
                    .font(.callout.weight(.medium))

                Spacer()

                Menu {
                    Button("Remove Flag", role: .destructive) {
                        store.send(.removeFlagTapped(flag))
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Flag actions")
                .accessibilityLabel("More actions for \(flag)")
            }

            HStack(spacing: 12) {
                Text(assignedRuleKinds.isEmpty ? "No rules added" : "Rules")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                addRuleMenu(for: flag)
            }

            ForEach(assignedRuleKinds) { kind in
                assignedRuleRow(flag, kind: kind)
            }
        }
        .padding(.vertical, 12)
    }

    private func assignedRuleRow(
        _ flag: String,
        kind: RoutineFlagRuleKind
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title)
                    .font(.callout)
                Text(kind.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if kind == .autoAssumeDone {
                    Button {
                        store.send(.migrateAutoAssumeDoneTasksTapped(flag))
                    } label: {
                        Label("Migrate Existing Tasks…", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderless)
                    .font(.footnote)
                    .help("Add this Flag to tasks that already use auto-assume done")
                }
            }

            Spacer(minLength: 8)

            Button {
                store.send(.removeFlagRuleTapped(flagName: flag, kind: kind))
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Remove \(kind.title)")
            .accessibilityLabel("Remove \(kind.title) from \(flag)")
        }
        .padding(.vertical, 2)
    }

    private func addRuleMenu(for flag: String) -> some View {
        let availableRuleKinds = store.flags.availableRuleKinds(for: flag)

        return Menu {
            ForEach(availableRuleKinds) { kind in
                Button {
                    store.send(.addFlagRuleTapped(flagName: flag, kind: kind))
                } label: {
                    Label(kind.title, systemImage: kind.systemImage)
                }
            }
        } label: {
            Label("Add Rule", systemImage: "plus")
                .frame(minHeight: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(availableRuleKinds.isEmpty)
        .help(
            availableRuleKinds.isEmpty
                ? "All available rules are already added"
                : "Choose a rule to add to \(flag)"
        )
        .accessibilityLabel(
            availableRuleKinds.isEmpty
                ? "All rules added to \(flag)"
                : "Add rule to \(flag)"
        )
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { store.flags.draft },
            set: { store.send(.flagDraftChanged($0)) }
        )
    }
}

private struct SettingsMacTagNormalizationList: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Routina found tag names that may be the same word, such as #clean and #Cleaning. Nothing changes until you confirm each merge.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(store.tags.normalizationSuggestions) { suggestion in
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("#\(suggestion.source.name) → #\(suggestion.replacement.name)")
                            .font(.callout.weight(.medium))
                        Text("#\(suggestion.source.name) is used by \(suggestion.source.totalLinkedItemCount) item\(suggestion.source.totalLinkedItemCount == 1 ? "" : "s")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Merge…") {
                        store.send(.normalizeTagSuggestionTapped(
                            sourceTagName: suggestion.source.name,
                            replacementTagName: suggestion.replacement.name
                        ))
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.tags.isTagOperationInProgress)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

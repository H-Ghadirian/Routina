import ComposableArchitecture
import SwiftUI

struct SettingsMacTagsDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
SettingsMacDetailShell(
    title: "Tags"
) {
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
}

struct SettingsMacFlagsDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        SettingsMacDetailShell(title: "Flags") {
            SettingsMacDetailCard(title: "Task behavior") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Flags are separate from tags. Use them to mark tasks for Routina behavior without changing your tag organization.")
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

            SettingsMacDetailCard(title: "Defined Flags") {
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
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label(flag, systemImage: "flag.fill")
                    .font(.callout.weight(.medium))

                ForEach(RoutineFlagRuleKind.allCases) { kind in
                    let isEnabled = store.flags.hasRule(kind, for: flag)
                    Label(
                        "\(kind.title): \(isEnabled ? "On" : "Off")",
                        systemImage: kind == .hideFromTaskLists ? "eye.slash" : "checkmark.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Menu("Rules") {
                ForEach(RoutineFlagRuleKind.allCases) { kind in
                    Button(store.flags.hasRule(kind, for: flag) ? "Remove \(kind.title)" : "Add \(kind.title)") {
                        store.send(
                            store.flags.hasRule(kind, for: flag)
                                ? .removeFlagRuleTapped(flagName: flag, kind: kind)
                                : .addFlagRuleTapped(flagName: flag, kind: kind)
                        )
                    }
                }
            }
            .menuStyle(.borderedButton)

            if store.flags.hasRule(.autoAssumeDone, for: flag) {
                Button("Migrate") {
                    store.send(.migrateAutoAssumeDoneTasksTapped(flag))
                }
                .buttonStyle(.bordered)
                .help("Add this Flag to tasks that already use auto-assume done")
            }

            Menu {
                Button("Remove flag", role: .destructive) {
                    store.send(.removeFlagTapped(flag))
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .help("Flag actions")
        }
        .padding(.vertical, 8)
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

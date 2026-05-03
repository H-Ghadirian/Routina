import ComposableArchitecture
import SwiftUI

struct SettingsTagsDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("Info") {
                    Text("Rename or delete tags across every routine that uses them.")
                        .foregroundStyle(.secondary)
                }

                Section("Saved Tags") {
                    if store.tags.savedTags.isEmpty {
                        Text("No tags yet. Tags you add to routines will appear here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.tags.savedTags) { tag in
                            SettingsTagRow(store: store, tag: tag)
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
}

private struct SettingsTagRow: View {
    let store: StoreOf<SettingsFeature>
    let tag: RoutineTagSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    RoutineTagPill(tag: tag)
                    Text(tag.settingsSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                fastFilterButton
                tagActionsMenu
            }

            relatedTagsEditor
            tagColorEditor
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

    private var fastFilterButton: some View {
        Button {
            store.send(.fastFilterTagToggled(tag.name))
        } label: {
            Image(systemName: isFastFilterTag ? "bolt.fill" : "bolt")
                .font(.title3)
                .foregroundStyle(isFastFilterTag ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.borderless)
        .disabled(store.tags.isTagOperationInProgress)
        .accessibilityLabel("Toggle fast filter")
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

    private var isFastFilterTag: Bool {
        store.tags.fastFilterTags.contains(where: { RoutineTag.contains($0, in: [tag.name]) })
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

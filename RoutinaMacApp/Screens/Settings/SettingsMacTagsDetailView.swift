import ComposableArchitecture
import SwiftUI

struct SettingsMacTagsDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "Tags",
                subtitle: "Review every tag in Routina and rename or remove them globally."
            ) {
                SettingsMacDetailCard(title: "All Tags") {
                    if store.tags.savedTags.isEmpty {
                        Text("No tags yet. Tags you add to routines will appear here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            tagSearchField
                            filteredTagsList
                        }
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
        }
    }

    @ViewBuilder
    private var filteredTagsList: some View {
        let filtered = store.tags.filteredSavedTags
        if filtered.isEmpty {
            Text("No tags match \u{201C}\(store.tags.tagSearchQuery)\u{201D}.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, tag in
                    SettingsMacTagRow(store: store, tag: tag)

                    if index < filtered.count - 1 {
                        Divider()
                    }
                }
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

    private var tagSearchQueryBinding: Binding<String> {
        Binding(
            get: { store.tags.tagSearchQuery },
            set: { store.send(.tagSearchQueryChanged($0)) }
        )
    }

    @ViewBuilder
    private var tagSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.callout)

            TextField("Search tags", text: tagSearchQueryBinding)
                .textFieldStyle(.plain)
                .font(.callout)

            if !store.tags.tagSearchQuery.isEmpty {
                Button {
                    store.send(.tagSearchQueryChanged(""))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

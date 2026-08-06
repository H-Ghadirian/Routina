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

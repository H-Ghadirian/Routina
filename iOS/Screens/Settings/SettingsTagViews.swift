import ComposableArchitecture
import SwiftUI

struct SettingsTagManagerPresentationView: View {
    let store: StoreOf<SettingsFeature>
    @Environment(\.dismiss) var dismiss

    var body: some View {
        platformTagManagerContent
        .onAppear {
            store.send(.tagManagerAppeared)
        }
    }
}

struct SettingsTagRenameSheet: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rename Tag")
                        .font(.title2.weight(.semibold))

                    Text("Update this tag everywhere it is used. Renaming to an existing tag will merge them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                TextField("Tag name", text: tagRenameDraftBinding)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        guard !store.tags.isSaveRenameDisabled else { return }
                        store.send(.saveTagRenameTapped)
                    }

                if let pendingTag = store.tags.tagPendingRename {
                    Text(pendingTag.settingsSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()

                    Button("Cancel") {
                        store.send(.setTagRenameSheet(false))
                    }

                    Button("Save") {
                        store.send(.saveTagRenameTapped)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.tags.isSaveRenameDisabled)
                }
            }
            .padding(20)
            .frame(minWidth: 320, idealWidth: 380, alignment: .topLeading)
        }
    }

    private var tagRenameDraftBinding: Binding<String> {
        Binding(
            get: { store.tags.tagRenameDraft },
            set: { store.send(.tagRenameDraftChanged($0)) }
        )
    }
}

import ComposableArchitecture
import SwiftUI

struct SettingsMacTagsListContent: View {
    let store: StoreOf<SettingsFeature>
    @AppStorage(
        UserDefaultBoolValueKey.appSettingRelatedTagRulesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isRelatedTagRulesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isNotesEnabled = false

    var body: some View {
if store.tags.savedTags.isEmpty {
    Text(emptyTagsText)
        .font(.footnote)
        .foregroundStyle(.secondary)
} else {
    VStack(alignment: .leading, spacing: 12) {
        tagSearchField
        filteredTagsList
    }
}
    }

    private var emptyTagsText: String {
        isNotesEnabled
            ? "No tags yet. Tags you add to tasks, goals, notes, or events will appear here."
            : "No tags yet. Tags you add to tasks, goals, or events will appear here."
    }

    @ViewBuilder
    private var filteredTagsList: some View {
        let filtered = store.tags.filteredSavedTags
        if filtered.isEmpty {
            Text("No tags match “\(store.tags.tagSearchQuery)”.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, tag in
                    SettingsMacTagRow(
                        store: store,
                        tag: tag,
                        isRelatedTagRulesEnabled: isRelatedTagRulesEnabled
                    )

                    if index < filtered.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

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
        .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.06, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var tagSearchQueryBinding: Binding<String> {
        Binding(
            get: { store.tags.tagSearchQuery },
            set: { store.send(.tagSearchQueryChanged($0)) }
        )
    }
}

import ComposableArchitecture
import SwiftUI

struct HomeMacSettingsSidebarView: View {
    let store: StoreOf<SettingsFeature>
    let selectedSection: SettingsMacSection
    let onSelectSection: (SettingsMacSection) -> Void

    var body: some View {
        List {
            ForEach(SettingsMacSection.visibleSections(isGitFeaturesEnabled: store.appearance.isGitFeaturesEnabled)) { section in
                Button {
                    onSelectSection(section)
                } label: {
                    SettingsMacSidebarRow(
                        section: section,
                        store: store
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(section == selectedSection ? Color.accentColor.opacity(0.9) : Color.clear)
                        .padding(.vertical, 2)
                )
            }
        }
        .listStyle(.sidebar)
    }
}

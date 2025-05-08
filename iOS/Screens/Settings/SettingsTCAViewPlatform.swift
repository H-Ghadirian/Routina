import SwiftUI

extension SettingsTCAView {
    @ViewBuilder
    var platformSettingsContent: some View {
        NavigationStack {
            SettingsIOSRootView(store: store)
        }
    }
}

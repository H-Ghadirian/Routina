import SwiftUI

extension SettingsTCAView {
    @ViewBuilder
    var platformSettingsContent: some View {
        SettingsPlatformRootView(store: store)
    }
}

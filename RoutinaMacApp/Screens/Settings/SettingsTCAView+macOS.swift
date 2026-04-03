import SwiftUI

extension SettingsTCAView {
    @ViewBuilder
    var platformSettingsContent: some View {
        SettingsMacView(store: store)
    }
}

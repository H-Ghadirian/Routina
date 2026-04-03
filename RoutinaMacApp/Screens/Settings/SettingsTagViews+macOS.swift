import SwiftUI

extension SettingsTagManagerPresentationView {
    var platformTagManagerContent: some View {
        SettingsMacTagsDetailView(store: store)
            .frame(minWidth: 640, minHeight: 520)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
    }
}

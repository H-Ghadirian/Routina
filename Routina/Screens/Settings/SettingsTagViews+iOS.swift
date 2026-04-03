import SwiftUI

extension SettingsTagManagerPresentationView {
    var platformTagManagerContent: some View {
        NavigationStack {
            SettingsTagsDetailView(store: store)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

import SwiftUI

struct IOSWorkspaceControlsButton: View {
    let title: String
    let isCustomized: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "slider.horizontal.3")
                .foregroundStyle(isCustomized ? Color.accentColor : Color.primary)
        }
        .accessibilityValue(isCustomized ? "Customized" : "Default")
    }
}

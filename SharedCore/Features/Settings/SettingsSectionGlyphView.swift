import SwiftUI

struct SettingsSectionGlyphView: View {
    let icon: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(tint)
            .frame(width: 30, height: 30)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

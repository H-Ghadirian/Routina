import SwiftUI

struct HomeMacSidebarSectionCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassPanel(cornerRadius: 18, tint: .secondary, tintOpacity: 0.08)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }
}

struct HomeMacFilterAppearanceToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    init(
        _ title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.subtitle = subtitle
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .toggleStyle(.switch)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

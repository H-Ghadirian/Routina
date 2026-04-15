import SwiftUI

struct HomeMacTagChipView: View {
    let title: String
    let count: Int
    let systemImage: String
    let isSelected: Bool
    let selectedColor: Color
    let action: () -> Void

    init(
        title: String,
        count: Int,
        systemImage: String,
        isSelected: Bool,
        selectedColor: Color = .accentColor,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.count = count
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.selectedColor = selectedColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))

                Text(title)
                    .font(.caption.weight(.semibold))

                Text(count.formatted())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.white.opacity(0.18) : Color.primary.opacity(0.08))
                    )
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? selectedColor : Color.secondary.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? selectedColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

struct HomeMacTagChipView: View {
    let title: String
    let count: Int
    let systemImage: String
    let isSelected: Bool
    let selectedColor: Color
    let unselectedColor: Color?
    let action: () -> Void

    init(
        title: String,
        count: Int,
        systemImage: String,
        isSelected: Bool,
        selectedColor: Color = .accentColor,
        unselectedColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.count = count
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.selectedColor = selectedColor
        self.unselectedColor = unselectedColor
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
                            .fill(countBackgroundColor)
                    )
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var tint: Color {
        if isSelected {
            return selectedColor
        }
        return unselectedColor ?? .secondary
    }

    private var foregroundColor: Color {
        if isSelected {
            return selectedColor
        }
        return unselectedColor ?? .primary
    }

    private var backgroundColor: Color {
        tint.opacity(isSelected ? 0.16 : 0.10)
    }

    private var countBackgroundColor: Color {
        tint.opacity(isSelected ? 0.18 : 0.12)
    }

    private var strokeColor: Color {
        tint.opacity(isSelected ? 0.35 : 0.18)
    }
}

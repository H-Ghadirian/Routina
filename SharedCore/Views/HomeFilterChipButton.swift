import SwiftUI

struct HomeFilterChipButton: View {
    let title: String
    let isSelected: Bool
    let selectedColor: Color
    let selectedForegroundColor: Color?
    let unselectedForegroundColor: Color
    let unselectedColor: Color?
    let selectedBackgroundOpacity: Double
    let unselectedBackgroundOpacity: Double
    let fillsAvailableWidth: Bool
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let action: () -> Void

    init(
        title: String,
        isSelected: Bool,
        selectedColor: Color = .accentColor,
        selectedForegroundColor: Color? = nil,
        unselectedForegroundColor: Color = .secondary,
        unselectedColor: Color? = nil,
        selectedBackgroundOpacity: Double = 0.16,
        unselectedBackgroundOpacity: Double = 0.10,
        fillsAvailableWidth: Bool = false,
        horizontalPadding: CGFloat = 10,
        verticalPadding: CGFloat = 7,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.selectedColor = selectedColor
        self.selectedForegroundColor = selectedForegroundColor
        self.unselectedForegroundColor = unselectedForegroundColor
        self.unselectedColor = unselectedColor
        self.selectedBackgroundOpacity = selectedBackgroundOpacity
        self.unselectedBackgroundOpacity = unselectedBackgroundOpacity
        self.fillsAvailableWidth = fillsAvailableWidth
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: fillsAvailableWidth ? .infinity : nil)
                .foregroundStyle(foregroundColor)
                .routinaGlassPill(
                    tint: backgroundTint,
                    tintOpacity: backgroundOpacity,
                    interactive: true
                )
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: fillsAvailableWidth ? .infinity : nil)
    }

    private var foregroundColor: Color {
        if isSelected {
            selectedForegroundColor ?? selectedColor
        } else {
            unselectedColor ?? unselectedForegroundColor
        }
    }

    private var backgroundTint: Color {
        if isSelected {
            selectedColor
        } else {
            unselectedColor ?? Color.secondary
        }
    }

    private var backgroundOpacity: Double {
        isSelected ? selectedBackgroundOpacity : unselectedBackgroundOpacity
    }
}

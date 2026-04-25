import SwiftUI

struct HomeFilterChipButton: View {
    let title: String
    let isSelected: Bool
    let selectedColor: Color
    let selectedForegroundColor: Color?
    let unselectedForegroundColor: Color
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
                .frame(maxWidth: fillsAvailableWidth ? .infinity : nil)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .foregroundStyle(foregroundColor)
                .background(
                    Capsule()
                        .fill(backgroundColor)
                )
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        if isSelected {
            selectedForegroundColor ?? selectedColor
        } else {
            unselectedForegroundColor
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            selectedColor.opacity(selectedBackgroundOpacity)
        } else {
            Color.secondary.opacity(unselectedBackgroundOpacity)
        }
    }
}

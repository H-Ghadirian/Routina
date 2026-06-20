import SwiftUI

struct TaskDetailColoredSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let title: (Option) -> String
    let tint: (Option) -> Color
    let selectedForeground: (Option) -> Color
    let action: (Option) -> Void

    var body: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Task detail options",
            options: options,
            selection: selection,
            onSelect: action,
            minimumSegmentWidth: 64,
            horizontalPadding: 8,
            verticalPadding: 6,
            fillsAvailableWidth: true,
            tint: tint,
            foregroundColor: { option, isSelected in
                isSelected ? selectedForeground(option) : .primary
            }
        ) { option in
            let isSelected = selection == option

            HStack(spacing: 6) {
                Circle()
                    .fill(isSelected ? selectedForeground(option).opacity(0.88) : tint(option))
                    .frame(width: 6, height: 6)

                Text(title(option))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
    }
}

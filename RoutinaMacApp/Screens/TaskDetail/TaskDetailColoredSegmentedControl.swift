import SwiftUI

struct TaskDetailColoredSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let title: (Option) -> String
    let tint: (Option) -> Color
    let selectedForeground: (Option) -> Color
    let action: (Option) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = selection == option

                Button {
                    action(option)
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isSelected ? selectedForeground(option).opacity(0.88) : tint(option))
                            .frame(width: 6, height: 6)

                        Text(title(option))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? selectedForeground(option) : .primary)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(tint(option))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(option))
                .accessibilityValue(isSelected ? "Selected" : "")

                if index < options.index(before: options.endIndex) {
                    let nextOption = options[options.index(after: index)]
                    let isAdjacentToSelection = isSelected || selection == nextOption

                    Rectangle()
                        .fill(.primary.opacity(isAdjacentToSelection ? 0 : 0.14))
                        .frame(width: 1, height: 18)
                }
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

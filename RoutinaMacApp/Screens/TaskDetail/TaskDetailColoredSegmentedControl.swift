import SwiftUI

struct TaskDetailColoredSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let title: (Option) -> String
    let tint: (Option) -> Color
    let selectedForeground: (Option) -> Color
    let action: (Option) -> Void
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .glassEffect(
                                    .regular.tint(tint(option).opacity(0.30)).interactive(),
                                    in: .rect(cornerRadius: 7)
                                )
                                .glassEffectID(index, in: glassNamespace)
                        }
                    }
                    .accessibilityLabel(title(option))
                    .accessibilityValue(isSelected ? "Selected" : "")
                }
            }
            .padding(3)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 9))
        }
    }
}
